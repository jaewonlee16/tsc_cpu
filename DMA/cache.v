`include "opcodes.v"
`include "constants.v"

module cache
   (
    input clk,
    input reset_n,
    input read_cache,
    input write_cache,
    input [`WORD_SIZE-1:0] address_cache,
    inout [`WORD_SIZE-1:0] data_cache_datapath, // data connected to datapath
    inout [4 * `WORD_SIZE - 1 : 0] data_mem_cache, // data connected to memory

    output reg doneWrite,  // tells the cpu that writing is finshed
    output [`WORD_SIZE-1:0] address_memory,
    output reg readM,
    output reg writeM,

    // DMA
    input BG
   );
    
    // ------------- logic for hit miss calculation ------------------ //
    reg [`WORD_SIZE-1:0] num_cache_miss;      // for debugging
    reg [`WORD_SIZE-1:0] num_cache_hit;      // for debugging

   always @ (posedge clk) begin
        if (!reset_n) begin
            num_cache_miss <= 0;
            num_cache_hit <= 0;
        end
        // cache(1cycle) + memory(4cycle) + cache(1cycle)
        // read_cache && !readM is true only when first cylcle of cache
        if (read_cache && !readM) begin          
            if (hit) num_cache_hit <= num_cache_hit + 1;
            else num_cache_miss <= num_cache_miss + 1;
        end
        // cache(1cycle) + memory_read(4cycle) + cache(1cycle) + memory_write(4cycle) + cache(1cycle)
        // write_cache && !readM && !doneWrite && !writeM is true only when first cylcle of cache 
        else if (write_cache && !readM && !doneWrite && !writeM) begin  
            if (hit) num_cache_hit <= num_cache_hit + 1;
            else num_cache_miss <= num_cache_miss + 1;
        end
           
   end   
   
   
    // ---------------------- cache logic -----------------------------------
   
   // for data_cache_datapath
    reg [`WORD_SIZE - 1 : 0] cache_output_data;


   // counter
    reg count_start;
    reg [2: 0] count;


    // 4 line, 4 word wide cache block
    // as line number is 4, index is log(4) = 2 bits
    // as block size is 4, block offset is log(4) = 2bits
    // therefore, tag is 16 - 2 - 2 = 12 bits
    reg [4*`WORD_SIZE-1:0]  data_bank[3:0];
    reg [`WORD_SIZE-5:0]    tag_bank[3:0];
    reg [3:0]              valid;

   // Address decoding
   wire [1:0] index;
   wire [`WORD_SIZE-5:0] tag;
   wire [1:0] block_offset;             
   assign index = address_cache[3:2];
   assign tag = address_cache[`WORD_SIZE-1:4];
   assign block_offset = address_cache[1:0];

   // ouput port assignment
   assign data_mem_cache = writeM ? data_bank[index] : 64'bz;
   assign data_cache_datapath = read_cache ? !hit ? `NOP : cache_output_data : `WORD_SIZE'bz;


   // cache hit
   wire hit;
   assign hit = valid[index] && (tag_bank[index] == tag);
               
   // memory signals
   // as memory is accessed by line,
   // last 2 bits are always 00
   assign address_memory = {address_cache[`WORD_SIZE - 1 : 2], 2'b00};

    // valid logic
    // if it is NOP, it is not valid
   always @ (*) begin
      if ((read_cache || write_cache) && data_bank[index] [63:60] != `OPCODE_NOP) begin
         valid[index] = 1;
      end
      else valid[index] = 0;
   end
   
   // assign for output
   // cache_output data is for the output to processor
   always @ (*) begin
      
      case(block_offset) 
         2'b00: cache_output_data = data_bank[index] [63:48] ;
         2'b01: cache_output_data = data_bank[index] [47:32] ;
         2'b10: cache_output_data = data_bank[index] [31:16] ;
         2'b11: cache_output_data = data_bank[index] [15:0] ;
      endcase
      
   end
   
   // counter for write
   // the processor stalls until writeDone
   // writeDone is determined by "count"
   integer i;
   always @ (posedge clk) begin
      
      if (!reset_n || count == `LATENCY) begin
         count <= 0;
      end
      else if (count_start) count <= count + 1;

   end
   
  
    // update data bank and tag bank logic
    // write through no allocate
    always @ (posedge clk) begin
        // Request type: Read
         if (read_cache) begin
            if (!hit) begin
               // Read data from lower memory into the cache block
               data_bank[index] <= BG ? {4`NOP} : data_mem_cache;  // if BG stall(NOP) else read from data memory
               tag_bank[index] <= tag;
            end
         end
         // Request type : Write
         else if (write_cache) begin
            if (!hit) begin
               // Read data from lower memory into the cache block
               data_bank[index] <=  BG ? {4`NOP} : data_mem_cache;
               tag_bank[index] <=  tag;
            end
            else begin
                tag_bank[index] = tag;
               case(block_offset) 
                  2'b00: data_bank[index] [63:48] <= data_cache_datapath;
                  2'b01: data_bank[index] [47:32] <= data_cache_datapath;
                  2'b10: data_bank[index] [31:16] <= data_cache_datapath;
                  2'b11: data_bank[index] [15:0] <= data_cache_datapath;
               endcase;
            end
         end
    end
    
    
   // logic for control signals
   // determines to read memory or write memory,
   // sends the processor that write is done (writeDone)
   always @ (posedge clk) begin
      if (!reset_n) begin
         for (i=0; i<4; i=i+1) begin
            data_bank[i] <= {4`NOP};
            tag_bank[i] <= 0;
            valid[i] <= 0;
            num_cache_miss <= 0;
            writeM <= 0;

         end
      end
      else begin
         // Request type: Read
         if (read_cache) begin
            doneWrite <= 0;
            count_start <= 0;
            if (!hit) begin
               // Read data from lower memory into the cache block

                readM <= BG ? 0 : 1; // if BG don't readM
               writeM <= 0;
            end
            else readM <= 0;
             

         end
         // Request type : Write
         else if (write_cache && !doneWrite) begin
            if (!hit) begin
               // Read data from lower memory into the cache block
                readM <= BG ? 0 : 1; // if BG don't readM

            end
            else begin
;               readM <= 0;
               count_start <= BG ? 0 : 1; // if BG write is not started
               writeM <= BG ? 0 : 1;      // if BG don't writeM
               if (count == `LATENCY - 1) begin
                    doneWrite <= 1;
                    writeM <= 0;
               end
            end

         end
         // Request type: No memory request
         else begin

            doneWrite <= 0;
            count_start <= 0;
            readM <= 0;
            writeM <= 0;
         end 
      end
   end
endmodule