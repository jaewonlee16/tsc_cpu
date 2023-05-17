`define PERIOD1 100
`define READ_DELAY 30 // delay before memory data is ready
`define WRITE_DELAY 30 // delay in writing to memory
`define MEMORY_SIZE 256 // size of memory is 2^8 words (reduced size)
`define WORD_SIZE 16 // instead of 2^16 words to reduce memory
                        
`define NUM_TEST 58
`define TESTID_SIZE 5

// Instruction Types
`define typeR 4'b1111

// ALU compare results
// 00 : same (=), 10 : greater than (>), 11 : less than (<)
`define ALU_SAME 2'b00
`define ALU_BIG 2'b10
`define ALU_SMALL 2'b11

// MUX selectors

`define PCSRC_SEQ 2'd0
`define PCSRC_BRANCH 2'd1
`define PCSRC_JUMP 2'd2
`define PCSRC_REG 2'd3

`define ALUSRCA_PC 1'b0
`define ALUSRCA_REG 1'b1

`define ALUSRCB_REG 2'd0
`define ALUSRCB_ONE 2'd1
`define ALUSRCB_IMM 2'd2
`define ALUSRCB_ZERO 2'd3

`define REGWRITESRC_ALU 2'd0
`define REGWRITESRC_MEM 2'd1
`define REGWRITESRC_PC 2'd2

`define REGDST_RT 2'd0
`define REGDST_RD 2'd1
`define REGDST_2 2'd2

`define IORD_I 1'b0
`define IORD_D 1'b1

`define BRANCH_ALWAYS_TAKEN 1'b0
`define BRANCH_SATURATION_COUNTER 1'b1

`define FORWARD_SRC_MEM 0
`define FORWARD_SRC_WB 1
`define FORWARD_SRC_RF 2