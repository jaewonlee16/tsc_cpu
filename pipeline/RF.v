`timescale 1ns / 1ps


module RF(
    input write,
    input clk,
    input reset_n,
    input [1:0] addr1,
    input [1:0] addr2,
    input [1:0] addr3,
    input [1:0] wwd_addr,
    output reg [15 : 0] data1,
    output reg [15 : 0] data2,
    input [15 : 0] data3,
    output reg [15 : 0] wwd_data
    );
    
    reg [15 : 0] register [3 : 0];
    
    integer index;
    
    // combinational logic
    always @ (*)
    begin
        data1 = register[addr1];
        data2 = register[addr2];
        wwd_data = register[wwd_addr];
    end
    
    // sequential logic
    always @ (negedge clk)
    begin
        // reset all values of regiser to 0
        if (!reset_n) for (index = 0; index < 4; index = index + 1) register[index] <= 0;
        // write if only write is 1
        else if (write) register[addr3] <= data3;
    end
endmodule