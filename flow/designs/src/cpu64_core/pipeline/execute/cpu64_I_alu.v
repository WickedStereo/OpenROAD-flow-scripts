///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_I_alu                                                                     //
// Description: Integer ALU performing arithmetic, logical, and shift operations.
//              Implements ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA
//              operations for both 32-bit and 64-bit data widths. Handles
//              signed and unsigned comparisons with proper overflow detection.
//              This is a single-cycle ALU that performs all basic integer operations
//              required by the RISC-V RV64IMAC instruction set.
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_I_alu (
    //===================== ALU Operands =======================//
    input      [`XLEN-1:0] a_i,              // ALU operand A (64-bit)
    input      [`XLEN-1:0] b_i,              // ALU operand B (64-bit)
    input      [5:0]       alu_operation_i,  // ALU operation code (6-bit)

    //===================== ALU Result =========================//
    output reg [`XLEN-1:0] alu_result_oa     // ALU result (64-bit)
);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   32-bit Operand Extraction                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Extract 32-bit operands for RV64I W-extension operations
    // These operations work on 32-bit data but produce 64-bit results with sign extension

    wire [31:0] a_32 = a_i[31:0];    // 32-bit operand A (lower 32 bits)
    wire [31:0] b_32 = b_i[31:0];    // 32-bit operand B (lower 32 bits)

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   32-bit Operation Results                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Pre-compute 32-bit operation results for RV64I W-extension instructions
    // These results will be sign-extended to 64 bits in the main ALU logic

    wire [31:0] addw_res = a_32  + b_32;                    // 32-bit addition result
    wire [31:0] sllw_res = a_32 << b_32[4:0];               // 32-bit logical left shift result
    wire [31:0] srlw_res = a_32 >> b_32[4:0];               // 32-bit logical right shift result
    wire [31:0] subw_res = a_32  - b_32;                    // 32-bit subtraction result
    wire [31:0] sraw_res = $signed(a_32) >>> b_32[4:0];     // 32-bit arithmetic right shift result


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    ALU Operation Decoder                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Main ALU operation decoder implementing all RISC-V RV64IMAC integer operations
    // Handles both 64-bit operations and 32-bit W-extension operations

    always @ (*) begin
        case (alu_operation_i)
            //===================== 64-bit Arithmetic Operations =============//
            `ALU_OP_ADD  : alu_result_oa = a_i + b_i;                                    // 64-bit addition
            `ALU_OP_SUB  : alu_result_oa = a_i - b_i;                                    // 64-bit subtraction
            
            //===================== 64-bit Logical Operations ================//
            `ALU_OP_AND  : alu_result_oa = a_i & b_i;                                    // 64-bit bitwise AND
            `ALU_OP_OR   : alu_result_oa = a_i | b_i;                                    // 64-bit bitwise OR
            `ALU_OP_XOR  : alu_result_oa = a_i ^ b_i;                                    // 64-bit bitwise XOR
            
            //===================== 64-bit Shift Operations ==================//
            `ALU_OP_SLL  : begin
                // Shift left logical - using direct bit extraction
                alu_result_oa = a_i << b_i[5:0];
            end
            `ALU_OP_SRL  : alu_result_oa = a_i >> b_i[5:0];              // 64-bit logical right shift
            `ALU_OP_SRA  : alu_result_oa = $signed(a_i) >>> b_i[5:0];    // 64-bit arithmetic right shift
            
            //===================== 64-bit Comparison Operations =============//
            `ALU_OP_SLT  : alu_result_oa = $signed(a_i) < $signed(b_i) ? 64'd1: 'b0;   // 64-bit signed less than
            `ALU_OP_SLTU : alu_result_oa = a_i < b_i ? 64'd1: 'b0;                     // 64-bit unsigned less than
            
            //===================== Pass-Through Operation ===================//
            `ALU_OP_PASS : alu_result_oa = a_i;                                         // Pass operand A through

            //===================== RV64I W-Extension Operations =============//
            // 32-bit operations with sign extension to 64 bits
            `ALU_OP_ADDW : alu_result_oa = { {32{addw_res[31]}}, addw_res };            // 32-bit add with sign extension
            `ALU_OP_SLLW : alu_result_oa = { {32{sllw_res[31]}}, sllw_res };            // 32-bit logical left shift with sign extension
            `ALU_OP_SRLW : alu_result_oa = { {32{srlw_res[31]}}, srlw_res };            // 32-bit logical right shift with sign extension
            `ALU_OP_SUBW : alu_result_oa = { {32{subw_res[31]}}, subw_res };            // 32-bit subtract with sign extension
            `ALU_OP_SRAW : alu_result_oa = { {32{sraw_res[31]}}, sraw_res };            // 32-bit arithmetic right shift with sign extension
            
            //===================== Default Case =============================//
            default           : alu_result_oa = 'b0;                                     // Default: return zero
        endcase
    end

endmodule

