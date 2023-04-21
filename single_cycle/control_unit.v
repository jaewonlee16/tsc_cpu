`define typeR 4'b1111
`include "opcodes.v"

module control_unit(
     input reset_n,
     input [3 : 0] opcode,
     input [5 : 0] func_code,
     output RegDst,
     output Jump,
     output reg [3: 0] ALUOperation,
     output ALUSrc,
     output reg RegWrite,
     output isWWD
    );
    
    
    assign RegDst = (opcode == `typeR) ? 1 : 0;
    assign Jump = (opcode == `OPCODE_JMP || opcode == `OPCODE_JAL) ? 1 : 0;
    assign ALUSrc = (opcode == `typeR) ? 0 : 1;
    assign isWWD = (opcode == `typeR && func_code == `FUNC_WWD) ? 1 : 0;
   
    
    always @ (*) begin
    case (opcode)
        `typeR: begin
            case (func_code)
                `FUNC_ADD : begin ALUOperation = `OP_ADD; RegWrite =1; end
                `FUNC_WWD : begin ALUOperation = `OP_ID; RegWrite = 0; end
            endcase
        end
        
        `OPCODE_ADI: begin
            ALUOperation = `OP_ADD;
            RegWrite = 1;
        end
        
        `OPCODE_LHI: begin
            ALUOperation = `OP_LHI;
            RegWrite = 1;
        end
        
        `OPCODE_JMP: begin
            RegWrite = 0;
         end
     endcase 
     end  
    
endmodule