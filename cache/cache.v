module cache
   (
    input clk,
    input reset_n,
    input read_cache,
    input write_cache,
    input [WORD_SIZE-1:0]      address_cache,
    inout [WORD_SIZE-1:0]      data_cache_datapath, // data connected to datapath
    inout [READ_SIZE-1:0]      data_mem_cache, // data connected to memory

    // issue memory access for cache misses
    output                      doneWrite,
    output [WORD_SIZE-1:0]     addressM,
    output reg                 readM,
    output reg                 writeM,
    output reg [WORD_SIZE-1:0] num_cache_access,
    output reg [WORD_SIZE-1:0] num_cache_miss,
   );
    reg [WORD_SIZE-1:0] num_cache_access,
    reg [WORD_SIZE-1:0] num_cache_miss,