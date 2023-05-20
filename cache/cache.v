module cache
   (
    input clk,
    input reset_n,
    input read_cache,
    input write_cache,
    input [WORD_SIZE-1:0] address_cache,
    inout [WORD_SIZE-1:0] data_cache_datapath, // data connected to datapath
    inout [READ_SIZE-1:0] data_mem_cache, // data connected to memory

    output doneWrite,  // tells the cpu that writing is finshed
    output [WORD_SIZE-1:0] address_memory,
    output reg readM,
    output reg writeM,
   );
    reg [WORD_SIZE-1:0] num_cache_access,    // for debugging
    reg [WORD_SIZE-1:0] num_cache_miss,      // for debugging

    