`include "opcodes.v"
`include "constants.v"

module control_unit(
     input [3 : 0] opcode,
     input [5 : 0] func_code,
     
     // all input signals are from ID stage
     // and all output signals are out at ID stage
     // But signals can go through pipeline register until WB

     // ID signal
     output output_active,
     output is_halted,
     output [1 : 0] PCSource,

     // EX signal
     output reg [1 : 0] ALUSrcB,
     output reg [3: 0] ALUOperation,

     // MEM signal
     output d_readM,
     output d_writeM,

     // WB signal
     output [1 : 0] RegDst, // write to 0: rt, 1: rd, 2: $2 (JAL)
     output RegWrite,
     output [1 : 0] MemtoReg // write 0: ALU, 1: MDR, 2: PC + 1
    );
    
    // type of instructions
    wire isRtype_Arithmetic;
    wire isRtype_Special;
    wire isRtype_Halt;
    wire isItype_Arithmetic;
    wire isItype_Branch;
    wire isItype_Memory;
    wire isJtype_Jump;
    wire isRtype_Jump;
    
    // is Arithmetic Rtype instruction
    assign isRtype_Arithmetic = (opcode == `typeR)
                     && ( (func_code == `FUNC_ADD)
                         ||(func_code == `FUNC_SUB)
                         ||(func_code == `FUNC_AND)
                         ||(func_code == `FUNC_ORR)
                         ||(func_code == `FUNC_NOT)
                         ||(func_code == `FUNC_TCP)
                         ||(func_code == `FUNC_SHL)
                         ||(func_code == `FUNC_SHR) );
    // is Special Rtype instruction
    assign isRtype_Special = ( (opcode == `typeR)
                            &&( (func_code == `FUNC_WWD)
                            ||(func_code == `FUNC_JPR)
                            ||(func_code == `FUNC_JRL) ) );
    
    // is Arithmetic Itype instruction
    assign isItype_Arithmetic = (opcode == `OPCODE_ADI)
                ||(opcode == `OPCODE_ORI)
                ||(opcode == `OPCODE_LHI);
    // is conditional Branch Instruction
    assign isItype_Branch = ( (opcode == `OPCODE_BNE)
                ||(opcode == `OPCODE_BEQ)
                ||(opcode == `OPCODE_BGZ)
                ||(opcode == `OPCODE_BLZ) );
    // is Load or Store
    assign isItype_Memory = ( (opcode == `OPCODE_LWD)
                            || (opcode == `OPCODE_SWD) );
    // is unconditional Jump
    assign isJtype_Jump = ( (opcode == `OPCODE_JMP)
                            || (opcode == `OPCODE_JAL) );
    
    // is R type jump instruction                        
    assign isRtype_Jump = (opcode == `typeR 
                       && (func_code == (`FUNC_JPR  || func_code == `FUNC_JRL)));
    
    
    
    //              output signal                //
    
    // simple signals
    assign output_active = ( opcode == `typeR && func_code == `FUNC_WWD );
    assign is_halted = ((opcode == `typeR) && (func_code == `FUNC_HLT) );
    
   
    // ALU op signals
    always @ (*) begin
            if( isRtype_Arithmetic ) begin
                if( func_code == `FUNC_ADD ) ALUOperation = `OP_ADD;
                else if( func_code == `FUNC_SUB ) ALUOperation = `OP_SUB;
                else if( func_code == `FUNC_AND ) ALUOperation = `OP_AND;
                else if( func_code == `FUNC_ORR ) ALUOperation = `OP_OR;
                else if( func_code == `FUNC_NOT ) ALUOperation = `OP_NOT;
                else if( func_code == `FUNC_TCP ) ALUOperation = `OP_TCP;
                else if( func_code == `FUNC_SHL ) ALUOperation = `OP_SHL;
                else if( func_code == `FUNC_SHR ) ALUOperation = `OP_SHR;
            end
            else if( isItype_Arithmetic ) begin
                if( opcode == `OPCODE_ADI ) ALUOperation = `OP_ADD;
                else if( opcode == `OPCODE_ORI ) ALUOperation = `OP_OR;
                else if( opcode == `OPCODE_LHI ) ALUOperation = `OP_LHI;
            end
            else if( isItype_Branch ) ALUOperation = `OP_SUB;   // determine branch is taken or not at EX stage
            else if( isItype_Memory ) ALUOperation = `OP_ADD;  // LWD, SWD
            else ALUOperation = 4'bx;
     end  
    

    // d_readM signal
    assign d_readM = opcode == `OPCODE_LWD ? 1 : 0;


    // d_writeM signal
    assign d_writeM = opcode == `OPCODE_SWD ? 1 : 0;

    
    //              MUX selector signals             //
    // RegDst signal
    assign RegDst = ( opcode == `OPCODE_JAL 
                  || (opcode == `typeR && func_code == `FUNC_JRL) ) ? `REGDST_2 : // write next inst. at register2
                      opcode == `typeR ? `REGDST_RD :
                      `REGDST_RT;
    
    // MemtoReg signal
    assign MemtoReg = (opcode == `OPCODE_JAL 
                   || (opcode == `typeR && func_code == `FUNC_JRL) ) ? `REGWRITESRC_PC : // write next inst. at register2
                       opcode == `OPCODE_LWD ? `REGWRITESRC_MEM : 
                       `REGWRITESRC_ALU;
    
    
    // ALUSrc B signal
    always @ (*) begin
            if( opcode == `OPCODE_BNE || opcode == `OPCODE_BEQ ) ALUSrcB = `ALUSRCB_REG;    // compare two registers
            else if( opcode == `OPCODE_BGZ || opcode == `OPCODE_BLZ ) ALUSrcB = `ALUSRCB_ZERO;  // compare register(ALUSrcA) and zero
            else if( isItype_Arithmetic || isItype_Memory ) ALUSrcB = `ALUSRCB_IMM; // for i type except for branch
            else if( isRtype_Arithmetic) ALUSrcB = `ALUSRCB_REG;    // for r type
            else ALUSrcB = 2'bz;
    end
    
    
    // PCSource
    assign PCSource = (isItype_Branch  && stage == `STAGE_EX) ? `PCSRC_BRANCH :     // pc from branch
                      isJtype_Jump ? `PCSRC_JUMP :      // pc from jump
                      (opcode == `typeR && ( func_code == `FUNC_JPR || func_code == `FUNC_JRL)) ? `PCSRC_REG :  // pc from register 2
                      `PCSRC_SEQ; // pc + 1
    
    //                  write signals               //
    // regWrite
    assign RegWrite = ( (opcode == `typeR && func_code == `FUNC_JRL) // stage ID JRL
                      || opcode == `OPCODE_JAL ) ? 1'b1 : 1'b0 ; // stage ID JAL
     
    

endmodule