module IR (
    input clk,
    input reset_n,
    input nop,
    input IRWrite,
    input [15 : 0] data,
    output reg [15 : 0] instruction
    );
    
    always @ (posedge clk) begin
        if (~reset_n) instruction <= 0;
        else if (nop) instruction <= {16{1'b1}};
        else if (IRWrite) instruction <= data;
    end
   
endmodule