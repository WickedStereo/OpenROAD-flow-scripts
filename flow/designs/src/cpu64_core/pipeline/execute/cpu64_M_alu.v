///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_M_alu                                                                     //
// Description: Multiply/Divide ALU for multi-cycle M-extension operations.
//              Implements MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
//              operations for both 32-bit and 64-bit data widths. Uses
//              iterative algorithms with proper exception handling.
//              This is a multi-cycle ALU that can stall the pipeline during
//              long operations like division. Multiplication is single-cycle
//              but division requires multiple cycles.
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_M_alu (
    //===================== Clock and Reset =====================//
    input                   clk_i,              // System clock
    input                   rst_ni,             // Active-low reset

    //===================== ALU Operands =======================//
    input  [`XLEN-1:0]      a_i,                // ALU operand A (64-bit)
    input  [`XLEN-1:0]      b_i,                // ALU operand B (64-bit)

    //===================== ALU Operation ======================//
    input  [5:0]            alu_operation_i,    // ALU operation code (6-bit)

    //===================== ALU Outputs ========================//
    output reg [`XLEN-1:0]  alu_result_oa,      // ALU result (64-bit)
    output wire             stall_o             // ALU stall required
);
    // TODO - multiplier must be pipelined, then the pre and post processing steps should be 
    //        pipelined.

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    M-ALU Preprocessing                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Preprocess operands for signed operations by converting to absolute values
    // This allows the core multiplication/division logic to work with unsigned numbers
    // The sign information is preserved for post-processing

    reg [63:0] op_a, op_b;    // Preprocessed operands for core operations

    //===================== 64-bit Operand Sign Detection =======//
    // Detect sign bits and compute result sign for 64-bit operations
    wire a_neg        = a_i[63];                    // Operand A is negative
    wire b_neg        = b_i[63];                    // Operand B is negative
    wire res_sign     = a_neg ^ b_neg;              // Result sign (XOR of operand signs)
    wire [63:0] abs_a = a_neg ? ~a_i + 1 : a_i;     // Absolute value of A (two's complement)
    wire [63:0] abs_b = b_neg ? ~b_i + 1 : b_i;     // Absolute value of B (two's complement)

    //===================== 32-bit Operand Sign Detection =======//
    // Detect sign bits and compute result sign for 32-bit W-extension operations
    wire a32_neg        = a_i[31];                  // Operand A is negative (32-bit)
    wire b32_neg        = b_i[31];                  // Operand B is negative (32-bit)
    wire res32_sign     = a32_neg ^ b32_neg;        // Result sign (32-bit)
    wire [31:0] abs_a32 = a32_neg ? ~a_i[31:0] + 32'b1 : a_i[31:0];  // Absolute value of A (32-bit)
    wire [31:0] abs_b32 = b32_neg ? ~b_i[31:0] + 32'b1 : b_i[31:0];  // Absolute value of B (32-bit)

    //===================== Operand Preprocessing ===============//
    // Select appropriate operands based on operation type
    // Signed operations use absolute values, unsigned operations use original values
    always @(*) begin
        //===================== Operand A Selection =============//
        case (alu_operation_i)
            `ALU_OP_MULH,  `ALU_OP_MULHSU,      // Signed multiply high operations
            `ALU_OP_DIV,   `ALU_OP_REM          // Signed divide/remainder operations
                : op_a = abs_a;                 // Use absolute value for signed operations
            `ALU_OP_DIVW,  `ALU_OP_REMW         // Signed 32-bit divide/remainder operations
                : op_a = { 32'b0, abs_a32[31:0] };  // Use 32-bit absolute value, zero-extend
            `ALU_OP_DIVUW, `ALU_OP_REMUW        // Unsigned 32-bit divide/remainder operations
                : op_a = { 32'b0, a_i[31:0] };  // Use 32-bit original value, zero-extend
            default                             // All other operations (MUL, MULHU, etc.)
                : op_a = a_i;                   // Use original value
        endcase

        //===================== Operand B Selection =============//
        case (alu_operation_i)
            `ALU_OP_MULH, `ALU_OP_DIV,          // Signed multiply high and divide operations
            `ALU_OP_REM                         // Signed remainder operations
                : op_b = abs_b;                 // Use absolute value for signed operations
            `ALU_OP_DIVW,  `ALU_OP_REMW         // Signed 32-bit divide/remainder operations
                : op_b = { 32'b0, abs_b32[31:0] };  // Use 32-bit absolute value, zero-extend
            `ALU_OP_DIVUW, `ALU_OP_REMUW        // Unsigned 32-bit divide/remainder operations
                : op_b = { 32'b0, b_i[31:0] };  // Use 32-bit original value, zero-extend
            default                             // All other operations (MUL, MULHU, etc.)
                : op_b = b_i;                   // Use original value
        endcase
    end

    //===================== Division Request Detection ==========//
    // Detect if current operation requires division and divisor is non-zero
    // Division by zero is handled by returning special values
    wire div_alu_req = ( (alu_operation_i == `ALU_OP_DIV)     ||  // 64-bit signed division
                         (alu_operation_i == `ALU_OP_DIVW)    ||  // 32-bit signed division
                         (alu_operation_i == `ALU_OP_DIVU)    ||  // 64-bit unsigned division
                         (alu_operation_i == `ALU_OP_DIVUW)   ||  // 32-bit unsigned division
                         (alu_operation_i == `ALU_OP_REM)     ||  // 64-bit signed remainder
                         (alu_operation_i == `ALU_OP_REMW)    ||  // 32-bit signed remainder
                         (alu_operation_i == `ALU_OP_REMU)    ||  // 64-bit unsigned remainder
                         (alu_operation_i == `ALU_OP_REMUW))  &&  // 32-bit unsigned remainder
                         (op_b != 'b0);                          // Only if divisor is non-zero


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           M-ALU                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Core multiplication and division logic
    // Multiplication is single-cycle, division is multi-cycle with stall capability

    //===================== Core Operation Results =============//
    wire [127:0] product_u;        // Unsigned multiplication result (128-bit)
    wire [63:0]  quotient_raw;     // Raw quotient from divider
    wire [63:0]  remainder_raw;    // Raw remainder from divider
    wire [63:0]  quotient_u;       // Final quotient (with division by zero handling)
    wire [63:0]  remainder_u;      // Final remainder (with division by zero handling)
    wire         div_done;         // Division completion signal

    //===================== Division State Machine =============//
    // Track division progress to manage multi-cycle operations
    reg div_in_progress;           // Division is currently in progress

    // Division state machine: start division on request, stop on completion
    always @(posedge clk_i) begin
        if (~rst_ni || div_done)
            div_in_progress <= 'b0;                    // Reset or division complete: clear progress
        else if (div_alu_req)
            div_in_progress <= 'b1;                    // Division requested: set progress
    end

    //===================== Division Unit Instantiation ========//
    // Multi-cycle divider for division and remainder operations
    cpu64_divider u_divider(
        .clk_i  (clk_i),                               // System clock
        .rst_ni (rst_ni),                              // Active-low reset

        .op_a_i (op_a),                                // Dividend (preprocessed)
        .op_b_i (op_b),                                // Divisor (preprocessed)
        .req_i  (div_alu_req && ~div_in_progress),     // Division request (start new division)

        .quotient_o (quotient_raw),                    // Raw quotient result
        .remainder_o (remainder_raw),                  // Raw remainder result
        .done_o (div_done)                             // Division completion signal
    );

    //===================== Core Operations ====================//
    assign product_u   = op_a * op_b;                  // Single-cycle multiplication (TODO: pipeline)
    assign quotient_u  = (op_b == 'b0) ? `NEGATIVE_1 : quotient_raw;  // Handle division by zero
    assign remainder_u = (op_b == 'b0) ? op_a        : remainder_raw; // Handle division by zero

    //===================== Stall Signal Generation ============//
    // Stall pipeline during division operations
    assign stall_o = (div_in_progress && ~div_done) ||                    // Division in progress
                     (div_alu_req     && ~div_done  && ~div_in_progress); // Starting new division


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   M-ALU Post Processing                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Post-process results to handle signed operations and format outputs correctly
    // Converts unsigned results back to signed format and selects appropriate result portions

    //===================== Post-Processing Signals =============//
    reg [63:0]  div_res_a,  quotient_neg, remainder_neg;  // Division result processing
    reg [127:0] product_su, mul_res_a,    product_neg;    // Multiplication result processing
    reg         carry_su;                                  // Carry for signed-unsigned multiply

    //===================== Result Post-Processing ==============//
    // Convert unsigned results back to signed format and select appropriate portions
    always @(*) begin
        //===================== Multiplication Post-Processing =//
        // Handle signed multiplication by negating result if needed
        product_neg   = ~product_u + 1;                    // Two's complement negation
        carry_su      = (product_u[63:0] == 64'b0);        // Carry for signed-unsigned multiply
        product_su    = a_neg ? ( ~product_u + {127'b0, carry_su} ) : product_u;  // Signed-unsigned multiply

        //===================== Division Post-Processing =======//
        // Handle signed division by negating quotient/remainder if needed
        quotient_neg  = (op_b == 'b0) ? `NEGATIVE_1 : ~quotient_u  + 1;  // Negate quotient
        remainder_neg = ~remainder_u + 1;                  // Negate remainder

        //===================== Multiplication Result Selection =//
        // Select appropriate multiplication result based on operation type
        case (alu_operation_i)
            `ALU_OP_MULH    : mul_res_a = res_sign ? product_neg : product_u;  // Signed multiply high
            `ALU_OP_MULHSU  : mul_res_a = product_su;                          // Signed-unsigned multiply high
            default         : mul_res_a = product_u;                           // Unsigned multiply high
        endcase

        //===================== Division Result Selection =======//
        // Select appropriate division result based on operation type
        case (alu_operation_i)
            `ALU_OP_DIV   : div_res_a  = res_sign ? quotient_neg  : quotient_u;   // 64-bit signed division
            `ALU_OP_REM   : div_res_a  = a_neg    ? remainder_neg : remainder_u;  // 64-bit signed remainder
            `ALU_OP_DIVU  : div_res_a  = quotient_u;                              // 64-bit unsigned division
            `ALU_OP_REMU  : div_res_a  = remainder_u;                             // 64-bit unsigned remainder
            `ALU_OP_DIVW  : div_res_a  = res32_sign ? quotient_neg  : quotient_u; // 32-bit signed division
            `ALU_OP_REMW  : div_res_a  = a32_neg    ? remainder_neg : remainder_u; // 32-bit signed remainder
            `ALU_OP_DIVUW : div_res_a  = quotient_u;                              // 32-bit unsigned division
            `ALU_OP_REMUW : div_res_a  = remainder_u;                             // 32-bit unsigned remainder
            default                     : div_res_a  = 'b0;                       // Default: zero
        endcase

        //===================== Final Result Selection ==========//
        // Select final ALU result based on operation type
        case (alu_operation_i)
            `ALU_OP_MUL     : alu_result_oa = mul_res_a[`XLEN-1:0];                    // 64-bit multiply (low)
            `ALU_OP_MULH    : alu_result_oa = mul_res_a[((2*`XLEN)-1):`XLEN];         // 64-bit multiply (high)
            `ALU_OP_MULHSU  : alu_result_oa = mul_res_a[((2*`XLEN)-1):`XLEN];         // 64-bit signed-unsigned multiply (high)
            `ALU_OP_MULHU   : alu_result_oa = mul_res_a[((2*`XLEN)-1):`XLEN];         // 64-bit unsigned multiply (high)
            `ALU_OP_MULW    : alu_result_oa = { {32{mul_res_a[31]}}, mul_res_a[31:0] }; // 32-bit multiply with sign extension
            `ALU_OP_DIV     : alu_result_oa = div_res_a;                               // 64-bit division
            `ALU_OP_DIVU    : alu_result_oa = div_res_a;                               // 64-bit unsigned division
            `ALU_OP_REM     : alu_result_oa = div_res_a;                               // 64-bit remainder
            `ALU_OP_REMU    : alu_result_oa = div_res_a;                               // 64-bit unsigned remainder
            default         : alu_result_oa = { {32{div_res_a[31]}}, div_res_a[31:0] }; // 32-bit operations with sign extension
        endcase
    end

    endmodule
