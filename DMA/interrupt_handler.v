module interrupt_handler(
    // DMA signals
    input clk,
    input dma_start_int,
    input dma_end_int, // not use
    input BR,
    output reg BG,
    output cmd,

    // d_mem signals
    input d_readM,
    input d_writeM,
    input [4 * `WORD_SIZE - 1 : 0] d_data,
    input doneWrite_d 
);

    wire d_mem_busy;
    assign d_mem_busy = d_readM && d_data[63 : 60] == `OPCODE_NOP
                    || d_writeM && !doneWrite_d;
    always @ (posedge clk) begin
        if (BR && !d_mem_busy) BG <= 1;
        else if (!BR) BG <= 0;
    end

    // cmd
    always @ (posedge clk) begin
        cmd <= dma_start_int;
    end

endmodule