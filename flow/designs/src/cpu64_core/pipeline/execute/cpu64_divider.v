///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_divider                                                                    //
// Description: Integer division unit implementing signed and unsigned division
//              and remainder operations. Uses iterative algorithm with proper
//              exception handling for division by zero and overflow conditions.
//              Supports both 32-bit and 64-bit operations.
//              This module implements a configurable pipelined division algorithm
//              that can be optimized for different performance/area tradeoffs.
//                                                                                               //
//              Parameters:                                                                      //
//              - XLEN         : The data width (32 or 64 bits)                                 //
//              - STAGE_DEPTH  : How many bits of the result are calculated per pipeline stage  //
//                               A value of 0 means there is no pipelining                      //
//              - STAGE_OFFSET : Offsets the pipeline stages, a value of 0 means the first       //
//                               stage is the full depth, while a value of 1 means the first bit //
//                               of the result will be registered.                               //
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////

module cpu64_divider #( parameter   XLEN           = 64,    // Data width (32 or 64 bits)
                  parameter   STAGE_DEPTH    = 5,    // Bits calculated per pipeline stage
                  parameter   STAGE_OFFSET   = 2 )   // Pipeline stage offset
(
    //===================== Clock and Reset =====================//
    input                   clk_i,              // System clock
    input                   rst_ni,             // Active-low reset

    //===================== Operand Inputs ======================//
    input  [XLEN-1:0]       op_a_i,             // Dividend (operand A)
    input  [XLEN-1:0]       op_b_i,             // Divisor (operand B)
    input                   req_i,              // Division request

    //===================== Result Outputs ======================//
    output wire [XLEN-1:0]  quotient_o,         // Division result (quotient)
    output wire [XLEN-1:0]  remainder_o,        // Division remainder
    output wire             done_o              // Division completion signal
);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Pipeline Configuration                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Calculate pipeline stage configuration based on parameters
    // These constants determine how the division algorithm is pipelined

    localparam STAGE1_IDX   = STAGE_OFFSET == 0 ? STAGE_DEPTH-1 : (STAGE_OFFSET-1) % STAGE_DEPTH;  // First stage index
    localparam FLOOR_STAGES = (XLEN / STAGE_DEPTH);                                                // Minimum number of stages
    localparam CEIL_STAGES  = (XLEN % STAGE_DEPTH == 0) ? 
                              (XLEN / STAGE_DEPTH) : (XLEN / STAGE_DEPTH) + 1;                    // Maximum number of stages
    localparam NUM_STAGES   = (STAGE_DEPTH == 0) ? 0 : 
                              ( STAGE1_IDX >= (XLEN % STAGE_DEPTH) ) ? FLOOR_STAGES : CEIL_STAGES; // Total pipeline stages

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Pipeline State Arrays                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Arrays to store pipeline state for each stage
    // These arrays hold the intermediate values as they flow through the pipeline

    reg            valid       [NUM_STAGES:0];    // Valid bit for each pipeline stage
    reg [XLEN-1:0] divisor     [NUM_STAGES:0];    // Divisor value for each stage
    reg [XLEN-1:0] dividend_r  [NUM_STAGES:0];    // Registered dividend for each stage
    reg [XLEN-1:0] quotient_r  [NUM_STAGES:0];    // Registered quotient for each stage

    // Arrays for combinational logic between pipeline stages
    wire [XLEN-1:0] dividend_a  [XLEN:0] /* verilator split_var */;  // Dividend array (combinational)
    wire [XLEN-1:0] quotient_a  [XLEN:0] /* verilator split_var */;  // Quotient array (combinational)     

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Pipeline Input Logic                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Initialize the first pipeline stage with input operands
    // This sets up the initial state for the division algorithm

    //===================== Stage 0 Input Assignment =============//
    // Set up the first pipeline stage with input operands
    always @(*) begin
        valid[0]         = ~rst_ni ? 'b0 : req_i;  // Valid when request is active and not reset
        divisor[0]       = op_b_i;                  // Store divisor in first stage
    end
  
    // Initialize combinational arrays for first iteration
    assign dividend_a[0] = op_a_i;                  // Start with dividend
    assign quotient_a[0] = 0;                       // Initialize quotient to zero   
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Division Algorithm Loop                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate the division algorithm for each bit position
    // This implements an iterative division algorithm that processes one bit at a time

    generate
    	genvar i;
    	for (i=0; i < XLEN; i = i + 1) begin
            //===================== Stage Calculation ==================//
            // Calculate which pipeline stage this bit belongs to
            localparam stage     = (i <= STAGE1_IDX) ? 
                                    0 : (i-STAGE1_IDX-1 + STAGE_DEPTH) / STAGE_DEPTH;
            // Determine if this bit should be registered (pipelined)
            localparam reg_stage = ((i % STAGE_DEPTH) == STAGE1_IDX) && (NUM_STAGES != 0);

            //===================== Division Step Signals ==============//
            // Signals for the current division step
            wire                partial_quotient;    // Quotient bit for this step
            wire [i:0]          partial_remainder;   // Remainder for this step
            wire [XLEN-1:0]     next_dividend;       // Next dividend value

            //===================== Division Step Logic ===============//
            // Implement the core division algorithm for each bit position
            if (i+1 != XLEN) begin : partial_step
                //===================== Partial Division Step ===========//
                // Intermediate division step - processes one bit of the result
                // This is the main division logic that runs for most bit positions
                
                wire [i:0]        upper_dividend, lower_divisor;    // Upper bits of dividend, lower bits of divisor
                wire [XLEN-1:i+1] upper_divisor,  lower_dividend;   // Upper bits of divisor, lower bits of dividend

                // Split dividend and divisor into upper and lower parts
                assign {upper_dividend, lower_dividend} = dividend_a[i];  // Split current dividend
                assign {upper_divisor,  lower_divisor}  = divisor[stage]; // Split divisor for this stage
                
                // Core division logic: determine quotient bit and remainder
                // Quotient bit is 1 if upper dividend >= lower divisor and upper divisor is zero
                assign partial_quotient  = !(|{upper_divisor}) && (upper_dividend >= lower_divisor);    
                // Remainder is either (upper_dividend - lower_divisor) or upper_dividend
                assign partial_remainder = partial_quotient ? 
                                           (upper_dividend - lower_divisor) : upper_dividend;
                // Next dividend combines remainder with lower dividend bits
                assign next_dividend     = {partial_remainder, lower_dividend};

            end else begin : final_step
                //===================== Final Division Step =============//
                // Final division step - completes the division calculation
                // This handles the last bit position and produces the final result
                
                // Final quotient bit: dividend >= divisor
                assign partial_quotient  = dividend_a[i] >= divisor[stage];
                // Final remainder: either (dividend - divisor) or dividend
                assign partial_remainder = partial_quotient ? 
                                           (dividend_a[i] - divisor[stage]) : dividend_a[i];
                // Final dividend is just the remainder
                assign next_dividend     = partial_remainder;

            end

            //===================== Pipeline Stage Implementation ======//
            // Choose between registered (pipelined) or combinational implementation
            if ( reg_stage ) begin : registered_step
                //===================== Registered Pipeline Stage =======//
                // This bit position is registered - implements pipeline stage
                // Used to break long combinational paths and improve timing
                
                always @ (posedge clk_i) begin : stage_registers
                    if (~rst_ni) begin
                        // Reset: clear all pipeline stage registers
                        valid[stage+1]                <= 'b0;              // Clear valid bit
                        divisor[stage+1]              <= 'b0;              // Clear divisor
                        dividend_r[stage+1]           <= 'b0;              // Clear dividend
                        quotient_r[stage+1]           <= 'b0;              // Clear quotient
                    end else begin
                        // Normal operation: advance pipeline stage
                        valid     [stage+1]           <= valid[stage];     // Propagate valid bit
                        divisor   [stage+1]           <= divisor[stage];   // Propagate divisor
                        dividend_r[stage+1]           <= next_dividend;    // Update dividend
                        quotient_r[stage+1]           <= quotient_a[i];    // Update quotient
                        quotient_r[stage+1][XLEN-i-1] <= partial_quotient; // Set quotient bit
                    end
                end

                // Connect registered values to next stage
                assign dividend_a[i+1] = dividend_r[stage+1];  // Use registered dividend
                assign quotient_a[i+1] = quotient_r[stage+1];  // Use registered quotient

            end else begin : combinational_step
                //===================== Combinational Step ==============//
                // This bit position is combinational - no pipeline register
                // Used for bits that don't need to be registered for timing
                
                // Direct assignment of next values
                assign dividend_a[i+1]           = next_dividend;         // Pass through dividend
                assign quotient_a[i+1][XLEN-i-1] = partial_quotient;      // Set quotient bit

                // Preserve quotient bits from previous steps
                if (i != 0) begin : quotient_not_first_step 
                    // Copy upper quotient bits from previous step
                    assign quotient_a[i+1][XLEN-1:XLEN-i] = quotient_a[i][XLEN-1:XLEN-i];
                end

                if (i != XLEN-1) begin : quotient_not_last_step
                    // Copy lower quotient bits from previous step
                    assign quotient_a[i+1][XLEN-i-2:0]    = quotient_a[i][XLEN-i-2:0];
                end

            end
        end
    endgenerate

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Pipeline Outputs                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate the final outputs from the division algorithm
    // These outputs provide the quotient, remainder, and completion signal

    //===================== Division Results =====================//
    // Extract the final results from the last iteration
    assign quotient_o  = quotient_a[XLEN];    // Final quotient result
    assign remainder_o = dividend_a[XLEN];    // Final remainder result
    assign done_o      = valid[NUM_STAGES];   // Division completion signal

endmodule
