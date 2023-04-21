`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/03/27 19:38:58
// Design Name: 
// Module Name: datapath
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define WORD_SIZE 16

module datapath(
    input clk,
    input reset_n,
    input inputReady,
    inout [`WORD_SIZE-1:0] data,
    output reg readM,
    output [`WORD_SIZE-1:0] address,
    output reg [`WORD_SIZE-1:0] num_inst,
    output [`WORD_SIZE-1:0] output_port,
        
    input RegDst,
    input RegWrite,
    input ALUSrc,
    input [3 : 0] ALUOp,    
    input Jump,
    input isWWD,
        
    input [3 : 0] opcode,
    input [5 : 0] func_code
        
    );
    
    // ID stage
   wire [1:0]           rs, rt, rd;
   wire [7:0]           imm;
   wire [11:0]          target_imm;
   wire [`WORD_SIZE-1:0] imm_signed;
   wire [15 : 0] read_data1;
   wire [15 : 0] read_data2;
   wire [1 : 0] register_addr3;
   
   //EX
   wire [15 : 0] ALU_i2;
   wire [15 : 0] ALU_out;
   wire ALU_Overflow;
   

    RF rf(
        .write(RegWrite),
        .clk(clk),
        .reset_n(reset_n),
        .addr1(rs),
        .addr2(rt),
        .addr3(register_addr3),
        .data1(read_data1),
        .data2(read_data2),
        .data3(ALU_out)
    );
    
    ALU ALU_UUT(
        .A(read_data1),
        .B(ALU_i2),
        .Cin(1'b0),
        .OP(ALUOp),
        .C(ALU_out),
        .Cout(ALU_Overflow)
    );
    
    PC pc(
        .clk(clk),
        .reset_n(reset_n),
        .jump(Jump),
        .target_address(target_imm),
        .address(address)
    
    );
        
    
   // register input 
   assign rs = data[11:10];
   assign rt = data[9:8];
   assign rd = data[7:6];
   assign register_addr3 = RegDst ? rd : rt; // MUX
   
   
   assign imm = data[7:0];
   assign imm_signed = {{8{imm[7]}}, imm}; //sign-extended
   assign target_imm = data[11:0];
   
   //ALU input
   assign ALU_i2 = ALUSrc ? imm_signed : read_data2; // MUX
   
   // output_port only when isWWD
   assign output_port = isWWD ? read_data1 : 16'bz;
   
   //num_inst
   always @ (posedge clk) begin
      if (!reset_n) num_inst <= 1;
      else num_inst <= num_inst + 1; readM = 1;
   end
   
   // readM
   always @ (posedge inputReady) begin
        readM <= 0;
    end
   
endmodule
