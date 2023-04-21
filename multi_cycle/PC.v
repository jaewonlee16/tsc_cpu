module PC(
    input clk,
    input reset_n,
    input en,
    input [15 : 0] pc_in,
    output [15 : 0] pc_out
    );
    reg [15 : 0] pc;
    
    assign pc_out = pc;
    
    always @ (posedge clk) begin
        if (!reset_n) pc <= 0;
        else if (en) pc <= pc_in;
    end
    
endmodule
    