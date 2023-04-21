module PC(
    input clk,
    input reset_n,
    input jump,
    input [11 : 0] target_address,
    output reg [15 : 0] address
    );
    always @ (posedge clk) begin
        if (!reset_n) address <= 0;
        else if (jump) address <= {address[15 : 12], target_address};
        else address <= address + 16'd1;
    end

endmodule
    