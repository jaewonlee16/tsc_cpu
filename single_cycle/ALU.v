`timescale 1ns / 1ps

`include "opcodes.v"

module ALU(
input [15:0] A,
input [15:0] B,
input Cin,
input [3:0] OP,
output reg [15:0]C,
output reg Cout
    );
    always @ (*)begin
    
    // As Cout is not used except for Arithmetic operations
    // Cout is intitialized to 0 by default
    Cout = 0;
    case (OP)
        // Arithmetic
        // the result of addition and subtractioin are 17bits when oveflow occurs
        // so used concatenation at Cout(carry) and C
        `OP_ADD: {Cout, C} = A + B + Cin;
        `OP_SUB: {Cout, C} = A - B - Cin;
        //  Bitwise Boolean operation
        `OP_ID: C = A;
        `OP_NAND: C = ~(A & B);
        `OP_NOR: C = ~(A | B);
        `OP_XNOR: C = ~(A ^ B);
        `OP_NOT: C = ~A;
        `OP_AND: C = A & B;
        `OP_OR: C = A | B;
        `OP_XOR: C = A ^ B;
        // Shifting
        `OP_LRS: C = A >> 1;
        // failed when using >>> operator so used concatenation instead
        //`OP_ARS: C = A >>> 1;
        `OP_ARS: C = {A[15], A[15:1]};
        `OP_RR: C = {A[0], A[15 : 1]};
        `OP_LLS: C = A << 1;
	    `OP_ALS: C = A <<< 1;
        `OP_LHI: C = {B[7 : 0], 8'h00};
        endcase
    end
    
endmodule
