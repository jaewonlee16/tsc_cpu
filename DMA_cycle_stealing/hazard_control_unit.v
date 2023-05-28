`timescale 1ns/1ns

`include "constants.v"
`include "opcodes.v"

module hazard_control_unit
   #(parameter DATA_FORWARDING = 1)
   (input clk,
    input reset_n,
    input [3:0] opcode,
    input [5:0] func_code,

    // flush input signals
    input       jump_miss, // misprediction of unconditional branch
    input       i_branch_miss, // misprediction of conditional branch

    // signals that determine when to stall
    input [1:0] rs_ID, 
    input [1:0] rt_ID, 
    input       Reg_write_EX,
    input       Reg_write_MEM,
    input       Reg_write_WB,
    input [1:0] dest_EX,             // write_reg_addr_EX, 
    input [1:0] dest_MEM,            // write_reg_addr_MEM, 
    input [1:0] dest_WB,            // write_reg_addr_WB, 

    // load stall
    input       d_MEM_read_EX,
    input       d_MEM_read_MEM,
    input [1:0] rt_EX, 
    input [1:0] rt_MEM,
    input [1:0] rt_WB,

    input d_MEM_write_MEM,
    input [3 : 0] d_data_opcode,
    input doneWrite,

    // control signals
    output reg  stall_IFID, // stall pipeline IF_ID_register
    output reg  stall_IDEX,
    output reg  stall_EXMEM,
    output reg  flush_IFID, // flush if
    output reg  flush_IDEX, // flush id
    output reg  flush_MEMWB,
    output reg  pc_write,
    output reg  ir_write
);
    //memory latency

    reg [1 : 0] d_count; // for counting cycle for writing d_data


    always @ (posedge clk) begin
        if (!reset_n ) begin

            d_count <= 0;
        end
        else begin
            if (d_count == `LATENCY) begin 
                d_count <= 0;
            end
            else if (d_MEM_write_MEM) begin
                d_count <= d_count + 1;
            end
        end
    end

    // --------------------------  type of instructions --------------------------- //
    // --------------------- the same wires from control_unit.v
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
                       && (func_code == `FUNC_JPR  || func_code == `FUNC_JRL));

    wire use_rs, use_rt;
    assign use_rs = isRtype_Arithmetic || isItype_Memory || isItype_Branch || isRtype_Jump 
                 || (isItype_Arithmetic && opcode != `OPCODE_LHI) ? 1 : 0;
    assign use_rt = isRtype_Arithmetic || isItype_Memory || isItype_Branch ? 1 : 0; 

    // ---------------   data hazards  ---------------- //
    wire reg_write_stall_check;
    assign reg_write_stall_check = !DATA_FORWARDING
                               &&((use_rs && Reg_write_EX  && rs_ID == dest_EX) 
                               || (use_rs && Reg_write_MEM && rs_ID == dest_MEM) 
                               || (use_rt && Reg_write_EX  && rt_ID == dest_EX) 
                               || (use_rt && Reg_write_MEM && rt_ID == dest_MEM)) ? 1 : 0;
    
    wire data_forwarding_stall_check;
    assign data_forwarding_stall_check = DATA_FORWARDING
                               &&((isRtype_Jump && Reg_write_EX  && rs_ID == dest_EX) 
                               || (isRtype_Jump && Reg_write_MEM && rs_ID == dest_MEM)) ? 1 : 0;                  

   wire load_stall_check;
   assign load_stall_check = 
           ((use_rs || use_rt) && d_MEM_read_EX && (rs_ID == rt_EX || rt_ID == rt_EX)) ||
           ((use_rs || use_rt) && d_MEM_read_MEM && (rs_ID == rt_MEM || rt_ID == rt_MEM))  ? 1 : 0;
  
    
    wire d_mem_stall_check;
    assign d_mem_stall_check = d_MEM_read_MEM && (d_data_opcode == `OPCODE_NOP) 
                            || d_MEM_write_MEM && !doneWrite;

    always @ (*) begin
        
          
        if (d_mem_stall_check) begin
            // stall MEM to WB
            flush_IFID = 0;
            flush_IDEX = 0;
            flush_MEMWB = 1;
            stall_IFID = 1;
            stall_IDEX = 1;
            stall_EXMEM = 1;
            pc_write = 0;
            ir_write = 0;
        end

        else if (reg_write_stall_check || load_stall_check || data_forwarding_stall_check) begin
            // stall ID to EX
           stall_IFID = 1;
           stall_IDEX = 0;
           stall_EXMEM = 0;
           flush_IFID = 0;
           flush_IDEX = 1;
           flush_MEMWB = 0;
           pc_write = 0;
           ir_write = 0;
           
        end 
         // -------------- control hazards ----------------- //
        else if (i_branch_miss) begin
            // flush ID to EX
            stall_IFID = 0;
            stall_IDEX = 0;
           stall_EXMEM = 0;
            flush_IFID = 1;
            flush_IDEX = 1;
            flush_MEMWB = 0;
            pc_write = 1;
            ir_write = 1;
        end

        else if (jump_miss) begin
            // flush IF to ID
            stall_IFID = 0;
            stall_IDEX = 0;
           stall_EXMEM = 0;
            flush_IFID = 1;
            flush_IDEX = 0;
            flush_MEMWB = 0;
            pc_write = 1;
            ir_write = 1;
        end

        
        
        // ---------- default ---------------//
        else begin
            stall_IFID = 0;
            stall_IDEX = 0;
            stall_EXMEM = 0;
            flush_IFID = 0;
            flush_IDEX = 0;
            flush_MEMWB = 0;
            pc_write = 1;
            ir_write = 1;
    end
    end
endmodule