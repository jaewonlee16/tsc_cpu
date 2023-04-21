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
     output IRWrite,
     output PVSWrite,
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
    
    // stage
    reg [2 : 0] stage;
    reg [2 : 0] next_stage;
    
    // decide if the branch instruction is taken or not taken
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
    assign output_active = ( /*stage == `STAGE_ID && */opcode == `typeR && func_code == `FUNC_WWD );
    assign is_halted = ( stage != `STAGE_IF && (opcode == `typeR) && (func_code == `FUNC_HLT) );
    assign writeM = ( stage == `STAGE_MEM && opcode == `OPCODE_SWD );
    
   
    // ALU op signals
    always @ (*) begin
        if ( stage == `STAGE_IF || stage == `STAGE_ID ) ALUOperation = `OP_ADD;  // used for IF: pc + 1 , ID: pc + imm (branch)
        else if (stage == `STAGE_EX) begin
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
        else ALUOperation = 4'bx; // stage == MEM or stage == WB
     end  
    
    // readM signal
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
    
    // ALUSrc A signal
    assign ALUSrcA = (stage == `STAGE_IF || stage == `STAGE_ID) ? `ALUSRCA_PC : `ALUSRCA_REG; // IF : pc + 1  ID: pc + imm (branch)
    
    // ALUSrc B signal
    always @ (*) begin
        if(stage == `STAGE_IF) ALUSrcB = `ALUSRCB_ONE; // IF: pc + 1
        else if (stage == `STAGE_ID) ALUSrcB = isItype_Branch ? `ALUSRCB_IMM : `ALUSRCB_ONE; // ID: pc + imm (branch)
        else if(stage == `STAGE_EX) begin
            if( opcode == `OPCODE_BNE || opcode == `OPCODE_BEQ ) ALUSrcB = `ALUSRCB_REG;    // compare two registers
            else if( opcode == `OPCODE_BGZ || opcode == `OPCODE_BLZ ) ALUSrcB = `ALUSRCB_ZERO;  // compare register(ALUSrcA) and zero
            else if( isItype_Arithmetic || isItype_Memory ) ALUSrcB = `ALUSRCB_IMM; // for i type except for branch
            else if( isRtype_Arithmetic) ALUSrcB = `ALUSRCB_REG;    // for r type
            else ALUSrcB = 2'bz;
        end
        else ALUSrcB = 2'bz;
    end
    
    // IorD signal
    assign IorD = ( PC_en ? `IORD_I : `IORD_D );
    
    // PCSource
    assign PCSource = (isItype_Branch  && stage == `STAGE_EX) ? `PCSRC_BRANCH :     // pc from branch
                      isJtype_Jump ? `PCSRC_JUMP :      // pc from jump
                      (opcode == `typeR && ( func_code == `FUNC_JPR || func_code == `FUNC_JRL)) ? `PCSRC_REG :  // pc from register 2
                      `PCSRC_SEQ; // pc + 1
    
    //                  write signals               //
    // regWrite
    assign RegWrite = ( stage == `STAGE_WB 
                    || (stage == `STAGE_IF && 
                            ( (opcode == `typeR && func_code == `FUNC_JRL) // stage ID JRL
                            || opcode == `OPCODE_JAL ) )? 1'b1 : 1'b0 ); // stage ID JAL
     
    // MemWrite
    assign MemWrite = ( stage == `STAGE_MEM && opcode == `OPCODE_SWD ? 1'b1 : 1'b0 );
    
    // PC_en
    // PC_en = PCWrite  + PCWriteCond * ALU_compare (from lecture05. multicycle cpu slides)
    // the final signal to update pc or not
    assign PC_en = (stage == `STAGE_IF // update pc + 1
                 || stage == `STAGE_ID && (isItype_Branch && (isJtype_Jump || isRtype_Jump)) // update pc + 1 (for branch so that next instr = pc + 1 + imm) 
                                                                                             // or {pc, target} (jump)
                 || stage == `STAGE_EX && isItype_Branch && isBranchTaken) ? 1 : 0; // update pc + imm that was caldulated at ID stage
    
    // IRWrite
    assign IRWrite = stage == `STAGE_IF ? 1 : 0;
    
    // pvsWrite
    assign PVSWrite = ( ( // if instruction finishes
                        ( stage == `STAGE_ID && 
                            ( isRtype_Special || isJtype_Jump) ) 
                      || ( stage == `STAGE_EX && isItype_Branch ) 
                      ||( stage == `STAGE_MEM && (opcode == `OPCODE_SWD)) 
                      ||( stage == `STAGE_WB && 
                            ( opcode == `OPCODE_LWD || isRtype_Arithmetic || isItype_Arithmetic )) // if at WB stage, all finish
                    ) ? 1'b1 : 1'b0 );
    
    
    
    // sequential logic for state(stage)
    always @ (posedge clk) begin
        if (!reset_n) begin next_stage <= `STAGE_IF; stage <= 0; end
        else stage <= next_stage;
    end
    
    // combinational logic for next state (next_stage)
    always @ (*) begin
        case (stage)
                `STAGE_IF : next_stage = `STAGE_ID;
                
                `STAGE_ID: if (isJtype_Jump || isRtype_Special) next_stage <= `STAGE_IF; 
                    else if ( (opcode == `typeR) && (func_code == `FUNC_HLT) ) next_stage = `STAGE_ID;
                    else next_stage = `STAGE_EX;
                    
                `STAGE_EX: if (isItype_Branch) next_stage = `STAGE_IF;
                else if (isItype_Memory) next_stage = `STAGE_MEM;
                else next_stage = `STAGE_WB;
                
                `STAGE_MEM: if (opcode == `OPCODE_LWD) next_stage = `STAGE_WB;
                else next_stage = `STAGE_IF;
                
                `STAGE_WB: next_stage = `STAGE_IF;
        endcase      
    end

endmodule