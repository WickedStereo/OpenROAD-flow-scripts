///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_validity_tracker                                                          //
// Description: Validity tracker manages stage validity considering stall, bubble,
//              and squash conditions. Implements sticky flags to remember
//              squashes during stalls/bubbles. Ensures proper pipeline state
//              management and hazard resolution. This module handles the complex
//              interactions between stalls (pipeline hold), bubbles (invalid instructions
//              introduced into pipeline), and squashes (explicit invalidation). It uses
//              sticky flags to remember squash conditions that occur during stalls or
//              bubbles, ensuring proper pipeline state management and hazard resolution.
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////


module cpu64_validity_tracker (
    //===================== Clock and Reset =====================//
    input       clk_i,              // System clock
    input       rst_ni,             // Active-low reset

    //===================== Pipeline Control Inputs =============//
    input       valid_i,            // Input instruction valid
    input       squash_i,           // Squash current instruction
    input       bubble_i,           // Insert bubble (NOP) instruction
    input       stall_i,            // Stall pipeline stage

    //===================== Validity Output ====================//
    output wire valid_ao            // Output instruction valid
);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Sticky Flag Registers                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Sticky flags to remember squash conditions that occur during stalls or bubbles
    // These flags ensure that squashes are not lost when they occur during pipeline stalls

    reg  squashed_during_stall;     // Remember squash that occurred during stall
    reg  squashed_during_bubble;    // Remember squash that occurred during bubble

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Stall Squash Tracker                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Track squashes that occur during pipeline stalls
    // This ensures that squashes are not lost when they happen during stalled periods

    always @(posedge clk_i) begin
        if (~rst_ni || (~stall_i && ~bubble_i)) 
            // Reset or not stalled/bubbled: clear the sticky flag
            squashed_during_stall   <= 'b0;
        else if (stall_i && squash_i) 
            // Stalled and squashed: set the sticky flag to remember the squash
            squashed_during_stall   <= 'b1;
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Bubble Squash Tracker                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Track squashes that occur during pipeline bubbles
    // This ensures that squashes are not lost when they happen during bubbled periods

    always @(posedge clk_i) begin
        if (~rst_ni || (~stall_i && ~bubble_i)) 
            // Reset or not stalled/bubbled: clear the sticky flag
            squashed_during_bubble   <= 'b0;
        else if (bubble_i && squash_i) 
            // Bubbled and squashed: set the sticky flag to remember the squash
            squashed_during_bubble   <= 'b1;
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Validity Output Logic                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate the final validity output considering all conditions
    // An instruction is valid only if it was valid and not squashed or bubbled

    assign valid_ao = valid_i   &&                    // Input instruction must be valid
                      ~squash_i && ~squashed_during_stall &&  // Not currently squashed or remembered squash during stall
                      ~bubble_i && ~squashed_during_bubble;   // Not currently bubbled or remembered squash during bubble


endmodule

