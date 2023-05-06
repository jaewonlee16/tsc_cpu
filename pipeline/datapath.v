`timescale 1ns / 1ns
`include "constants.v"
`include "opcodes.v"
module datapath
  #(parameter DATA_FORWARDING,
    parameter BRANCH_PREDICTOR)
    (
        input clk,
        input reset_n,

        // --------------------------- control_unit signals
        // ID signal
        output [3:0] opcode,
        output [5:0] func_code,

        input [1 : 0] PCSource,
        input isJump,

        // EX signal
        input [1 : 0] ALUSrcB,
        input [3: 0] ALUOperation,
        input isItype_Branch,

        // MEM signal
        input d_readM_ID,
        input d_writeM_ID,

        // WB signal
        input output_active,
        input is_halted_ID,
        input [1 : 0] RegDst, // write to 0: rt, 1: rd, 2: $2 (JAL)
        input RegWrite,
        input [1 : 0] MemtoReg, // write 0: ALU, 1: MDR, 2: PC + 1

        // --------------------------- cpu.v signals
        output [`WORD_SIZE-1:0]       i_address,
        output [`WORD_SIZE-1:0]       d_address,
        output                       i_readM,
        output                       d_readM,
        output                       i_writeM,
        output                       d_writeM,
        inout [`WORD_SIZE-1:0]        i_data,
        inout [`WORD_SIZE-1:0]        d_data,
        output reg [`WORD_SIZE-1:0]   output_port,
        output                       is_halted, 
        output [`WORD_SIZE-1:0]       num_inst
        
    )
        // reg declaration
        reg [`WORD_SIZE-1:0]   num_branch; // total number of branches
        reg [`WORD_SIZE-1:0]   num_branch_miss; // number of branch prediction miss
        reg [`WORD_SIZE - 1 : 0] pc;


        // ------------------------------------ modules --------------------------------
        // hazard_control_unit
        hazard_control_unit #(.DATA_FORWARDING(DATA_FORWARDING))
        hazard (
            .opcode(opcode),
            .func_code(func_code),

            // flush .signals
            .jump_miss(jump_miss), // misprediction of unconditional branch
            .i_branch_miss(i_branch_miss), // misprediction of conditional branch

            // signals that determine when to stall
            .rs_ID(rs_ID), 
            .rt_ID(rt_ID), 
            .Reg_write_EX(),
            .Reg_write_MEM(),
            .Reg_write_WB(),
            .dest_EX(),             // write_reg_addr_EX 
            .dest_MEM(),            // write_reg_addr_MEM 
            .dest_WB(),            // write_reg_addr_WB 

            // load stall
            .d_MEM_write_WB(),
            .d_MEM_read_EX(),
            .d_MEM_read_mem(),
            .d_MEM_read_WB(),
            .rt_EX(), 
            .rt_MEM(),
            .rt_WB(),

            // control signals
            .stall_IFID(stall_IFID), // stall pipeline IF_ID_register
            .flush_IFID(flush_IFID), // flush if
            .flush_IDEX(flush_IDEX), // flush id
            .pc_write(pc_write),
            .ir_write(ir_write)
        );

        // branch_predictor
        branch_predictor #(BRANCH_PREDICTOR.(BRANCH_PREDICTOR),
                            BTB_IDX_SIZE.(BTB_IDX_SIZE))
        bp (

            clk(clk),
            reset_n(reset_n), // clear BTB to all zero

            // IF
            pc(pc_IF), // the pc that was just fetched

            // ID
            update_tag(update_tag), // update tag as soon as decode (when target is known)
            pc_for_btb_update(pc_ID), // PC collision tag 
            branch_target_for_btb_update(branch_target), // branch target of jump and i type branch.

            // ID or EX
            update_bht(), // update BHT when know prediction was correct or not
            pc_real(),        // The actual pc that is calculated (not predicted)
                            // pc_ex(i type branch) or pc_id(jump)
            branch_correct_or_notCorrect(), // if the predicted pc is same as the actual pc

            // IF
            tag_match(tag_match_IF), // tag matched PC
            branch_predicted_pc(branch_predicted_pc_IF) // predicted next PC
        );   

        RF rf(
            .write(),
            .clk(clk),
            .reset_n(reset_n),
            .addr1(rs_ID),
            .addr2(rt_ID),
            .addr3(),
            .data1(RF_data1_ID),
            .data2(RF_data2_ID),
            .data3()
        );
        
        ALU ALU_UUT(
            .A(RF_data1_EX),
            .B(),
            .Cin(0),
            .OP(ALUOperation_EX),
            .C(),
            .Cout(),
            .Compare()
        );

        // pipeline_register.v
        IF_ID_register IF_to_ID(
            clk(clk),
            reset_n(reset_n),
            flush(flush_IFID),
            stall(stall_IFID),
            pc_IF(pc_IF),
            branch_predicted_pc_IF(branch_predicted_pc_IF),
            instruction_IF(instruction_IF),
            tag_match_IF(tag_match_IF),
            pc_ID(pc_ID),
            branch_predicted_pc_ID(branch_predicted_pc_ID),
            instruction_ID(instruction_ID),
            tag_match_ID(tag_match_ID)


        );

        ID_EX_register ID_to_EX(
            clk(clk),
            reset_n(reset_n),
            flush(flush_IDEX),
            stall(stall_IDEX),

            // ----------------------------- control signal inputs and outputs
            // input ports
            // EX
            ALUSrcB_ID(ALUSrcB),
            ALUOperation_ID(ALUOperation),
            isItype_Branch_ID(isItype_Branch),

            // MEM
            d_readM_ID(d_readM_ID),
            d_writeM_ID(d_writeM_ID),

            // WB
            output_active_ID(output_active),
            is_halted_ID(is_halted_ID), 
            RegDst_ID(RegDst), // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_ID(RegWrite),
            MemtoReg_ID(MemtoReg), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // output ports
            // EX
            ALUSrcB_EX(),
            ALUOperation_EX(),
            isItype_Branch_EX(),

            // MEM
            d_readM_EX(),
            d_writeM_EX(),

            // WB
            output_active_EX(),
            is_halted_EX(), 
            RegDst_EX(), // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_EX(),
            MemtoReg_EX(), // write 0: ALU, 1: MDR, 2: PC + 1

            // ----------------------------------- Data latch
            pc_ID(pc_ID),
            branch_predicted_pc_ID(branch_predicted_pc_ID),
            instruction_ID(instruction_ID),

            pc_EX(),
            branch_predicted_pc_EX(),    // last because branch ends at EX
            instruction_EX(),

            i_type_branch_target_ID(i_type_branch_target_ID),
            rs_ID(rs_ID),
            rt_ID(rt_ID),
            rd_ID(rd_ID),
            RF_data1_ID(RF_data1_ID),
            RF_data2_ID(RF_data2_ID),
            imm_signed_ID(imm_signed_ID),
            write_reg_addr_ID(write_reg_addr_ID),

            
            i_type_branch_target_EX(),   // last because branch ends at EX
            rs_EX(),
            rt_EX(),
            rd_EX(),
            RF_data1_EX(),
            RF_data2_EX(),
            imm_signed_EX(),
            write_reg_addr_EX()

        );

        EX_MEM_register EX_to_MEM(

            clk(),
            reset_n(),
            flush(),
            stall(),

            // ----------------------------- control signal inputs and outputs
            // ports
            // MEM
            d_readM_EX(),
            d_writeM_EX(),

            // WB
            output_active_EX(),
            is_halted_EX(), 
            RegDst_EX(), // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_EX(),
            MemtoReg_EX(), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ports
            // MEM
            d_readM_MEM(),
            d_writeM_MEM(),

            // WB
            output_active_MEM(),
            is_halted_MEM(), 
            RegDst_MEM(), // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_MEM(),
            MemtoReg_MEM(), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ----------------------------------- Data latch
            pc_EX(),
            instruction_EX(),

            pc_MEM(),
            instruction_MEM(),

            rs_EX(),
            rt_EX(),
            RF_data2_EX(),
            imm_signed_EX(),
            write_reg_addr_EX(),

            rs_MEM(),
            rt_MEM(),
            RF_data2_MEM(),      // for SWD`        
            imm_signed_MEM(),
            write_reg_addr_MEM

            ALU_result_EX(),
            ALU_out_MEM()
        );

        MEM_WB_register MEM_to_WB(

            clk(),
            reset_n(),
            flush(),
            stall(),

            // ----------------------------- control signal inputs and outputs
            // ports
            // WB
            output_active_MEM(),
            is_halted_MEM(), 
            RegDst_MEM(), // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_MEM(),
            MemtoReg_MEM(), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ports
            // WB
            output_active_WB(),
            is_halted_WB(), 
            RegDst_WB(), // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_WB(),
            MemtoReg_WB(), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ----------------------------------- Data latch
            pc_MEM(),
            instruction_MEM(),

            pc_WB(),
            instruction_WB(),

            rs_MEM(),
            rt_MEM(),
            imm_signed_MEM(),
            write_reg_addr_MEM(),

            rs_WB(),
            rt_WB(),
            imm_signed_WB(),
            write_reg_addr_WB

            ALU_out_MEM(),
            ALU_out_WB(),

            MDR_MEM(),
            MDR_WB()
        );



        // ------------------------  Datapath  ------------------------ //

        // pipeline register control wires
        wire flush_IFID, flush_IDEX, flush_EXMEM, flush_MEMWB;
        wire stall_IFID, stall_IDEX, stall_EXMEM, stall_MEMWB;

        //  ----------------------- IF STAGE --------------------------
        // pipeline register wires
        wire [`WORD_SIZE - 1 : 0] pc_IF;
        wire [`WORD_SIZE - 1 : 0] branch_predicted_pc_IF;
        wire [`WORD_SIZE - 1 : 0] instruction_IF;
        wire tag_match_IF;

        // hazard_control wires
        wire pc_write;
        wire ir_write;

        // assign
        assign pc_IF = pc;   // pc_IF : wire    pc: reg
        assign i_address = pc;
        assign instruction_IF = i_data;

        // ------------------------- ID STAGE ----------------------------
        // pipeline register wires
        wire [`WORD_SIZE - 1 : 0] pc_ID;
        wire [`WORD_SIZE - 1 : 0] branch_predicted_pc_ID;
        wire [`WORD_SIZE - 1 : 0] instruction_ID;
        wire tag_match_ID;

        // instruction decode
        wire [1:0]           rs_ID, rt_ID, rd_ID;
        wire [7:0]           imm;
        wire [11:0]          jump_target_imm;
        wire [`WORD_SIZE-1:0] imm_signed_ID;
        wire [15 : 0] RF_data1_ID;
        wire [15 : 0] RF_data2_ID;
        wire [1 : 0] write_reg_addr_ID;

        wire [`WORD_SIZE - 1 : 0] jump_target;
        wire [`WORD_SIZE - 1 : 0] i_type_branch_target_ID;
        wire [`WORD_SIZE - 1 : 0] branch_target;
        wire jump_miss;
        wire update_tag;

        assign opcode = instruction_ID[15:12];
        assign func_code = instruction_ID[5:0];

        assign rs_ID = instruction_ID[11:10];
        assign rt_ID = instruction_ID[9:8];
        assign rd_ID = instruction_ID[7:6];
        
        assign imm = instruction_ID[7:0];
        assign imm_signed_ID = {{8{imm[7]}}, imm}; //sign-extended
        assign jump_target_imm = instruction_ID[11:0];
        assign write_reg_addr_ID = (RegDst == `REGDST_RT) ? rt_ID :
                                   (RegDst == `REGDST_RD) ? rd_ID :
                                    2'd2;

        // branch predictor ID
        assign jump_target = (opcode == `OPCODE_RTYPE && (func_code == `FUNC_JPR || func_code == `FUNC_JRL)) ?
                        RF_data1_ID :
                        {pc[15:12], jump_target_imm};
        assign i_type_branch_target_ID = (pc_id + 1) + imm_signed_ID;
        assign branch_target = isJump ? jump_target :i_type_branch_target_ID;
        assign jump_miss = isJump ? (jump_target != branch_predicted_pc_ID) : 1;

        // If this is a branch instruction and BTB tag match failed in IF,
        // update tag in ID stage.
        assign update_tag = ((isJump || isItype_Branch_ID) && !tag_match_ID) ? 1 : 0;


        // ------------------------- EX STAGE ------------------------------
        // -- pipeline register wires -- //
        // control signal wires
        wire [1 : 0] ALUSrcB_EX;
        wire [3 : 0] ALUOperation_EX;
        wire isItype_Branch_EX;

        wire d_readM_EX;
        wire d_writeM_EX;

        wire output_active_EX;
        wire is_halted_EX;
        wire [1 : 0] RegDst_EX;
        wire Reg_write_EX;
        wire [1 : 0] MemtoReg_EX;

        // data signal wires
        wire [`WORD_SIZE - 1 : 0] pc_EX;
        wire [`WORD_SIZE - 1 : 0] branch_predicted_pc_EX;
        wire [`WORD_SIZE - 1 : 0] instruction_EX;

        wire [`WORD_SIZE - 1 : 0] i_type_branch_target_EX;
        wire [1 : 0] rs_EX, rt_EX, rd_EX;
        wire [`WORD_SIZE - 1 : 0] RF_data1_EX, RF_data2_EX;
        wire [`WORD_SIZE - 1 : 0] imm_signed_EX;
        wire [1 : 0] write_reg_addr_EX;


        // ------------------ ALU.v wires -----------
        wire [`WORD_SIZE - 1 : 0] ALU_in_B

        // ------- Branch Predictor wires ------ //

        wire i_branch_miss;

        // IF + ID + EX
        // pc update logic
        // sequential logic for pc and num_branch_miss
        always @ (posedge clk) begin
            if (pc_write) begin
                if (reset_n) begin
                    pc <= 0;
                    num_branch_miss <= 0;
                end
                else if (i_branch_miss) begin
                    pc <= calculated_pc_EX;
                    num_branch_miss <= num_branch_miss + 1;
                end
                else if (jump_miss) begin
                    pc <= jump_target;
                    num_branch_miss <= num_branch_miss + 1;
                end
                else
                    pc <= branch_predicted_pc_IF;
            end
            else // stall
                pc <= pc;
        end