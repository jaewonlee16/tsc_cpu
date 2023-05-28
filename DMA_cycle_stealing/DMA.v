`define WORD_SIZE 16
/*************************************************
* DMA module (DMA.v)
* input: clock (CLK), bus grant (BG) signal, 
*        data from the device (edata), and DMA command (cmd)
* output: bus request (BR) signal 
*         WRITE signal
*         memory address (addr) to be written by the device, 
*         offset device offset (0 - 2)
*         data that will be written to the memory
*         interrupt to notify DMA is end
* You should NOT change the name of the I/O ports and the module name
* You can (or may have to) change the type and length of I/O ports 
* (e.g., wire -> reg) if you want 
* Do not add more ports! 
*************************************************/

// fixed address and length
`define ADDRESS 16'h01F4
`define LENGTH 16'd12

module DMA (
    input CLK, BG,
    input [4 * `WORD_SIZE - 1 : 0] edata,
    input cmd,
    output reg BR, 
    output WRITE,
    output [`WORD_SIZE - 1 : 0] addr, 
    output [4 * `WORD_SIZE - 1 : 0] data,
    output [1:0] offset,
    output interrupt); 
    

    /* Implement your own logic */
    initial begin
        counter <= 0;
        BR <= 0;
    end


    // BR logic;
    // BR is 1 after cmd and turns to 0 when write ends (when counter is LENGTH)
    always @ (posedge CLK) begin
        if (cmd) BR <= 1;
        else if (BR == 0 && (counter == `LENGTH - 8 || counter == `LENGTH -4)) BR <= 1;   // cycle stealing: set BR to 1 every 1 word
        // because of cycle stealing.set BR to 0 after 1 word dma write
        else if (counter == `LENGTH - 1 || counter == `LENGTH - 5 || counter == `LENGTH - 9) BR <= 0;
    end


    // Write
    assign WRITE = BG;

    // data
    assign data = BG ? edata : 64'hz;

    // addr
    assign addr = BG ? `ADDRESS + 4 * offset : `WORD_SIZE'hz;

    // offset
    reg [`WORD_SIZE - 1 : 0] counter;
    always @ (posedge CLK) begin
        if (BG && counter == `LENGTH) counter <= 0;
        else if (BG) counter <= counter + 1;
    end

    assign offset = counter >> 2; // divide by 4


    // not use interrupt
    // instead use BR to see if interrupt ended
    // assign interrupt = counter == `LENGTH - 1;


endmodule


