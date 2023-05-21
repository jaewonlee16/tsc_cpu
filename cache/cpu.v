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
        inout [4*`WORD_SIZE-1:0] i_data, 

	// Data memory interface
        output d_readM, 
        output d_writeM, 
        output [`WORD_SIZE-1:0] d_address, 
        inout [4*`WORD_SIZE-1:0] d_data, 

        output [`WORD_SIZE-1:0] num_inst, 
        output [`WORD_SIZE-1:0] output_port, 
        output is_halted
);

	// TODO : Implement your pipelined CPU!
	parameter DATA_FORWARDING = 1;
    parameter BRANCH_PREDICTOR = `BRANCH_SATURATION_COUNTER;
    
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
        .i_address(address_cache_i),
        .d_address(address_cache_d),
        .i_readM(read_cache_i),
        .d_readM(read_cache_d),
        .i_writeM(write_cache_i),
        .d_writeM(write_cache_d),
        .i_data(data_cache_datapath_i),
        .d_data(data_cache_datapath_d),
        .output_port(output_port),
        .is_halted(is_halted), 
        .num_inst(num_inst),
        .doneWrite(doneWrite_d)
        );


        i_cache instruction_cache(
                
        .clk(Clk),
        .reset_n(Reset_N),
        .read_cache(1),
        .write_cache(0),
        .address_cache(address_cache_i),
        .data_cache_datapath(data_cache_datapath_i), // data connected to datapath
        .data_mem_cache(i_data), // data connected to memory

        .doneWrite(),  // tells the cpu that writing is finshed
        .address_memory(i_address),
        .readM(i_readM),
        .writeM()

        );

        d_cache data_cache(
                
        .clk(Clk),
        .reset_n(Reset_N),
        .read_cache(read_cache_d),
        .write_cache(write_cache_d),
        .address_cache(address_cache_d),
        .data_cache_datapath(data_cache_datapath_d), // data connected to datapath
        .data_mem_cache(d_data), // data connected to memory

        .doneWrite(doneWrite_d),  // tells the cpu that writing is finshed
        .address_memory(d_address),
        .readM(d_readM),
        .writeM(d_writeM)

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


        // instruction_cache <---------> datapath.v wires
        wire read_cache_i;
        wire write_cache_i;
        wire [`WORD_SIZE - 1 : 0] address_cache_i;
        wire [`WORD_SIZE - 1 : 0] data_cache_datapath_i;
        
        
        
        // data cache <-----------> datapath.v wires
        wire read_cache_d;
        wire write_cache_d;
        wire [`WORD_SIZE - 1 : 0] address_cache_d;
        wire [`WORD_SIZE - 1 : 0] data_cache_datapath_d;
        wire doneWrite_d;



endmodule
