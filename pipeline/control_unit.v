`include "opcodes.v"
`include "constants.v"

module control_unit(
     input reset_n,
     input clk,
     input [3 : 0] opcode,
     input [5 : 0] func_code,
     input [1:0] ALU_Compare,
     
     output [1 : 0] RegDst, // write to 0: rt, 1: rd, 2: $2 (JAL)
     output RegWrite,
     output ALUSrcA,
     output reg [1 : 0] ALUSrcB,
     output reg [3: 0] ALUOperation,
     output [1 : 0] PCSource,
     output PC_en,
     output IorD,
     output reg readM,
     output MemWrite,
     output [1 : 0] MemtoReg, // write 0: ALU, 1: MDR, 2: PC + 1
     output output_active,
     output is_halted
    );
    // control signals that are not output
    wire PCWriteCond;
    wire PCWrite;
    
    // type of instructions
    wire isRtype_Arithmetic;
    wire isRtype_Special;
    wire isRtype_Halt;
    wire isItype_Arithmetic;
    wire isItype_Branch;
    wire isItype_Memory;
    wire isJtype_Jump;
    wire isRtype_Jump;
    
    wire isBranchTaken;
    
    assign isBranchTaken = (opcode == `OPCODE_BNE && (ALU_Compare == `ALU_BIG || ALU_Compare == `ALU_SMALL) // not equal
                         || opcode == `OPCODE_BEQ && ALU_Compare == `ALU_SAME  // equal
                         || opcode == `OPCODE_BGZ && ALU_Compare == `ALU_BIG  // greater than
                         || opcode == `OPCODE_BLZ && ALU_Compare == `ALU_SMALL) ? 1 : 0;  // kess than
    
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
    assign writeM = ( stage == `STAGE_MEM && opcode == `OPCODE_SWD );
    
   
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
    
    // readM signal                ////////////////////////////////////////////////////////  need changes
     always @(*) begin 
        if(stage==`STAGE_IF) readM = 1'b1; // activate at instruction fetch
        else if(stage==`STAGE_MEM && opcode == `OPCODE_LWD) readM = 1'b1; // activate at mem read
        else readM = 0;
    end
    
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
    
    // ALUSrc A signal                     //////////////////////////    ALUSRC_A may not ne need
    assign ALUSrcA = (stage == `STAGE_IF || stage == `STAGE_ID) ? `ALUSRCA_PC : `ALUSRCA_REG; // IF : pc + 1  ID: pc + imm (branch)
    
    // ALUSrc B signal
    always @ (*) begin
            if( opcode == `OPCODE_BNE || opcode == `OPCODE_BEQ ) ALUSrcB = `ALUSRCB_REG;    // compare two registers
            else if( opcode == `OPCODE_BGZ || opcode == `OPCODE_BLZ ) ALUSrcB = `ALUSRCB_ZERO;  // compare register(ALUSrcA) and zero
            else if( isItype_Arithmetic || isItype_Memory ) ALUSrcB = `ALUSRCB_IMM; // for i type except for branch
            else if( isRtype_Arithmetic) ALUSrcB = `ALUSRCB_REG;    // for r type
            else ALUSrcB = 2'bz;
    end
    
    // IorD signal                        ///////////////////////////   may need to be fixed
    assign IorD = ( PC_en ? `IORD_I : `IORD_D );
    
    // PCSource
    assign PCSource = (isItype_Branch  && stage == `STAGE_EX) ? `PCSRC_BRANCH :     // pc from branch
                      isJtype_Jump ? `PCSRC_JUMP :      // pc from jump
                      (opcode == `typeR && ( func_code == `FUNC_JPR || func_code == `FUNC_JRL)) ? `PCSRC_REG :  // pc from register 2
                      `PCSRC_SEQ; // pc + 1
    
    //                  write signals               //
    // regWrite
    assign RegWrite = ( (opcode == `typeR && func_code == `FUNC_JRL) // stage ID JRL
                      || opcode == `OPCODE_JAL ) ? 1'b1 : 1'b0 ; // stage ID JAL
     
    // MemWrite
    assign MemWrite = ( opcode == `OPCODE_SWD ? 1'b1 : 1'b0 );
    
    // PC_en
    // PC_en = PCWrite  + PCWriteCond * ALU_compare (from lecture05. multicycle cpu slides)
    // the final signal to update pc or not
    assign PC_en = (stage == `STAGE_IF // update pc + 1                       ////////////////////// NEED TO BE FIXED
                 || stage == `STAGE_ID && (isItype_Branch && (isJtype_Jump || isRtype_Jump)) // update pc + 1 (for branch so that next instr = pc + 1 + imm) 
                                                                                             // or {pc, target} (jump)
                 || stage == `STAGE_EX && isItype_Branch && isBranchTaken) ? 1 : 0; // update pc + imm that was caldulated at ID stage