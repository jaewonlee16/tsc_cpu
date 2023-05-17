module MDR(
    input inputReady,
    input reset_n,
    input [15 : 0] MDR_in,
    output reg [15 : 0] MDR_out
    );
    
    always @ (posedge inputReady) begin
        if (~reset_n) MDR_out <= 0;
        else MDR_out <= MDR_in;
    end
   
endmodule