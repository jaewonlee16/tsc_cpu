`define FUNC_ADD 6'd0
`define FUNC_SUB 6'd1
`define FUNC_AND 6'd2
`define FUNC_ORR 6'd3
`define FUNC_NOT 6'd4
`define FUNC_TCP 6'd5
`define FUNC_SHL 6'd6
`define FUNC_SHR 6'd7
`define FUNC_WWD 6'd28
`define FUNC_JPR 6'd25
`define FUNC_JRL 6'd26
`define FUNC_HLT 6'd29

`define OPCODE_ADI 4'd4
`define OPCODE_ORI 4'd5
`define OPCODE_LHI 4'd6
`define OPCODE_LWD 4'd7
`define OPCODE_SWD 4'd8
`define OPCODE_BNE 4'd0
`define OPCODE_BEQ 4'd1
`define OPCODE_BGZ 4'd2
`define OPCODE_BLZ 4'd3
`define OPCODE_JMP 4'd9
`define OPCODE_JAL 4'd10


// ALU operations
`define	OP_ADD	4'b0000
`define	OP_SUB	4'b0001
//  Bitwise Boolean operation
`define	OP_ID		4'b0010
`define	OP_NAND	4'b0011
`define	OP_NOR	4'b0100
`define	OP_XNOR	4'b0101
`define	OP_NOT	4'b0110
`define	OP_AND	4'b0111
`define	OP_OR		4'b1000
`define	OP_XOR	4'b1001
// Shifting
`define	OP_TCP	4'b1010
`define	OP_SHL	4'b1011
`define	OP_SHR		4'b1100

`define	OP_LHI		4'b1111



// Stage
`define STAGE_IF 3'd1
`define STAGE_ID 3'd2
`define STAGE_EX 3'd3
`define STAGE_MEM 3'd4
`define STAGE_WB 3'd5