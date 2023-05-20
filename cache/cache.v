module cache
   (
    input clk,
    input reset_n,
    input read_cache,
    input write_cache,
    input [WORD_SIZE-1:0] address_cache,
    inout [WORD_SIZE-1:0] data_cache_datapath, // data connected to datapath
    inout [4 * READ_SIZE - 1 : 0] data_mem_cache, // data connected to memory

    output doneWrite,  // tells the cpu that writing is finshed
    output [WORD_SIZE-1:0] address_memory,
    output reg readM,
    output reg writeM,
   );
    reg [WORD_SIZE-1:0] num_cache_access,    // for debugging
    reg [WORD_SIZE-1:0] num_cache_miss,      // for debugging


    // 4 line, 4 word wide cache block
    // as line number is 4, index is log(4) = 2 bits
    // as block size is 4, block offset is log(4) = 2bits
    // therefore, tag is 16 - 2 - 2 = 12 bits
    reg [4*WORD_SIZE-1:0]  data_bank[3:0];
    reg [WORD_SIZE-5:0]    tag_bank[3:0];
    reg [3:0]              valid;
    reg [3:0]              dirty;

   // Address decoding
   wire [1:0] index;
   wire [WORD_SIZE-5:0] tag;
   wire [1:0] block_offset;             
   assign index = address_cache[3:2];
   assign tag = address_cache[WORD_SIZE-1:4];
   assign block_offset = address_cache[1:0];

   // cache hit
   wire hit;
   assign hit = valid[index] && (tag_bank[index] == tag);