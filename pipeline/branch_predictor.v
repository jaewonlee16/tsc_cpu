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
    output reg [WORD_SIZE-1:0] branch_predicted_pc // predicted next PC
);

   // Tag table
   reg [WORD_SIZE-BTB_IDX_SIZE-1:0] tag_table[2**BTB_IDX_SIZE-1:0];
   // Branch history table
   reg [1:0] bht[2**BTB_IDX_SIZE-1:0];
   // Branch target buffer
   reg [BTB_IDX_SIZE-1:0] btb[2**BTB_IDX_SIZE-1:0];
   // BTB index
   wire [BTB_IDX_SIZE-1:0] btb_idx;
   assign btb_idx = pc[BTB_IDX_SIZE-1:0];
   // PC tag
   wire [WORD_SIZE-BTB_IDX_SIZE-1:0] pc_tag;
   assign pc_tag = pc[WORD_SIZE-1:BTB_IDX_SIZE];
   // BTB hit
   assign tag_match = (tags[btb_idx] == pc_tag);

   wire [BTB_IDX_SIZE-1:0]           btb_idx_collided;
   assign btb_idx_collided = pc_for_btb_update[BTB_IDX_SIZE-1:0];
   wire [WORD_SIZE-BTB_IDX_SIZE-1:0] pc_tag_collided;
   assign pc_tag_collided = pc_for_btb_update[WORD_SIZE-1:BTB_IDX_SIZE];
