// =============================================================================
// Project: TileLink Inclusive Directory Coherence (TIDC) System
// Module: Simple 2-Master Arbiter
// Description: Simple round-robin arbiter for 2 L1 masters - much simpler than 
//              the general N-master arbiter for just 2 masters
// =============================================================================

module simple_arbiter (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Channel A requests from 2 masters
    input  wire [1:0]               a_valid_i,
    input  wire [5:0]               a_opcode_i,  // 2*3 bits packed
    output wire [1:0]               a_ready_o,
    
    // Channel C requests from 2 masters  
    input  wire [1:0]               c_valid_i,
    input  wire [5:0]               c_opcode_i,  // 2*3 bits packed
    output wire [1:0]               c_ready_o,
    
    // Arbiter outputs
    output reg                      arb_valid,
    output reg  [1:0]               arb_channel,   // 0 = Channel A, 1 = Channel C
    output reg                      arb_master_id, // 0 or 1 for 2 masters
    output wire [1:0]               arb_master_oh, // One-hot: [1:0] or [0:1]
    
    // Control
    input  wire                     arb_ready,
    output reg                      arb_busy
);

    // Convert master ID to one-hot (simplified)
    assign arb_master_oh = arb_master_id ? 2'b10 : 2'b01;

    // Simple round-robin state
    reg last_master;  // 0 or 1, tracks which master was served last
    
    // Ready signals - only the selected master gets ready (simplified)
    assign a_ready_o[0] = arb_ready && arb_valid && (arb_channel == 2'b00) && !arb_master_id;
    assign a_ready_o[1] = arb_ready && arb_valid && (arb_channel == 2'b00) && arb_master_id;
    assign c_ready_o[0] = arb_ready && arb_valid && (arb_channel == 2'b01) && !arb_master_id;
    assign c_ready_o[1] = arb_ready && arb_valid && (arb_channel == 2'b01) && arb_master_id;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arb_valid <= 1'b0;
            arb_channel <= 2'b00;
            arb_master_id <= 1'b0;
            arb_busy <= 1'b0;
            last_master <= 1'b0;
        end else begin
            // Default: not valid
            arb_valid <= 1'b0;
            arb_busy <= 1'b0;
            
            // Priority: Channel C > Channel A (TileLink spec)
            // Within each channel: round-robin between masters
            
            if (|c_valid_i) begin
                // Channel C has requests
                arb_valid <= 1'b1;
                arb_busy <= 1'b1;
                arb_channel <= 2'b01; // Channel C
                
                // Simple round-robin for 2 masters
                arb_master_id <= c_valid_i[~last_master] ? ~last_master : last_master;
                
                // Update round-robin state when request is accepted
                if (arb_ready) begin
                    last_master <= arb_master_id;
                end
                
            end else if (|a_valid_i) begin
                // Channel A has requests
                arb_valid <= 1'b1;
                arb_busy <= 1'b1;
                arb_channel <= 2'b00; // Channel A
                
                // Simple round-robin for 2 masters
                arb_master_id <= a_valid_i[~last_master] ? ~last_master : last_master;
                
                // Update round-robin state when request is accepted
                if (arb_ready) begin
                    last_master <= arb_master_id;
                end
            end
        end
    end

endmodule 