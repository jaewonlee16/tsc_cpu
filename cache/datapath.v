`timescale 1ns / 1ns
`include "constants.v"
`include "opcodes.v"
module datapath
  #(parameter DATA_FORWARDING = 1,
    parameter BRANCH_PREDICTOR = `BRANCH_ALWAYS_TAKEN)
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
        output reg [`WORD_SIZE-1:0]  num_inst,

        input doneWrite_d
        
    );
        // reg declaration
        reg [`WORD_SIZE-1:0]   num_branch; // total number of branches
        reg [`WORD_SIZE-1:0]   num_branch_miss; // number of branch prediction miss
        reg [`WORD_SIZE - 1 : 0] pc;


        


        // ------------------------------------ modules --------------------------------
        // hazard_control_unit
        hazard_control_unit #(.DATA_FORWARDING(DATA_FORWARDING))
        hazard (
            .clk(clk),
            .reset_n(reset_n),
            .opcode(opcode),
            .func_code(func_code),

            // flush .signals
            .jump_miss(jump_miss_for_pc_update), // misprediction of unconditional branch
            .i_branch_miss(i_branch_miss), // misprediction of conditional branch

            // signals that determine when to stall
            .rs_ID(rs_ID), 
            .rt_ID(rt_ID), 
            .Reg_write_EX(RegWrite_EX),
            .Reg_write_MEM(RegWrite_MEM),
            .Reg_write_WB(RegWrite_WB),
            .dest_EX(write_reg_addr_EX),             // write_reg_addr_EX 
            .dest_MEM(write_reg_addr_MEM),            // write_reg_addr_MEM 
            .dest_WB(write_reg_addr_WB),            // write_reg_addr_WB 

            // load stall
            .d_MEM_read_EX(d_readM_EX),
            .d_MEM_read_MEM(d_readM_MEM),
            .rt_EX(rt_EX), 
            .rt_MEM(rt_MEM),
            .rt_WB(rt_WB),

            .d_MEM_write_MEM(d_writeM_MEM),
            .d_data_opcode(d_data[15 : 12]),

            // control signals
            .stall_IFID(stall_IFID), // stall pipeline IF_ID_register
            .stall_IDEX(stall_IDEX),
            .stall_EXMEM(stall_EXMEM),
            .flush_IFID(flush_IFID), // flush if
            .flush_IDEX(flush_IDEX), // flush id
            .flush_MEMWB(flush_MEMWB),
            .pc_write(pc_write),
            .ir_write(ir_write)
        );

        // branch_predictor
        branch_predictor #(.BRANCH_PREDICTOR(BRANCH_PREDICTOR))
        bp (

            .clk(clk),
            .reset_n(reset_n), // clear BTB to all zero

            // IF
            .pc(pc_IF), // the pc that was just fetched

            // ID
            .update_tag(update_tag), // update tag as soon as decode (when target is known)
            .pc_for_btb_update(pc_ID), // PC collision tag 
            .branch_target_for_btb_update(branch_target), // branch target of jump and i type branch.

            // ID or EX
            .update_bht(update_bht), // update BHT when know prediction was correct or not
            .pc_for_bht_update(pc_for_bht_update),        // The actual pc that is calculated (not predicted)
                            // pc_ex(i type branch) or pc_id(jump)
            .branch_correct_or_notCorrect(branch_correct_or_notCorrect), // if the predicted pc is same as the actual pc

            // IF
            .tag_match(tag_match_IF), // tag matched PC
            .branch_predicted_pc(branch_predicted_pc_IF) // predicted next PC
        );   

        RF rf(
            .write(RegWrite_WB),
            .clk(clk),
            .reset_n(reset_n),
            .addr1(rs_ID),
            .addr2(rt_ID),
            .addr3(write_reg_addr_WB),
            .wwd_addr(wwd_addr),
            .data1(RF_data1_ID),
            .data2(RF_data2_ID),
            .data3(RF_write_data),
            .wwd_data(wwd_data)
        );
        
        ALU ALU_UUT(
            .A(ALU_in_A),
            .B(ALU_in_B),
            .Cin(0),
            .OP(ALUOperation_EX),
            .C(ALU_result_EX),
            .Cout(ALU_overflow),
            .Compare(ALU_Compare)
        );

        // pipeline_register.v
        IF_ID_register IF_to_ID(
            .clk(clk),
            .reset_n(reset_n),
            .flush(flush_IFID),
            .stall(stall_IFID),
            .pc_IF(pc_IF),
            .branch_predicted_pc_IF(branch_predicted_pc_IF),
            .instruction_IF(instruction_IF),
            .tag_match_IF(tag_match_IF),
            .pc_ID(pc_ID),
            .branch_predicted_pc_ID(branch_predicted_pc_ID),
            .instruction_ID(instruction_ID),
            .tag_match_ID(tag_match_ID)


        );

        ID_EX_register ID_to_EX(
            .clk(clk),
            .reset_n(reset_n),
            .flush(flush_IDEX),
            .stall(stall_IDEX),

            // ----------------------------- control signal inputs and outputs
            // input ports
            .isJump_ID(isJump),

            // EX
            .ALUSrcB_ID(ALUSrcB),
            .ALUOperation_ID(ALUOperation),
            .isItype_Branch_ID(isItype_Branch),

            // MEM
            .d_readM_ID(d_readM_ID),
            .d_writeM_ID(d_writeM_ID),

            // WB
            .output_active_ID(output_active),
            .is_halted_ID(is_halted_ID), 
            .RegDst_ID(RegDst), // write to 0: rt, 1: rd, 2: $2 (JAL)
            .RegWrite_ID(RegWrite),
            .MemtoReg_ID(MemtoReg), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // output ports
            .isJump_EX(isJump_EX),

            // EX
            .ALUSrcB_EX(ALUSrcB_EX),
            .ALUOperation_EX(ALUOperation_EX),
            .isItype_Branch_EX(isItype_Branch_EX),

            // MEM
            .d_readM_EX(d_readM_EX),
            .d_writeM_EX(d_writeM_EX),

            // WB
            .output_active_EX(output_active_EX),
            .is_halted_EX(is_halted_EX), 
            .RegDst_EX(RegDst_EX), // write to 0: rt, 1: rd, 2: $2 (JAL)
            .RegWrite_EX(RegWrite_EX),
            .MemtoReg_EX(MemtoReg_EX), // write 0: ALU, 1: MDR, 2: PC + 1

            // ----------------------------------- Data latch
            .pc_ID(pc_ID),
            .branch_predicted_pc_ID(branch_predicted_pc_ID),
            .instruction_ID(instruction_ID),

            .pc_EX(pc_EX),
            .branch_predicted_pc_EX(branch_predicted_pc_EX),    // last because branch ends at EX
            .instruction_EX(instruction_EX),

            .i_type_branch_target_ID(i_type_branch_target_ID),
            .rs_ID(rs_ID),
            .rt_ID(rt_ID),
            .rd_ID(rd_ID),
            .RF_data1_ID(RF_data1_ID),
            .RF_data2_ID(RF_data2_ID),
            .imm_signed_ID(imm_signed_ID),
            .write_reg_addr_ID(write_reg_addr_ID),

            
            .i_type_branch_target_EX(i_type_branch_target_EX),   // last because branch ends at EX
            .rs_EX(rs_EX),
            .rt_EX(rt_EX),
            .rd_EX(rd_EX),
            .RF_data1_EX(RF_data1_EX),
            .RF_data2_EX(RF_data2_EX),
            .imm_signed_EX(imm_signed_EX),
            .write_reg_addr_EX(write_reg_addr_EX)

        );

        EX_MEM_register EX_to_MEM(

            .clk(clk),
            .reset_n(reset_n),
            .flush(flush_EXMEM),
            .stall(stall_EXMEM),

            // ----------------------------- control signal inputs and outputs
            // ports
            // MEM
            .d_readM_EX(d_readM_EX),
            .d_writeM_EX(d_writeM_EX),

            // WB
            .output_active_EX(output_active_EX),
            .is_halted_EX(is_halted_EX), 
            .RegDst_EX(RegDst_EX), // write to 0: rt, 1: rd, 2: $2 (JAL)
            .RegWrite_EX(RegWrite_EX),
            .MemtoReg_EX(MemtoReg_EX), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ports
            // MEM
            .d_readM_MEM(d_readM_MEM),
            .d_writeM_MEM(d_writeM_MEM),

            // WB
            .output_active_MEM(output_active_MEM),
            .is_halted_MEM(is_halted_MEM), 
            .RegDst_MEM(RegDst_MEM), // write to 0: rt, 1: rd, 2: $2 (JAL)
            .RegWrite_MEM(RegWrite_MEM),
            .MemtoReg_MEM(MemtoReg_MEM), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ----------------------------------- Data latch
            .pc_EX(pc_EX),
            .instruction_EX(instruction_EX),

            .pc_MEM(pc_MEM),
            .instruction_MEM(instruction_MEM),

            .rs_EX(rs_EX),
            .rt_EX(rt_EX),
            .RF_data2_EX(RF_data2_EX),
            .imm_signed_EX(imm_signed_EX),
            .write_reg_addr_EX(write_reg_addr_EX),

            .rs_MEM(rs_MEM),
            .rt_MEM(rt_MEM),
            .RF_data2_MEM(RF_data2_MEM),      // for SWD`        
            .imm_signed_MEM(imm_signed_MEM),
            .write_reg_addr_MEM(write_reg_addr_MEM),

            .ALU_result_EX(ALU_result_EX),
            .ALU_out_MEM(ALU_out_MEM)
        );

        MEM_WB_register MEM_to_WB(

            .clk(clk),
            .reset_n(reset_n),
            .flush(flush_MEMWB),
            .stall(stall_MEMWB),

            // ----------------------------- control signal inputs and outputs
            // ports
            // WB
            .output_active_MEM(output_active_MEM),
            .is_halted_MEM(is_halted_MEM), 
            .RegDst_MEM(RegDst_MEM), // write to 0: rt, 1: rd, 2: $2 (JAL)
            .RegWrite_MEM(RegWrite_MEM),
            .MemtoReg_MEM(MemtoReg_MEM), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ports
            // WB
            .output_active_WB(output_active_WB),
            .is_halted_WB(is_halted), 
            .RegDst_WB(RegDst_WB), // write to 0: rt, 1: rd, 2: $2 (JAL)
            .RegWrite_WB(RegWrite_WB),
            .MemtoReg_WB(MemtoReg_WB), // write 0: ALU, 1: MDR, 2: PC + 1
            
            // ----------------------------------- Data latch
            .pc_MEM(pc_MEM),
            .instruction_MEM(instruction_MEM),

            .pc_WB(pc_WB),
            .instruction_WB(instruction_WB),

            .rs_MEM(rs_MEM),
            .rt_MEM(rt_MEM),
            .imm_signed_MEM(imm_signed_MEM),
            .write_reg_addr_MEM(write_reg_addr_MEM),

            .rs_WB(rs_WB),
            .rt_WB(rt_WB),
            .imm_signed_WB(imm_signed_WB),
            .write_reg_addr_WB(write_reg_addr_WB),

            .ALU_out_MEM(ALU_out_MEM),
            .ALU_out_WB(ALU_out_WB),

            .MDR_MEM(d_data),
            .MDR_WB(MDR_WB)
        );


        // ------------------------  Datapath  ------------------------ //

        // pipeline register control wires
        wire flush_IFID, flush_IDEX, flush_EXMEM, flush_MEMWB;
        wire stall_IFID, stall_IDEX, stall_EXMEM, stall_MEMWB;

        assign flush_EXMEM = 0;
        assign stall_MEMWB = 0;

        //  ----------------------- IF STAGE --------------------------
        // -------------------------------------------------------------
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
        // ---------------------------------------------------------------
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
        assign jump_target = (opcode == `typeR && (func_code == `FUNC_JPR || func_code == `FUNC_JRL)) ?
                        RF_data1_ID :
                        {pc[15:12], jump_target_imm};
        assign i_type_branch_target_ID = (pc_ID + 1) + imm_signed_ID;
        assign branch_target = isJump ? jump_target :i_type_branch_target_ID;
        assign jump_miss = isJump && (jump_target != branch_predicted_pc_ID) ? 1 : 0;
        
        // jump_miss is 1 as soon as jump misprediction is detected
        // However, you should not update pc if jump_miss because memory or cache can be busy
        // therefore, jump_miss_for_pc_update waits until memory or cache is not busy
        reg jump_miss_for_pc_update;
        reg [`WORD_SIZE - 1 : 0] jump_target_for_pc_update;
        always @ (posedge clk) begin
            if (~reset_n) begin
                jump_miss_for_pc_update <= 0;
                jump_target_for_pc_update <= 0;
            end
            else if (jump_miss) begin
                jump_miss_for_pc_update <= 1;
                jump_target_for_pc_update <= jump_target;
            end
            else if (instruction_IF[15 : 12] != `OPCODE_NOP) begin // when memory or cache is not busy
                jump_miss_for_pc_update <= 0;
                jump_target_for_pc_update <= jump_target;
            end
        end

        // If this is a branch instruction and BTB tag match failed in IF,
        // update tag in ID stage.
        assign update_tag = ((isJump || isItype_Branch) && !tag_match_ID) ? 1 : 0;


        // ------------------------- EX STAGE ------------------------------
        // -----------------------------------------------------------------
        // -- pipeline register wires -- //
        // control signal wires
        wire isJump_EX;

        wire [1 : 0] ALUSrcB_EX;
        wire [3 : 0] ALUOperation_EX;
        wire isItype_Branch_EX;

        wire d_readM_EX;
        wire d_writeM_EX;

        wire output_active_EX;
        wire is_halted_EX;
        wire [1 : 0] RegDst_EX;
        wire RegWrite_EX;
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
        
        wire [`WORD_SIZE - 1 : 0] ALU_result_EX;


        // ------------forwarding -----------

        wire [1 : 0] forwardA_src, forwardB_src;

        // forwardA
        assign forwardA_src = DATA_FORWARDING && RegWrite_MEM && rs_EX == write_reg_addr_MEM ? `FORWARD_SRC_MEM: 
                              DATA_FORWARDING && RegWrite_WB && rs_EX == write_reg_addr_WB ? `FORWARD_SRC_WB:
                                                                                   `FORWARD_SRC_RF;
           
        // forwardB
        assign forwardB_src = DATA_FORWARDING && RegWrite_MEM && rt_EX == write_reg_addr_MEM ? `FORWARD_SRC_MEM: 
                              DATA_FORWARDING && RegWrite_WB && rt_EX == write_reg_addr_WB ? `FORWARD_SRC_WB:
                                                                                   `FORWARD_SRC_RF;

        // ----------- ALU.v wires -----------
        
        wire [`WORD_SIZE - 1 : 0] ALU_in_A, ALU_in_B;
        assign ALU_in_A = forwardA_src == `FORWARD_SRC_MEM ? ALU_out_MEM:
                          forwardA_src == `FORWARD_SRC_WB ? RF_write_data:
                          RF_data1_EX; 
        assign ALU_in_B = ALUSrcB_EX == `ALUSRCB_ZERO ? 0:
                          ALUSrcB_EX == `ALUSRCB_IMM ? imm_signed_EX:
                          forwardB_src == `FORWARD_SRC_MEM ? ALU_out_MEM:
                          forwardB_src == `FORWARD_SRC_WB ? RF_write_data:
                          RF_data2_EX; 

        wire ALU_overflow;
        wire [1 : 0] ALU_Compare;

        // ------- Branch Predictor wires ------ //
        wire [3 : 0] opcode_EX;
        wire isBranchTaken;
        wire i_branch_miss;
        wire [`WORD_SIZE - 1 : 0] calculated_pc_EX;
        wire update_bht;
        wire branch_correct_or_notCorrect;
        wire [`WORD_SIZE - 1 : 0] pc_for_bht_update;

        assign opcode_EX = instruction_EX[15 : 12];
        // decide if the branch instruction is taken or not taken
        assign isBranchTaken = (opcode_EX == `OPCODE_BNE && (ALU_Compare == `ALU_BIG || ALU_Compare == `ALU_SMALL) // not equal
                             || opcode_EX == `OPCODE_BEQ && ALU_Compare == `ALU_SAME  // equal
                             || opcode_EX == `OPCODE_BGZ && ALU_Compare == `ALU_BIG  // greater than
                             || opcode_EX == `OPCODE_BLZ && ALU_Compare == `ALU_SMALL) ? 1 : 0;  // less than
        // the actual calculated next pc for i type branches
        assign calculated_pc_EX = (isItype_Branch_EX && isBranchTaken) ? i_type_branch_target_EX : pc_EX + 1;
        assign update_bht = isItype_Branch_EX || isJump;
        assign branch_correct_or_notCorrect = isItype_Branch_EX ? branch_predicted_pc_EX == calculated_pc_EX:
                                              isJump ? ~jump_miss : 1;
        assign i_branch_miss = isItype_Branch_EX && (branch_predicted_pc_EX != calculated_pc_EX) ? 1 : 0;

        // ID + EX
        // note that calculated_pc_EX is the next pc
        // whereas bht is updated with the current pc
        // which is "pc_for_bht_update"
        assign pc_for_bht_update = isItype_Branch_EX ? pc_EX:
                                   isJump ? pc_ID: 0;

        // IF + ID + EX
        // pc update logic
        // sequential logic for pc and num_branch_miss
        always @ (posedge clk) begin
            
            if (pc_write) begin
                if (~reset_n) begin
                    pc <= 0;
                    num_branch_miss <= 0;
                end
                // i_branch first becaus it is instruction from EX stage
                else if (i_branch_miss) begin 
                    pc <= calculated_pc_EX;
                    num_branch_miss <= num_branch_miss + 1;
                end
                else if (jump_miss_for_pc_update) begin
                    pc <= jump_target_for_pc_update;
                    num_branch_miss <= num_branch_miss + 1;
                end
                else if (instruction_IF[15 : 12] == `OPCODE_NOP) pc <= pc;
                else
                    pc <= branch_predicted_pc_IF;
            end
            else // stall
                pc <= pc;
        end

        // num_branch
        always @ (posedge clk) begin
            if (~reset_n) num_branch <= 0;
            else if (isItype_Branch_EX || isJump_EX) num_branch <= num_branch + 1;
            else num_branch <= num_branch;
        end


        // --------------------------- MEM -------------------------------//
        // ---------------------------------------------------------------//
        // pipeline wires
        wire d_readM_MEM;
        wire d_writeM_MEM;
        
        wire output_active_MEM;
        wire is_halted_MEM;
        wire [1 : 0] RegDst_MEM;
        wire RegWrite_MEM;
        wire [1 : 0] MemtoReg_MEM;

        wire [`WORD_SIZE - 1 : 0] pc_MEM;
        wire [`WORD_SIZE - 1 : 0] instruction_MEM;

        wire [1 : 0] rs_MEM;
        wire [1 : 0] rt_MEM;
        wire [`WORD_SIZE - 1 : 0] RF_data2_MEM;
        wire [`WORD_SIZE - 1 : 0] imm_signed_MEM;
        wire [1 : 0] write_reg_addr_MEM;
        
        wire [`WORD_SIZE - 1 : 0] ALU_out_MEM;

        assign d_readM = d_readM_MEM;
        assign d_writeM = d_writeM_MEM;
        assign d_address = ALU_out_MEM;
        assign d_data = d_writeM ? RF_data2_MEM : 16'bz;


        // ------------------------- WB ----------------------------------//
        // ---------------------------------------------------------------//
        // pipeline wires
        wire output_active_WB;
        wire [1 : 0] RegDst_WB;
        wire RegWrite_WB;
        wire [1 : 0] MemtoReg_WB;

        wire [`WORD_SIZE - 1 : 0] pc_WB;
        wire [`WORD_SIZE - 1 : 0] instruction_WB;

        wire [1 : 0] rs_WB, rt_WB;
        wire [`WORD_SIZE - 1 : 0] imm_signed_WB;
        wire [1 : 0] write_reg_addr_WB;
        wire [`WORD_SIZE - 1 : 0] ALU_out_WB;
        wire [`WORD_SIZE - 1 : 0] MDR_WB;

        // RF write
        wire [`WORD_SIZE - 1 : 0] RF_write_data;
        assign RF_write_data = MemtoReg_WB == `REGWRITESRC_ALU ? ALU_out_WB:
                               MemtoReg_WB == `REGWRITESRC_MEM ? MDR_WB:
                               /* `REGWRITESRC_PC */ pc_WB + 1;
         
        // WWD
        // another RF port is used for WWD
        // By doing this, no need to stall at WWD instructions
        // because WWD reads after write is finished
        wire [1 : 0] wwd_addr;
        wire [`WORD_SIZE - 1 : 0] wwd_data;
        assign wwd_addr = output_active_WB ? rs_WB : 2'bz;

        // num_inst
        // update num_inst at WB stage which is the end of pipeline
        // but don't update nop
        wire [3 : 0] opcode_MEM;
        wire [3 : 0] opcode_WB;
        assign opcode_MEM = instruction_MEM[15 : 12];
        assign opcode_WB = instruction_WB[15 : 12];

        always @ (posedge clk) begin
            if (~reset_n) num_inst <= 0;
            else if (opcode_WB == `OPCODE_NOP) num_inst <= num_inst;
            else num_inst <= num_inst + 1;
        end
        
        // output port
        // Because of nop num_inst can have the same value for more than 2 cycles
        // In order to sync with num_inst and output_port, output_port is latched
        always @ (posedge clk) begin
            if (output_active_WB) output_port <= wwd_data;
            else output_port <= output_port;
        end



endmodule
