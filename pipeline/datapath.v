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
        input [1 : 0] PCSource,
        input isJump,

        // EX signal
        input reg [1 : 0] ALUSrcB,
        input reg [3: 0] ALUOperation,
        input isItype_Branch,

        // MEM signal
        input d_readM,
        input d_writeM,

        // WB signal
        input output_active,
        input is_halted,
        input [1 : 0] RegDst, // write to 0: rt, 1: rd, 2: $2 (JAL)
        input RegWrite,
        input [1 : 0] MemtoReg, // write 0: ALU, 1: MDR, 2: PC + 1


        // --------------------------- hazard_control_unit signals
        input reg  stall_IFID, // stall pipeline IF_ID_register
        input reg  flush_IFID, // flush if
        input reg  flush_IDEX, // flush id
        input reg  pc_write,
        input reg  ir_write,

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
        output [3:0]                 opcode,
        output [5:0]                 func_code,
        output                       is_halted, 
        output [WORD_SIZE-1:0]       num_inst
        
    )
        reg [WORD_SIZE-1:0]   num_branch; // total number of branches
        reg [WORD_SIZE-1:0]   num_branch_miss; // number of branch prediction miss