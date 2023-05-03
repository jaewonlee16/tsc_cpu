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
`include "constants.v"

module datapath(
    input clk,
    input reset_n,
    input [`WORD_SIZE-1:0] instruction,
    input [`WORD_SIZE-1:0] memory_data,
    
    // output ports 
    output [`WORD_SIZE-1:0] address,
    output [`WORD_SIZE-1:0] output_port,
    output [`WORD_SIZE-1:0] write_data,
    output [1 : 0] ALU_Compare,
    
    // control signal inputs    
    input [1 : 0] RegDst, // write to 0: rt, 1: rd, 2: $2 (JAL)
    input RegWrite,
    input ALUSrcA,
    input [1 : 0] ALUSrcB,
    input [3 : 0] ALUOp,
    input [1 : 0] PCSource,    
    input PC_en,
    input IorD,
    input [1 : 0] MemtoReg,
    input output_active
    );
    // PC
    wire [15 : 0] PC_in;
    wire [15 : 0] PC_out;
    
    // ID stage
   wire [1:0]           rs, rt, rd;
   wire [7:0]           imm;
   wire [11:0]          target_imm;
   wire [`WORD_SIZE-1:0] imm_signed;
   wire [15 : 0] read_data1;
   wire [15 : 0] read_data2;
   wire [1 : 0] register_addr3;
   
   //EX
   wire [15 : 0] ALU_i1;
   wire [15 : 0] ALU_i2;
   wire [15 : 0] ALU_result;
   wire [15 : 0] ALU_out;
   wire ALU_Overflow;
   
   
   // WB 
   wire [15 : 0] rf_write_data;

    RF rf(
        .write(RegWrite),
        .clk(clk),
        .reset_n(reset_n),
        .addr1(rs),
        .addr2(rt),
        .addr3(register_addr3),
        .data1(read_data1),
        .data2(read_data2),
        .data3(rf_write_data)
    );
    
    ALU ALU_UUT(
        .A(ALU_i1),
        .B(ALU_i2),
        .Cin(0),
        .OP(ALUOp),
        .C(ALU_result),
        .Cout(ALU_Overflow),
        .Compare(ALU_Compare)
    );
    
    ALUOUT ALUOut(
        .clk(clk),
        .reset_n(reset_n),
        .ALU_result(ALU_result),
        .ALU_out(ALU_out)
    );
    
    PC pc(
        .clk(clk),
        .reset_n(reset_n),
        .en(PC_en),
        .pc_in(PC_in),
        .pc_out(PC_out)
    
    );
    
    
    // ID
   // register input 
   assign rs = instruction[11:10];
   assign rt = instruction[9:8];
   assign rd = instruction[7:6];
   
   assign imm = instruction[7:0];
   assign imm_signed = {{8{imm[7]}}, imm}; //sign-extended
   assign target_imm = instruction[11:0];
      
   // pc MUX
   assign PC_in = PCSource == `PCSRC_SEQ ? ALU_result :
                  PCSource == `PCSRC_BRANCH ? ALU_out:
                  PCSource == `PCSRC_REG ? read_data1:
               /* PCSource == `PCSRC_JMP ? */ {PC_out[15 : 12], target_imm};
       
   // EX
   // ALU Src A MUX
   assign ALU_i1 = ALUSrcA == `ALUSRCA_PC ? PC_out :
                /* ALUSrcA == `ALUSRCA_REG */ read_data1;
   
   // ALU Src B MUX
   assign ALU_i2 = ALUSrcB == `ALUSRCB_REG ? read_data2 :
                   ALUSrcB == `ALUSRCB_ONE ? 1:
                   ALUSrcB == `ALUSRCB_IMM ? imm_signed: 
                /* ALUSrcB == `ALUSRCB_ZERO */ 0;
   
   // MEM
   // address MUX
   assign address = (IorD == `IORD_I) ? PC_out : ALU_out;
   
   assign write_data = read_data2;
   
   // WB
   //  write register MUX
   assign register_addr3 = RegDst == `REGDST_RT ? rt : 
                           RegDst == `REGDST_RD ? rd
                      /*  RegDst == `REGDST_2 */ : 2; // for JAL
   
   // write data MUX
   assign rf_write_data = MemtoReg == `REGWRITESRC_ALU ? ALU_out:
                          MemtoReg == `REGWRITESRC_MEM ? memory_data:
                       /* MemtoReg == `REGWRITESRC_PC */ PC_out + 1;
                       

   // output_port only when isWWD
   assign output_port = output_active ? read_data1 : 16'bz;
   
endmodule
