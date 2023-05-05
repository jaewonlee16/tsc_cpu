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
        output [WORD_SIZE-1:0]       i_address,
        output [WORD_SIZE-1:0]       d_address,
        output                       i_readM,
        output                       d_readM,
        output                       i_writeM,
        output                       d_writeM,
        inout [WORD_SIZE-1:0]        i_data,
        inout [WORD_SIZE-1:0]        d_data,
        output reg [WORD_SIZE-1:0]   output_port,
        output                       is_halted, 
        output [WORD_SIZE-1:0]       num_inst
        
    )
        reg [WORD_SIZE-1:0]   num_branch; // total number of branches
        reg [WORD_SIZE-1:0]   num_branch_miss; // number of branch prediction miss


        // --------------- modules ----------------
        // hazard_control_unit
        hazard_control_unit #(.DATA_FORWARDING(DATA_FORWARDING))
        hazard (
            .opcode(opcode),
            .func_code(func_code),

            // flush .signals
            .jump_miss(), // misprediction of unconditional branch
            .i_branch_miss(), // misprediction of conditional branch

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
            .pc_write(),
            .ir_write()
        );
