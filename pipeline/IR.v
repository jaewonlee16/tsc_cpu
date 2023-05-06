module IR (
    input clk,
    input reset_n,

    input IRWrite,
    input [15 : 0] data,
    output reg [15 : 0] instruction
    );
    reg reset_after;
    
    always @ (posedge clk) begin
        if (~reset_n) begin 
            instruction <= {`OPCODE_NOP, {12{1'b0}}}; 
            reset_after <= 1;
        end
        /* else if (reset_after) begin 
            instruction <= {`OPCODE_NOP, {12{1'b0}}};
            reset_after <= 0;
        end */
        else if (IRWrite) instruction <= data;

    end
   
endmodule