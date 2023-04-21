module ALUOUT(
    input clk,
    input reset_n,
    input [15 : 0] ALU_result,
    output reg [15 : 0] ALU_out
    );
    
    always @ (posedge clk) begin
        if (~reset_n) ALU_out <= 0;
        else ALU_out <= ALU_result;
    end
    
    
endmodule