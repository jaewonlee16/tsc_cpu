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
            .rs_ID(), 
            .rt_ID(), 
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
            .stall_IFID(), // stall pipeline IF_ID_register
            .flush_IFID(), // flush if
            .flush_IDEX(), // flush id
            .pc_write(pc_write),
            .ir_write()
        );

        // branch_predictor
        branch_predictor #(BRANCH_PREDICTOR.(BRANCH_PREDICTOR),
                            BTB_IDX_SIZE.(BTB_IDX_SIZE))
        bp (

            clk(),
            reset_n(), // clear BTB to all zero
            update_tag(), // update tag as soon as decode (when target is known)
            update_bht(), // update BHT when know prediction was correct or not
            pc(pc_IF), // the pc that was just fetched
            pc_for_btb_update(), // PC collision tag 
                             // always pc_id
            pc_real(),        // The actual pc that is calculated (not predicted)
                            // pc_ex(i type branch) or pc_id(jump)
            branch_target_for_btb_update(), // branch target of jump and i type branch.
                                          // update as soon as decode
            branch_correct_or_notCorrect(), // if the predicted pc is same as the actual pc
            tag_match(tag_match_IF), // tag matched PC
            branch_predicted_pc(branch_predicted_pc_IF) // predicted next PC
        );   

        RF rf(
            .write(),
            .clk(clk),
            .reset_n(reset_n),
            .addr1(),
            .addr2(),
            .addr3(),
            .data1(),
            .data2(),
            .data3()
        );
        
        ALU ALU_UUT(
            .A(),
            .B(),
            .Cin(0),
            .OP(),
            .C(),
            .Cout(),
            .Compare()
        );

        // pipeline_register.v
        IF_ID_register IF_to_ID(
            clk(),
            reset_n(),
            flush(),
            stall(),
            pc_IF(),
            branch_predicted_pc_IF(),
            instruction_IF(),
            tag_match_ID(),
            pc_ID(),
            branch_predicted_pc_ID(),
            instruction_ID(),
            tag_match_ID()


        );

        ID_EX_register ID_to_EX(
            clk(),
            reset_n(),
            flush(),
            stall(),

            // ----------------------------- control signal inputs and outputs
            // ports
            // EX
            ALUSrcB_ID(),
            ALUOperation_ID(),
            isItype_Branch_ID(),

            // MEM
            d_readM_ID(),
            d_writeM_ID(),

            // WB
            output_active_ID(),
            is_halted_ID(), 
            RegDst_ID(), // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_ID(),
            MemtoReg_ID(), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ports
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
            pc_ID(),
            branch_predicted_pc_ID(),
            instruction_ID(),

            pc_EX(),
            branch_predicted_pc_EX(),    // last because branch ends at EX
            instruction_EX(),

            i_type_branch_target_ID(),
            rs_ID(),
            rt_ID(),
            rd_ID
            RF_data1_ID(),
            RF_data2_ID(),
            imm_signed_ID(),
            write_reg_addr_ID(),

            
            i_type_branch_target_EX(),   // last because branch ends at EX
            rs_EX(),
            rt_EX(),
            rd_EX
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
            B_EX(),
            imm_signed_EX(),
            write_reg_addr_EX(),

            rs_MEM(),
            rt_MEM(),
            B_MEM(),      // for SWD`        
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
        wire pc_write;

        // IF
        wire [`WORD_SIZE - 1 : 0] branch_predicted_pc_IF
        wire [`WORD_SIZE - 1 : 0] pc_IF;
        assign pc_IF = pc;   // pc_IF : wire    pc: reg
        assign i_address = pc;
        wire tag_match_IF;

        // ID
        wire jump_miss;
        wire tag_match_ID;

        // EX
        wire i_branch_miss;

        // IF + ID + EX
        // pc update logic
        // sequential logic fot pc and num_branch_miss
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
            else
                pc <= pc;
        end