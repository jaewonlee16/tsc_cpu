`timescale 1ns/1ns
`include "opcodes.v"
`include "constants.v"

module branch_predictor
  #(parameter BRANCH_PREDICTOR = `BRANCH_ALWAYS_TAKEN,
    parameter BTB_IDX_SIZE = 8)
   (input                      clk,
    input                      reset_n, // clear BTB to all zero
    input                      update_tag, // update tag as soon as decode (when target is known)
    input                      update_bht, // update BHT when know prediction was correct or not
    input [WORD_SIZE-1:0]      pc, // the pc that was just fetched
    input [WORD_SIZE-1:0]      pc_for_btb_update, // PC collision tag 
                                                // always pc_id
    input [WORD_SIZE-1:0]      pc_real,        // The actual pc that is calculated (not predicted)
                                               // pc_ex(i type branch) or pc_id(jump)
    input [WORD_SIZE-1:0]      branch_target_for_btb_update, // branch target of jump and i type branch.
                                                             // update as soon as decode
    input                      branch_correct_or_notCorrect, // if the predicted pc is same as the actual pc
    output                     tag_match, // tag matched PC
    output [WORD_SIZE-1:0] branch_predicted_pc // predicted next PC
);

   // Tag table
   reg [WORD_SIZE-BTB_IDX_SIZE-1:0] tag_table[2**BTB_IDX_SIZE-1:0];
   // Branch history table
   reg [1:0] bht[2**BTB_IDX_SIZE-1:0];
   // Branch target buffer
   reg [BTB_IDX_SIZE-1:0] btb[2**BTB_IDX_SIZE-1:0];
   // BTB index
   wire [BTB_IDX_SIZE-1:0] btb_idx;
   // PC tag
   wire [WORD_SIZE-BTB_IDX_SIZE-1:0] pc_tag;
   assign {pc_tag, btb_idx} = pc;
   // BTB hit

   wire [BTB_IDX_SIZE-1:0]           btb_idx_for_btb_update;
   wire [WORD_SIZE-BTB_IDX_SIZE-1:0] tag_for_btb_update;
   assign {tag_for_btb_update, btb_idx_for_btb_update} = pc_for_btb_update;

   // combinational logic for output
   assign tag_match = (tags[btb_idx] == pc_tag);
   assign  branch_predicted_pc = (tag_match && bht[btb_idx] >= 2'd2) ? btb[btb_idx] : pc + 1;

   integer i; // index
   
   // btb and bht update logic
   // sequential circuit
   always @(posedge clk) begin
      if (!reset_n) begin
         for (i=0; i<2**BTB_IDX_SIZE; i=i+1) begin
            // inititialize bht to weakly taken
            // inititialize everything else to 0
            tag_table[i] <= 0;
            bht[i] <= 2'b10; // initialize to 'weakly taken'
            btb[i] <= 0;
         end
      end
      else begin
         // On collision, at ID stage
         //
         // This should be done for all predictors including always taken.
         if (update_tag) begin
            tags[btb_idx_collided] <= pc_tag_collided;
            btb[btb_idx_collided] <= branch_target;
         end
         if (update_bht) // TODO
      end
   end
endmodule