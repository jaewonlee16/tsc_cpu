`timescale 1ns/1ns
`include "opcodes.v"
`include "constants.v"


module branch_predictor
  #(parameter BRANCH_PREDICTOR = `BRANCH_ALWAYS_TAKEN)
   (
    input clk,
    input reset_n, // clear BTB to all zero
    // IF
    input [`WORD_SIZE-1:0]      pc, // the pc that was just fetched

    // ID
    // BTB is only updated at ID stage
    input                      update_tag, // update tag as soon as decode(when target is known)
    input [`WORD_SIZE-1:0]      pc_for_btb_update, // PC collision tag 
    input [`WORD_SIZE-1:0]      branch_target_for_btb_update, // branch target of jump and i type branch.

    // ID or EX
    // BHT is updated at ID or EX stage depending on the branch type
    input                      update_bht, // update BHT when know prediction was correct or not
    input [`WORD_SIZE-1:0]      pc_for_bht_update,     // The actual pc that is calculated (not predicted)
                                               // pc_ex(i type branch) or pc_id(jump)
    input                      branch_correct_or_notCorrect, // if the predicted pc is same as the actual pc

    // IF
    output                     tag_match, // tag matched PC : output at IF
    output [`WORD_SIZE-1:0] branch_predicted_pc // predicted next PC
);
    parameter BTB_IDX_SIZE = 8;
    
   // Tag table
   reg [`WORD_SIZE - BTB_IDX_SIZE - 1:0] tag_table[2**BTB_IDX_SIZE-1:0];
   
   // Branch history table
   reg [1:0] bht[2**BTB_IDX_SIZE - 1:0];
   
   // Branch target buffer
   reg [BTB_IDX_SIZE-1:0] btb[2**BTB_IDX_SIZE-1:0];
   
   // BTB index, pc tag
   wire [BTB_IDX_SIZE-1:0] btb_idx;
   wire [`WORD_SIZE - BTB_IDX_SIZE - 1:0] pc_tag;
   assign {pc_tag, btb_idx} = pc;

   // BTB update
   wire [BTB_IDX_SIZE-1:0]           btb_idx_for_btb_update;
   wire [`WORD_SIZE - BTB_IDX_SIZE - 1:0] tag_for_btb_update;
   assign {tag_for_btb_update, btb_idx_for_btb_update} = pc_for_btb_update;

   // BHT update
   wire [BTB_IDX_SIZE - 1:0]           btb_idx_for_bht_update;
   assign  btb_idx_for_bht_update = pc_for_bht_update[BTB_IDX_SIZE-1:0];
   
   // combinational logic for output
   assign tag_match = (tag_table[btb_idx] == pc_tag);
   assign  branch_predicted_pc = (tag_match && bht[btb_idx] >= 2'd2) ? btb[btb_idx] : pc + 1;

   integer i; // index
   
   // btb and bht update logic
   // sequential circuit
   always @(posedge clk) begin
      if (!reset_n) begin
         for (i=0; i<2**BTB_IDX_SIZE; i=i+1) begin
            // inititialization
            tag_table[i] <= 1;
            bht[i] <= 2'd3; // initialize to 3
            btb[i] <= 0;
         end
      end
      else begin
         // On collision, at ID stage
         //
         // This should be done for all predictors including always taken.
         if (update_tag) begin
            tag_table[btb_idx_for_btb_update] <= tag_for_btb_update;
            btb[btb_idx_for_btb_update] <= branch_target_for_btb_update;
         end
         if (update_bht && BRANCH_PREDICTOR == `BRANCH_SATURATION_COUNTER) begin
            if (branch_correct_or_notCorrect) begin
                // add 1 if prediction was correct
                bht[btb_idx_for_bht_update] <= bht[btb_idx_for_bht_update] == 2'd3 ? bht[btb_idx_for_bht_update] : bht[btb_idx_for_bht_update] + 1;
            end
            else
                bht[btb_idx_for_bht_update] <= bht[btb_idx_for_bht_update] == 2'd0 ? bht[btb_idx_for_bht_update] : bht[btb_idx_for_bht_update] - 1;         
         end
      end
   end
endmodule