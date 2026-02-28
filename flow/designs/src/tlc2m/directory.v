// =============================================================================
// Project: TileLink Inclusive Directory Coherence (TIDC) System
// Module: Directory
// Description: Stores and manages the global coherence state for each cache line
//              Simplified version without unnecessary state machine
// =============================================================================

// Include shared parameter definitions
`include "tidc_params.v"

module directory (
    input  wire                       clk,
    input  wire                       rst_n,
    
    // Directory lookup interface - now combinational
    input  wire                       lookup_req,
    input  wire [63:0]                lookup_addr,
    output wire                       lookup_valid,
    output wire [2:0]                 lookup_state,  // DIR_STATE_*
    output wire [1:0]                 lookup_presence,  // Bit vector of L1s with this line
    output wire [1:0]                 lookup_tip_state, // Bit vector of L1s with Tip permission
    
    // Directory update interface - single cycle
    input  wire                       update_req,
    input  wire [63:0]                update_addr,
    input  wire [2:0]                 update_state,  // New directory state (DIR_STATE_*)
    input  wire [1:0]                 update_presence,  // New presence vector
    input  wire [1:0]                 update_tip_state, // New Tip state vector
    output wire                       update_done
);

    // Directory parameters
    localparam DIR_SIZE = 64;  // Small directory for testing
    localparam DIR_INDEX_WIDTH = 6;  // 6 bits for 64 entries
    localparam DIR_TAG_WIDTH = 64 - DIR_INDEX_WIDTH; // 58 bits
    
    // Directory entry structure
    reg [DIR_TAG_WIDTH-1:0]       dir_tags [DIR_SIZE-1:0];
    reg [2:0]                     dir_states [DIR_SIZE-1:0];
    reg [1:0]                     dir_presence [DIR_SIZE-1:0];
    reg [1:0]                     dir_tip_state [DIR_SIZE-1:0];
    reg                           dir_valid [DIR_SIZE-1:0];
    
    // Extract index and tag from address
    function [DIR_INDEX_WIDTH-1:0] get_index;
        input [63:0] addr;
        begin
            get_index = addr[DIR_INDEX_WIDTH-1:0];
        end
    endfunction
    
    function [DIR_TAG_WIDTH-1:0] get_tag;
        input [63:0] addr;
        begin
            get_tag = addr[63:DIR_INDEX_WIDTH];
        end
    endfunction
    
    // Combinational lookup logic
    wire [DIR_INDEX_WIDTH-1:0] lookup_index = get_index(lookup_addr);
    wire [DIR_TAG_WIDTH-1:0] lookup_tag = get_tag(lookup_addr);
    wire lookup_hit = dir_valid[lookup_index] && (dir_tags[lookup_index] == lookup_tag);
    
    // Lookup outputs - combinational
    assign lookup_valid = lookup_req;  // Always valid when requested
    assign lookup_state = lookup_hit ? dir_states[lookup_index] : DIR_STATE_INVALID;
    assign lookup_presence = lookup_hit ? dir_presence[lookup_index] : 2'b00;
    assign lookup_tip_state = lookup_hit ? dir_tip_state[lookup_index] : 2'b00;
    
    // Update done - single cycle
    assign update_done = update_req;  // Done immediately when requested
    
    // Reset and update logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize directory
            for (i = 0; i < DIR_SIZE; i = i + 1) begin
                dir_valid[i] <= 1'b0;
                dir_tags[i] <= {DIR_TAG_WIDTH{1'b0}};
                dir_states[i] <= DIR_STATE_INVALID;
                dir_presence[i] <= 2'b00;
                dir_tip_state[i] <= 2'b00;
            end
        end
        else begin
            // Handle directory updates
            if (update_req) begin
                dir_valid[get_index(update_addr)] <= 1'b1;
                dir_tags[get_index(update_addr)] <= get_tag(update_addr);
                dir_states[get_index(update_addr)] <= update_state;
                dir_presence[get_index(update_addr)] <= update_presence;
                dir_tip_state[get_index(update_addr)] <= update_tip_state;
                
                // $display("[DIR DEBUG] UPDATE addr=%h: state=%b, presence=%b, tip_state=%b", 
                //         update_addr, update_state, update_presence, update_tip_state);
            end
            
            // Debug lookup hits
            if (lookup_req) begin
                if (lookup_hit) begin
                    // $display("[DIR DEBUG] HIT addr=%h: state=%b, presence=%b, tip_state=%b", 
                    //         lookup_addr, dir_states[lookup_index], dir_presence[lookup_index], dir_tip_state[lookup_index]);
                end else begin
                    // $display("[DIR DEBUG] MISS addr=%h: returning INVALID", lookup_addr);
                end
            end
        end
    end

endmodule 