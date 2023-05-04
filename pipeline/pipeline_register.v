`include "opcodes.v"
`include "constants.v"

module IF_ID_register(
    input clk,
    input reset_n,
    input flush,
    input stall,
    input pc_IF,
    input branch_predicted_pc_IF,
    input instruction_IF,
    output reg pc_ID,
    output reg branch_predicted_pc_ID,
    output reg instruction_ID
);

    always @ (posedge clk) begin
        if (~reset_n || flush) begin
            pc_ID <= 0;
            branch_predicted_pc_ID <= 0;
            instruction_ID <= {`OPCODE_NOP, 12{0}};
        end
        else if (~stall){
            pc_ID <= pc_IF;
            branch_predicted_pc_ID <= branch_predicted_pc_IF;
            instruction_ID <= instruction_IF;
        }
    end
    endmodule


module ID_EX_register(

    input clk,
    input reset_n,
    input flush,
    input stall,

    // ----------------------------- control signal inputs and outputs
    // input ports
    // EX
    input [1 : 0] ALUSrcB_ID,
    input [3 : 0] ALUOperation_ID,

    // MEM
    input d_readM_ID,
    input d_writeM_ID,

    // WB
    input output_active_ID,
    input is_halted_ID, 
    input [1 : 0] RegDst_ID, // write to 0: rt, 1: rd, 2: $2 (JAL)
    input RegWrite_ID,
    input [1 : 0] MemtoReg_ID, // write 0: ALU, 1: MDR, 2: PC + 1
    
    // output ports
    // EX
    output reg [1 : 0] ALUSrcB_EX,
    output reg [3 : 0] ALUOperation_EX,

    // MEM
    output reg d_readM_EX,
    output reg d_writeM_EX,

    // WB
    output reg output_active_EX,
    output reg is_halted_EX, 
    output reg [1 : 0] RegDst_EX, // write to 0: rt, 1: rd, 2: $2 (JAL)
    output reg RegWrite_EX,
    output reg [1 : 0] MemtoReg_EX, // write 0: ALU, 1: MDR, 2: PC + 1

    // ----------------------------------- Data latch
    input pc_ID,
    input branch_predicted_pc_ID,
    input instruction_ID,

    output reg pc_EX,
    output reg branch_predicted_pc_EX,
    output reg instruction_EX,

    input [`WORD_SIZE - 1 : 0] i_type_branch_target_ID,
    input [1 : 0] rs_ID,
    input [1 : 0] rt_ID,
    input [1 : 0] rd_ID
    input [`WORD_SIZE - 1] RF_data1_ID,
    input [`WORD_SIZE - 1] RF_data2_ID,
    input [`WORD_SIZE - 1] imm_signed_ID,

    
    output reg [`WORD_SIZE - 1 : 0] i_type_branch_target_EX,
    output reg [1 : 0] rs_EX,
    output reg [1 : 0] rt_EX,
    output reg [1 : 0] rd_EX
    output reg [`WORD_SIZE - 1] RF_data1_EX,
    output reg [`WORD_SIZE - 1] RF_data2_EX,
    output reg [`WORD_SIZE - 1] imm_signed_EX,
);

    always @ (posedge clk) begin
        if (~reset_n || flush) begin
            // ----------------- control signals
            // EX
            ALUSrcB_EX <= 0;
            ALUOperation_EX <= 0;

            // MEM
            d_readM_EX <= 0;
            d_writeM_EX <= 0;

            // WB
            output_active_EX <= 0;
            is_halted_EX <= 0; 
            RegDst_EX <= 0; // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_EX <= 0;
            MemtoReg_EX <= 0; // write 0: ALU, 1: MDR, 2: PC + 1

            // ------------------  Data latches
            pc_EX <= 0;
            branch_predicted_pc_EX <= 0;
            instruction_EX <= 0;
            
            i_type_branch_target_EX <= 0;
            rs_EX <= 0;
            rt_EX <= 0;
            rd_EX
            RF_data1_EX <= 0;
            RF_data2_EX <= 0;
            imm_signed_EX <= 0;
        end
        else if (~stall) begin
            // ----------------- control signals
            // EX
            ALUSrcB_EX ;
            ALUOperation_EX <= 0;

            // MEM
            d_readM_EX <= 0;
            d_writeM_EX <= 0;

            // WB
            output_active_EX <= 0;
            is_halted_EX <= 0; 
            RegDst_EX <= 0; // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_EX <= 0;
            MemtoReg_EX <= 0; // write 0: ALU, 1: MDR, 2: PC + 1

            // ------------------  Data latches
            pc_EX <= 0;
            branch_predicted_pc_EX <= 0;
            instruction_EX <= 0;
            
            i_type_branch_target_EX <= 0;
            rs_EX <= 0;
            rt_EX <= 0;
            rd_EX
            RF_data1_EX <= 0;
            RF_data2_EX <= 0;
            imm_signed_EX <= 0;
        end
    end
    endmodule