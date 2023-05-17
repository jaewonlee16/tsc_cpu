`timescale 1ns/1ns
`define WORD_SIZE 16    // data and address word size

`include "opcodes.v"
`include "constants.v"



module cpu(
        input Clk, 
        input Reset_N, 

	// Instruction memory interface
        output i_readM, 
        output i_writeM, 
        output [`WORD_SIZE-1:0] i_address, 
        inout [`WORD_SIZE-1:0] i_data, 

	// Data memory interface
        output d_readM, 
        output d_writeM, 
        output [`WORD_SIZE-1:0] d_address, 
        inout [`WORD_SIZE-1:0] d_data, 

        output [`WORD_SIZE-1:0] num_inst, 
        output [`WORD_SIZE-1:0] output_port, 
        output is_halted
);

	// TODO : Implement your pipelined CPU!
	parameter DATA_FORWARDING = 1;
    parameter BRANCH_PREDICTOR = `BRANCH_SATURATION_COUNTER;
    
        assign i_readM = 1;
        assign i_writeM = 0;




        // =================== modules ===================
        // control_unit
        control_unit control(
            .opcode(opcode),
            .func_code(func_code),
            
            // ID signal
            .PCSource(PCSource),
            .isJump(isJump),

            // EX signal
            .ALUSrcB(ALUSrcB),
            .ALUOperation(ALUOperation),
            .isItype_Branch(isItype_Branch),

            // MEM signal
            .d_readM(d_readM_ID),
            .d_writeM(d_writeM_ID),

            // WB signal
            .output_active(output_active),
            .is_halted(is_halted_ID),
            .RegDst(RegDst), // write to 0: rt, 1: rd, 2: $2 (JAL)
            .RegWrite(RegWrite),
            .MemtoReg(MemtoReg) // write 0: ALU, 1: MDR, 2: PC + 1
        );

        // datapath
        datapath #(.DATA_FORWARDING(DATA_FORWARDING),
                   .BRANCH_PREDICTOR(BRANCH_PREDICTOR))
        dp (
        .clk(Clk),
        .reset_n(Reset_N),

        // --------------------------- control_unit signals
        // ID signal
        .opcode(opcode),
        .func_code(func_code),

        .PCSource(PCSource),
        .isJump(isJump),

        // EX signal
        .ALUSrcB(ALUSrcB),
        .ALUOperation(ALUOperation),
        .isItype_Branch(isItype_Branch),

        // MEM signal
        .d_readM_ID(d_readM_ID),
        .d_writeM_ID(d_writeM_ID),

        // WB signal
        .output_active(output_active),
        .is_halted_ID(is_halted_ID),
        .RegDst(RegDst), // write to 0: rt, 1: rd, 2: $2 (JAL)
        .RegWrite(RegWrite),
        .MemtoReg(MemtoReg), // write 0: ALU, 1: MDR, 2: PC + 1

        // --------------------------- cpu.v signals
        .i_address(i_address),
        .d_address(d_address),
        .i_readM(i_readM),
        .d_readM(d_readM),
        .i_writeM(i_writeM),
        .d_writeM(d_writeM),
        .i_data(i_data),
        .d_data(d_data),
        .output_port(output_port),
        .is_halted(is_halted), 
        .num_inst(num_inst)
        );


        // wires
        // control_unit.v    <----->   datapath.v wires
        wire [3 : 0] opcode;
        wire [5 : 0] func_code;
        // ID signal
        wire [1 : 0] PCSource;
        wire isJump;

        // EX signal
        wire [1 : 0] ALUSrcB;
        wire [3: 0] ALUOperation;
        wire isItype_Branch;

        // MEM signal
        wire d_readM_ID;
        wire d_writeM_ID;

        // WB signal
        wire output_active;
        wire is_halted_ID;
        wire [1 : 0] RegDst; // write to 0: rt, 1: rd, 2: $2 (JAL)
        wire RegWrite;
        wire [1 : 0] MemtoReg; // write 0: ALU, 1: MDR, 2: PC + 1



endmodule
