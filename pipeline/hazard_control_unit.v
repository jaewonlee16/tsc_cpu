`timescale 1ns/1ns

`include "constants.v"
`include "opcodes.v"

module hazard_control_unit
  #(parameter DATA_FORWARDING = 1)
   (input       clk,
    input       reset_n,
    input [3:0] opcode,
    input [5:0] func_code,

    // flush input signals
    input       jump_miss, // misprediction of unconditional branch
    input       i_branch_miss, // misprediction of conditional branch

    // signals that determine when to stall
    input [1:0] rs_ID, 
    input [1:0] rt_ID, 
    input       Reg_write_EX,
    input       Reg_write_MEM,
    input       Reg_write_WB,
    input [1:0] dest_EX             // write_reg_addr_EX, 
    input [1:0] dest_MEM            // write_reg_addr_MEM, 
    input [1:0] dest_WB            // write_reg_addr_WB, 

    // load stall
    input       d_MEM_write_WB,
    input       d_MEM_read_EX,
    input       d_MEM_read_mem,
    input       d_MEM_read_WB,
    input [1:0] rt_EX, 
    input [1:0] rt_MEM,
    input [1:0] rt_WB,

    input       i_ready,
    input       i_input_ready,
    output reg  i_MEM_read,
    output reg  stall_IFID, // stall pipeline IF_ID_register
    output reg  stall_IDEX, // stall pipeline ID_EX_register
    output reg  flush_IFID, // reset IR to nop
    output reg  flush_IDEX, // reset IR to nop
    output reg  pc_write,
    output reg  ir_write,
);
   reg          use_rs, use_rs_at_ID, use_rt;