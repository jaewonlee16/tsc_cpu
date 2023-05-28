module interrupt_handler(
    // DMA signals
    input clk,
    input dma_start_int,
    input dma_end_int, // not use
    input BR,
    output reg BG,
    output reg cmd,

    // d_mem signals
    input d_readM,
    input d_writeM,
    input [4 * `WORD_SIZE - 1 : 0] d_data,
    input doneWrite_d 
);

    wire d_mem_busy;
    assign d_mem_busy = d_readM && d_data[63 : 60] == `OPCODE_NOP // when d_readM and stall
                    || d_writeM && !doneWrite_d;                  // when d_writeM and stall
    
    // after BR and d memory access change BG to 1
    always @ (posedge clk) begin
        if (BR && !d_mem_busy) BG <= 1;
    end
    // asynchronously change BG to 0 as BR
    always @ (negedge BR) begin
        BG <= 0;
    end
    // cmd
    always @ (posedge clk) begin
        cmd <= dma_start_int;
    end

endmodule