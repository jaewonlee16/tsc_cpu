`timescale 1ns / 1ps

`include "opcodes.v"
`include "constants.v"


module ALU(
input [15:0] A,
input [15:0] B,
input Cin,
input [3:0] OP,
output reg [15:0]C,
output reg Cout,
output [1:0] Compare  // 00 : same, 10 : bigger(>), 11 : smaller(<)
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
        
        `OP_TCP: C = -A;
        `OP_SHL: C = {A[14 : 0], 1'b0};
        `OP_SHR: C = {A[15], A[15 : 1]};
        `OP_LHI: C = {B[7 : 0], 8'h00};
        default : C = 16'hz;
        endcase
    end
    
    // 00 : same (=), 10 : greater than (>), 11 : less than (<)
     assign Compare = ( OP==`OP_SUB ? ( C == `WORD_SIZE'h0 ? `ALU_SAME : {1'b1,C[`WORD_SIZE - 1]} ) : 2'bzz );

endmodule