module IR (
    input inputReady,
    input reset_n,
    input IRWrite,
    input [15 : 0] data,
    output reg [15 : 0] instruction
    );
    
    always @ (posedge inputReady) begin
        if (~reset_n) instruction <= 0;
        else if (IRWrite) instruction <= data;
    end
   
endmodule