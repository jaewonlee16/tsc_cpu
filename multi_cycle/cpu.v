`timescale 1ns/100ps

`include "opcodes.v"
`include "constants.v"

module cpu (
    output readM, // read from memory
    output writeM, // write to memory
    output [`WORD_SIZE-1:0] address, // current address for data
    inout [`WORD_SIZE-1:0] data, // data being input or output
    input inputReady, // indicates that data is ready from the input port
    input reset_n, // active-low RESET signal
    input clk, // clock signal
    
    // for debuging/testing purpose
    output reg [`WORD_SIZE-1:0] num_inst, // number of instruction during execution
    output [`WORD_SIZE-1:0] output_port, // this will be used for a "WWD" instruction
    output is_halted // 1 if the cpu is halted
);
    // ... fill in the rest of the code
    //instruction wire
    wire [`WORD_SIZE - 1 : 0] instruction;
    wire [3:0] opcode;
    wire [5:0] func_code;
    
    // memory data
    wire [`WORD_SIZE - 1 : 0] memory_data;
    wire [`WORD_SIZE - 1 : 0] write_data;
    
    // branch condition
    wire [1 : 0] ALU_Compare;
    
     // control wires
     wire [1 : 0] RegDst;
     wire RegWrite;
     wire ALUSrcA;
     wire [1 : 0] ALUSrcB;
     wire [3: 0] ALUOperation;
     wire [1 : 0] PCSource;
     wire PC_en;
     wire IorD;
     wire readM;
     wire [1 : 0] MemtoReg;
     wire IRWrite;
     wire PVSWrite;
     wire output_active;
     wire ALU_Cin;
    
    // module
    control_unit contol(
        .reset_n(reset_n),
        .clk(clk),
        .opcode(opcode),
        .func_code(func_code),
        .ALU_Compare(ALU_Compare),
     
        .RegDst(RegDst),
        .RegWrite(RegWrite),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ALUOperation(ALUOperation),
        .PCSource(PCSource),
        .PC_en(PC_en),
        .IorD(IorD),
        .readM(readM),
        .MemWrite(writeM),
        .MemtoReg(MemtoReg),
        .IRWrite(IRWrite),
        .PVSWrite(PVSWrite),
        .output_active(output_active),
        .is_halted(is_halted)
    );
    
    IR ir(
        .inputReady(inputReady),
        .reset_n(reset_n),
        .IRWrite(IRWrite),
        .data(data),
        .instruction(instruction)
    );
    
    MDR mdr(
        .inputReady(inputReady),
        .reset_n(reset_n),
        .MDR_in(data),
        .MDR_out(memory_data)
    );
    
    datapath DP(
        .clk(clk),
        .reset_n(reset_n),
        .instruction(instruction),
        .memory_data(memory_data),
    
        // output ports 
        .address(address),
        .output_port(output_port),
        .write_data(write_data),
        .ALU_Compare(ALU_Compare),
    
        // control signal inputs    
        .RegDst(RegDst),
        .RegWrite(RegWrite),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ALUOp(ALUOperation),
        .PCSource(PCSource),    
        .PC_en(PC_en),
        .IorD(IorD),
        .MemtoReg(MemtoReg),
        .output_active(output_active)
    );
    
    assign data = (writeM ? write_data : `WORD_SIZE'hz);
    
    
    // decode instructions for control_unit
    assign opcode = instruction[15 : 12];   
    assign func_code = instruction[5 : 0];
    
    // num_inst
    always @(posedge clk) begin
        if(~reset_n) num_inst = 1;
        else if(PVSWrite) num_inst = num_inst + 1;
    end
    
    
endmodule