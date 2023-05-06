`include "opcodes.v"
`include "constants.v"

module IF_ID_register(
    input clk,
    input reset_n,
    input flush,
    input stall,
    input [`WORD_SIZE - 1 : 0]pc_IF,
    input [`WORD_SIZE - 1 : 0]branch_predicted_pc_IF,
    input [`WORD_SIZE - 1 : 0]instruction_IF,
    input tag_match_IF,
    output reg [`WORD_SIZE - 1 : 0]pc_ID,
    output reg [`WORD_SIZE - 1 : 0]branch_predicted_pc_ID,
    output reg [`WORD_SIZE - 1 : 0]instruction_ID,
    output reg tag_match_ID
);

    always @ (posedge clk) begin
        if (~reset_n || flush) begin
            pc_ID <= 0;
            branch_predicted_pc_ID <= 0;
            instruction_ID <= {`OPCODE_NOP, 12{0}};
            tag_match_ID <= 0;
        end
        else if (~stall){
            pc_ID <= pc_IF;
            branch_predicted_pc_ID <= branch_predicted_pc_IF;
            instruction_ID <= instruction_IF;
            tag_match_ID <= tag_match_IF;
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
    input isItype_Branch_ID,

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
    output isItype_Branch_EX,

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
    input [`WORD_SIZE - 1 : 0]pc_ID,
    input [`WORD_SIZE - 1 : 0]branch_predicted_pc_ID,
    input [`WORD_SIZE - 1 : 0]instruction_ID,

    output reg [`WORD_SIZE - 1 : 0]pc_EX,
    output reg [`WORD_SIZE - 1 : 0]branch_predicted_pc_EX,    // last because branch ends at EX
    output reg [`WORD_SIZE - 1 : 0]instruction_EX,

    input [`WORD_SIZE - 1 : 0] i_type_branch_target_ID,
    input [1 : 0] rs_ID,
    input [1 : 0] rt_ID,
    input [1 : 0] rd_ID,
    input [`WORD_SIZE - 1] RF_data1_ID,
    input [`WORD_SIZE - 1] RF_data2_ID,
    input [`WORD_SIZE - 1] imm_signed_ID,
    input [1 : 0] write_reg_addr_ID,

    
    output reg [`WORD_SIZE - 1 : 0] i_type_branch_target_EX,   // last because branch ends at EX
    output reg [1 : 0] rs_EX,
    output reg [1 : 0] rt_EX,
    output reg [1 : 0] rd_EX,
    output reg [`WORD_SIZE - 1] RF_data1_EX,
    output reg [`WORD_SIZE - 1] RF_data2_EX,
    output reg [`WORD_SIZE - 1] imm_signed_EX,
    output [1 : 0] write_reg_addr_EX
);

    always @ (posedge clk) begin
        if (~reset_n || flush) begin
            // ----------------- control signals
            // EX
            ALUSrcB_EX <= 0;
            ALUOperation_EX <= 0;
            isItype_Branch_EX <= 0;

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
            instruction_EX <= {`OPCODE_NOP, 12{0}};
            
            i_type_branch_target_EX <= 0;
            rs_EX <= 0;
            rt_EX <= 0;
            rd_EX <= 0;
            RF_data1_EX <= 0;
            RF_data2_EX <= 0;
            imm_signed_EX <= 0;
            write_reg_addr_EX <= 0;
        end
        else if (~stall) begin
            // ----------------- control signals
            // EX
            ALUSrcB_EX <= ALUSrcB_ID;
            ALUOperation_EX <= ALUOperation_ID;
            isItype_Branch_EX <= isItype_Branch_ID;

            // MEM
            d_readM_EX <= d_readM_ID;
            d_writeM_EX <= d_writeM_ID;

            // WB
            output_active_EX <= output_active_ID;
            is_halted_EX <= is_halted_ID; 
            RegDst_EX <= RegDst_ID; // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_EX <= RegWrite_ID;
            MemtoReg_EX <= MemtoReg_ID; // write 0: ALU, 1: MDR, 2: PC + 1

            // ------------------  Data latches
            pc_EX <= pc_ID;
            branch_predicted_pc_EX <= branch_predicted_pc_ID;
            instruction_EX <= instruction_ID;
            
            i_type_branch_target_EX <= i_type_branch_target_ID;
            rs_EX <= rs_ID;
            rt_EX <= rt_ID;
            rd_EX <= rd_ID
            RF_data1_EX <= RF_data1_ID;
            RF_data2_EX <= RF_data2_ID;
            imm_signed_EX <= imm_signed_ID;
            write_reg_addr_EX <= write_reg_addr_ID;
        end
    end
    endmodule


    module EX_MEM_register(
        input clk,
        input reset_n,
        input flush,
        input stall,

        // ----------------------------- control signal inputs and outputs
        // input ports
        // MEM
        input d_readM_EX,
        input d_writeM_EX,

        // WB
        input output_active_EX,
        input is_halted_EX, 
        input [1 : 0] RegDst_EX, // write to 0: rt, 1: rd, 2: $2 (JAL)
        input RegWrite_EX,
        input [1 : 0] MemtoReg_EX, // write 0: ALU, 1: MDR, 2: PC + 1
        
        // output ports
        // MEM
        output reg d_readM_MEM,
        output reg d_writeM_MEM,

        // WB
        output reg output_active_MEM,
        output reg is_halted_MEM, 
        output reg [1 : 0] RegDst_MEM, // write to 0: rt, 1: rd, 2: $2 (JAL)
        output reg RegWrite_MEM,
        output reg [1 : 0] MemtoReg_MEM, // write 0: ALU, 1: MDR, 2: PC + 1
        
        // ----------------------------------- Data latch
        input [`WORD_SIZE - 1 : 0]pc_EX,
        input [`WORD_SIZE - 1 : 0]instruction_EX,

        output reg [`WORD_SIZE - 1 : 0]pc_MEM,
        output reg [`WORD_SIZE - 1 : 0]instruction_MEM,

        input [1 : 0] rs_EX,
        input [1 : 0] rt_EX,
        input [`WORD_SIZE - 1] RF_data1_EX,
        input [`WORD_SIZE - 1] imm_signed_EX,
        input [1 : 0] write_reg_addr_EX,

        output reg [1 : 0] rs_MEM,
        output reg [1 : 0] rt_MEM,
        output reg [`WORD_SIZE - 1] RF_data1_MEM,      // for SWD`        
        output reg [`WORD_SIZE - 1] imm_signed_MEM,
        output [1 : 0] write_reg_addr_MEM

        input [`WORD_SIZE - 1] ALU_result_EX,
        output [`WORD_SIZE - 1] ALU_out_MEM
    );

    always @ (posedge clk) begin
        if (~reset_n || flush) begin
            // ----------------- control signals
            // MEM
            d_readM_MEM <= 0;
            d_writeM_MEM <= 0;

            // WB
            output_active_MEM <= 0;
            is_halted_MEM <= 0; 
            RegDst_MEM <= 0; // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_MEM <= 0;
            MemtoReg_MEM <= 0; // write 0: ALU, 1: MDR, 2: PC + 1

            // ------------------  Data latches
            pc_MEM <= 0;
            instruction_MEM <= {`OPCODE_NOP, 12{0}};
            
            rs_MEM <= 0;
            rt_MEM <= 0;
            B_MEM <= 0;
            imm_signed_MEM <= 0;
            write_reg_addr_MEM <= 0;
            ALU_out_MEM <= 0;
        end
        else if (~stall) begin
            // ----------------- control signals
            // MEM
            d_readM_MEM <= d_readM_EX;
            d_writeM_MEM <= d_writeM_EX;

            // WB
            output_active_MEM <= output_active_EX;
            is_halted_MEM <= is_halted_EX; 
            RegDst_MEM <= RegDst_EX; // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_MEM <= RegWrite_EX;
            MemtoReg_MEM <= MemtoReg_EX; // write 0: ALU, 1: MDR, 2: PC + 1

            // ------------------  Data latches
            pc_MEM <= pc_EX;
            instruction_MEM <= instruction_EX;
            
            rs_MEM <= rs_EX;
            rt_MEM <= rt_EX;
            B_MEM <= RF_data2_EX;
            imm_signed_MEM <= imm_signed_EX;
            write_reg_addr_MEM <= write_reg_addr_EX;
            ALU_out_MEM <= ALU_result_EX;
        end
    end
    endmodule

    module MEM_WB_register(
        input clk,
        input reset_n,
        input flush,
        input stall,

        // ----------------------------- control signal inputs and outputs
        // input ports
        // WB
        input output_active_MEM,
        input is_halted_MEM, 
        input [1 : 0] RegDst_MEM, // write to 0: rt, 1: rd, 2: $2 (JAL)
        input RegWrite_MEM,
        input [1 : 0] MemtoReg_MEM, // write 0: ALU, 1: MDR, 2: PC + 1
        
        // output ports
        // WB
        output reg output_active_WB,
        output reg is_halted_WB, 
        output reg [1 : 0] RegDst_WB, // write to 0: rt, 1: rd, 2: $2 (JAL)
        output reg RegWrite_WB,
        output reg [1 : 0] MemtoReg_WB, // write 0: ALU, 1: MDR, 2: PC + 1
        
        // ----------------------------------- Data latch
        input [`WORD_SIZE - 1 : 0]pc_MEM,
        input [`WORD_SIZE - 1 : 0]instruction_MEM,

        output reg [`WORD_SIZE - 1 : 0]pc_WB,
        output reg [`WORD_SIZE - 1 : 0]instruction_WB,

        input [1 : 0] rs_MEM,
        input [1 : 0] rt_MEM,
        input [`WORD_SIZE - 1] imm_signed_MEM,
        input [1 : 0] write_reg_addr_MEM,

        output reg [1 : 0] rs_WB,
        output reg [1 : 0] rt_WB,
        output reg [`WORD_SIZE - 1] imm_signed_WB,
        output [1 : 0] write_reg_addr_WB

        input [`WORD_SIZE - 1] ALU_out_MEM,
        output [`WORD_SIZE - 1] ALU_out_WB,

        input [`WORD_SIZE - 1] MDR_MEM,
        output [`WORD_SIZE - 1] MDR_WB
    );

    always @ (posedge clk) begin
        if (~reset_n || flush) begin
            // ----------------- control signals
            // WB
            output_active_WB <= 0;
            is_halted_WB <= 0; 
            RegDst_WB <= 0; // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_WB <= 0;
            MemtoReg_WB <= 0; // write 0: ALU, 1: MDR, 2: PC + 1

            // ------------------  Data latches
            pc_WB <= 0;
            instruction_WB <= {`OPCODE_NOP, 12{0}};
            
            rs_WB <= 0;
            rt_WB <= 0;
            imm_signed_WB <= 0;
            write_reg_addr_WB <= 0;
            ALU_out_WB <= 0;
            MDR_WB <= 0;
        end
        else if (~stall) begin
            // ----------------- control signals
            // WB
            output_active_WB <= output_active_MEM;
            is_halted_WB <= is_halted_MEM; 
            RegDst_WB <= RegDst_MEM; // write to 0: rt, 1: rd, 2: $2 (JAL)
            RegWrite_WB <= RegWrite_MEM;
            MemtoReg_WB <= MemtoReg_MEM; // write 0: ALU, 1: MDR, 2: PC + 1

            // ------------------  Data latches
            pc_WB <= pc_MEM;
            instruction_WB <= instruction_MEM;
            
            rs_WB <= rs_MEM;
            rt_WB <= rt_MEM;
            imm_signed_WB <= imm_signed_MEM;
            write_reg_addr_WB <= write_reg_addr_MEM;
            ALU_out_WB <= ALU_result_MEM;
            MDR_WB <= MDR_MEM;
        end
    end
    endmodule