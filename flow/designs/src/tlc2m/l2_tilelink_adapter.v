// =============================================================================
// Project: TileLink Inclusive Directory Coherence (TIDC) System
// Module: L2 TileLink Adapter - Simplified for 2 Masters
// Description: Central TileLink Slave Agent and coherence manager for the TIDC system
//              Simplified version with explicit signals instead of packed arrays
// =============================================================================

// Include shared parameter definitions
`include "tidc_params.v"

module l2_tilelink_adapter (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Direct probe interfaces to L1 adapters (simplified for 2 masters)
    output wire                         l1_0_probe_req_valid,
    output wire                         l1_1_probe_req_valid,
    output wire [63:0]                  l1_0_probe_req_addr,
    output wire [63:0]                  l1_1_probe_req_addr,
    output wire [2:0]                   l1_0_probe_req_permissions,
    output wire [2:0]                   l1_1_probe_req_permissions,
    
    input  wire                         l1_0_probe_ack_valid,
    input  wire                         l1_1_probe_ack_valid,
    input  wire [63:0]                  l1_0_probe_ack_addr,
    input  wire [63:0]                  l1_1_probe_ack_addr,
    input  wire [2:0]                   l1_0_probe_ack_permissions,
    input  wire [2:0]                   l1_1_probe_ack_permissions,
    input  wire [511:0]                 l1_0_probe_ack_dirty_data,
    input  wire [511:0]                 l1_1_probe_ack_dirty_data,
    
    // TileLink Channel A (requests from L1s) - Keep packed for backward compatibility
    input  wire [1:0]                   a_valid,
    input  wire [5:0]                   a_opcode,  // Packed array of opcodes from each master (2*3)
    input  wire [5:0]                   a_param,   // Packed array of params from each master (2*3)
    input  wire [7:0]                   a_size,    // Packed array of sizes from each master (2*4)
    input  wire [7:0]                   a_source,  // Packed array of source IDs from each master (2*4)
    input  wire [127:0]                 a_address, // Packed array of addresses from each master (2*64)
    input  wire [1023:0]                a_data,    // Packed array of data from each master (2*512)
    input  wire [127:0]                 a_mask,    // Packed array of masks from each master (2*64)
    output wire [1:0]                   a_ready,
    
    // TileLink Channel B (probes to L1s) - Simplified individual signals
    output reg                          b_0_valid,
    output reg                          b_1_valid,
    output reg  [2:0]                   b_0_opcode,
    output reg  [2:0]                   b_1_opcode,
    output reg  [2:0]                   b_0_param,
    output reg  [2:0]                   b_1_param,
    output reg  [3:0]                   b_0_size,
    output reg  [3:0]                   b_1_size,
    output reg  [3:0]                   b_0_source,
    output reg  [3:0]                   b_1_source,
    output reg  [63:0]                  b_0_address,
    output reg  [63:0]                  b_1_address,
    output reg  [511:0]                 b_0_data,
    output reg  [511:0]                 b_1_data,
    output reg  [63:0]                  b_0_mask,
    output reg  [63:0]                  b_1_mask,
    input  wire                         b_0_ready,
    input  wire                         b_1_ready,
    
    // TileLink Channel C (responses from L1s) - Keep packed for backward compatibility
    input  wire [1:0]                   c_valid,
    input  wire [5:0]                   c_opcode,  // Packed array of opcodes from each master (2*3)
    input  wire [5:0]                   c_param,   // Packed array of params from each master (2*3)
    input  wire [7:0]                   c_size,    // Packed array of sizes from each master (2*4)
    input  wire [7:0]                   c_source,  // Packed array of source IDs from each master (2*4)
    input  wire [127:0]                 c_address, // Packed array of addresses from each master (2*64)
    input  wire [1023:0]                c_data,    // Packed array of data from each master (2*512)
    input  wire [1:0]                   c_error,   // Packed array of error flags from each master
    output wire [1:0]                   c_ready,
    
    // TileLink Channel D (responses to L1s) - Simplified individual signals
    output reg                          d_0_valid,
    output reg                          d_1_valid,
    output reg  [2:0]                   d_0_opcode,
    output reg  [2:0]                   d_1_opcode,
    output reg  [2:0]                   d_0_param,
    output reg  [2:0]                   d_1_param,
    output reg  [3:0]                   d_0_size,
    output reg  [3:0]                   d_1_size,
    output reg  [3:0]                   d_0_source,
    output reg  [3:0]                   d_1_source,
    output reg  [3:0]                   d_0_sink,
    output reg  [3:0]                   d_1_sink,
    output reg  [511:0]                 d_0_data,
    output reg  [511:0]                 d_1_data,
    output reg                          d_0_error,
    output reg                          d_1_error,
    input  wire                         d_0_ready,
    input  wire                         d_1_ready,
    
    // TileLink Channel E (acknowledgements from L1s) - Keep packed for simplicity
    input  wire [1:0]                   e_valid,
    input  wire [7:0]                   e_sink,    // Packed array of sink IDs from each master (2*4)
    output wire [1:0]                   e_ready,
    
    // L2 Cache Controller Interface
    output reg                          l2_cmd_valid,
    output reg  [2:0]                   l2_cmd_type,  // 000=Read, 001=Write, 010=Invalidate, 011=WriteBack
    output reg  [63:0]                  l2_cmd_addr,
    output reg  [511:0]                 l2_cmd_data,  // Data for write/write-back commands
    output reg  [3:0]                   l2_cmd_size,
    output reg                          l2_cmd_dirty,  // Indicates if data is dirty (for write-back)
    
    input  wire                         l2_response_valid,
    input  wire [511:0]                 l2_response_data,  // Data from L2 cache for read responses
    input  wire                         l2_response_error   // Error status from L2 cache
);

    // Convert individual signals back to packed arrays for backward compatibility
    wire [1:0] b_valid = {b_1_valid, b_0_valid};
    wire [5:0] b_opcode = {b_1_opcode, b_0_opcode};
    wire [5:0] b_param = {b_1_param, b_0_param};
    wire [7:0] b_size = {b_1_size, b_0_size};
    wire [7:0] b_source = {b_1_source, b_0_source};
    wire [127:0] b_address = {b_1_address, b_0_address};
    wire [1023:0] b_data = {b_1_data, b_0_data};
    wire [127:0] b_mask = {b_1_mask, b_0_mask};
    wire [1:0] b_ready = {b_1_ready, b_0_ready};
    
    wire [1:0] d_valid = {d_1_valid, d_0_valid};
    wire [5:0] d_opcode = {d_1_opcode, d_0_opcode};
    wire [5:0] d_param = {d_1_param, d_0_param};
    wire [7:0] d_size = {d_1_size, d_0_size};
    wire [7:0] d_source = {d_1_source, d_0_source};
    wire [7:0] d_sink = {d_1_sink, d_0_sink};
    wire [1023:0] d_data = {d_1_data, d_0_data};
    wire [1:0] d_error = {d_1_error, d_0_error};
    wire [1:0] d_ready = {d_1_ready, d_0_ready};
    
    // Convert back to packed arrays for probe signals
    wire [1:0] l1_probe_req_valid = {l1_1_probe_req_valid, l1_0_probe_req_valid};
    wire [127:0] l1_probe_req_addr = {l1_1_probe_req_addr, l1_0_probe_req_addr};
    wire [5:0] l1_probe_req_permissions = {l1_1_probe_req_permissions, l1_0_probe_req_permissions};
    
    wire [1:0] l1_probe_ack_valid = {l1_1_probe_ack_valid, l1_0_probe_ack_valid};
    wire [127:0] l1_probe_ack_addr = {l1_1_probe_ack_addr, l1_0_probe_ack_addr};
    wire [5:0] l1_probe_ack_permissions = {l1_1_probe_ack_permissions, l1_0_probe_ack_permissions};
    wire [1023:0] l1_probe_ack_dirty_data = {l1_1_probe_ack_dirty_data, l1_0_probe_ack_dirty_data};

    // Simplified request extraction helper signals
    wire [2:0] a_0_opcode = a_opcode[2:0];
    wire [2:0] a_1_opcode = a_opcode[5:3];
    wire [2:0] a_0_param = a_param[2:0];
    wire [2:0] a_1_param = a_param[5:3];
    wire [3:0] a_0_source = a_source[3:0];
    wire [3:0] a_1_source = a_source[7:4];
    wire [63:0] a_0_address = a_address[63:0];
    wire [63:0] a_1_address = a_address[127:64];
    wire [511:0] a_0_data = a_data[511:0];
    wire [511:0] a_1_data = a_data[1023:512];
    
    wire [2:0] c_0_opcode = c_opcode[2:0];
    wire [2:0] c_1_opcode = c_opcode[5:3];
    wire [2:0] c_0_param = c_param[2:0];
    wire [2:0] c_1_param = c_param[5:3];
    wire [3:0] c_0_source = c_source[3:0];
    wire [3:0] c_1_source = c_source[7:4];
    wire [63:0] c_0_address = c_address[63:0];
    wire [63:0] c_1_address = c_address[127:64];
    wire [511:0] c_0_data = c_data[511:0];
    wire [511:0] c_1_data = c_data[1023:512];
    
    wire [3:0] e_0_sink = e_sink[3:0];
    wire [3:0] e_1_sink = e_sink[7:4];

    // Define internal components and signals
    
    // Request Arbiter for selecting between multiple master requests
    wire                      arb_valid;
    wire [1:0]                arb_channel;   // 0 = Channel A, 1 = Channel C
    wire [1:0]                arb_master_oh; // One-hot encoding of selected master
    wire [0:0]                arb_master_id; // Binary encoding of selected master (log2(2) = 1 bit)
    wire                      arb_busy_unused; // Unused output from arbiter
    wire                      arb_ready;
    wire                      arb_busy;
    
    // Directory interface signals
    reg                       dir_lookup_req;
    reg  [63:0]               dir_lookup_addr;
    wire                      dir_lookup_valid;
    wire [2:0]                dir_lookup_state;
    wire [1:0]                dir_lookup_presence;
    wire [1:0]                dir_lookup_tip_state;
    
    reg                       dir_update_req;
    reg  [63:0]               dir_update_addr;
    reg  [2:0]                dir_update_state;
    reg  [1:0]                dir_update_presence;
    reg  [1:0]                dir_update_tip_state;
    wire                      dir_update_done;
    
    // Sink ID Manager signals
    wire                      sink_id_alloc_req;
    wire                      sink_id_alloc_gnt;
    wire [3:0]                sink_id_alloc_sink_id;
    wire                      sink_id_dealloc_req;
    reg  [3:0]                sink_id_dealloc_sink_id;
    
    // State Machine Definitions
    localparam STATE_IDLE             = 4'd0;  // Idle, waiting for requests
    localparam STATE_DIR_LOOKUP       = 4'd1;  // Looking up address in directory
    localparam STATE_ACQUIRE_PROCESS  = 4'd2;  // Processing an Acquire request
    localparam STATE_PROBE_SEND       = 4'd3;  // Sending Probes to sharers
    localparam STATE_PROBE_WAIT       = 4'd4;  // Waiting for ProbeAcks
    localparam STATE_L2_ACCESS        = 4'd5;  // Accessing L2 cache
    localparam STATE_GRANT_SEND       = 4'd6;  // Sending Grant/GrantData
    localparam STATE_RELEASE_PROCESS  = 4'd7;  // Processing a Release/ReleaseData
    localparam STATE_RELEASEACK_SEND  = 4'd8;  // Sending ReleaseAck
    localparam STATE_GRANTACK_WAIT    = 4'd9;  // Waiting for GrantAck
    localparam STATE_UNCACHED_PROCESS = 4'd10; // Processing uncached request
    
    // Main state machine register
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Pending transaction tracking
    reg [63:0]                 pending_addr;
    reg [0:0]                  pending_master_id;
    reg [2:0]                  pending_opcode;
    reg [2:0]                  pending_param;
    reg [3:0]                  pending_source;
    reg [3:0]                  pending_sink;
    reg [3:0]                  sent_sink_id;      // Sink ID that was actually sent in Grant
    reg                        sink_allocated;    // Flag to prevent double allocation
    reg [511:0]                pending_data;
    
    // Latched directory lookup results
    reg                        dir_result_valid;
    reg [2:0]                  dir_result_state;
    reg [1:0]                  dir_result_presence;
    reg [1:0]                  dir_result_tip_state;
    
    // Probe response tracking
    reg [1:0]                  probe_sent;      // Bit vector of L1s that were probed
    reg [1:0]                  probe_acked;     // Bit vector of L1s that have responded
    
    // L2 response buffering
    reg                        l2_response_buffered;
    reg [511:0]                l2_response_data_buf;
    reg                        l2_response_error_buf;
    
    // Integer variables (no longer needed with simplified logic)
    
    // Simple 2-Master Arbiter instantiation
    simple_arbiter request_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .a_valid_i(a_valid),
        .a_opcode_i(a_opcode),
        .a_ready_o(a_ready),
        .c_valid_i(c_valid),
        .c_opcode_i(c_opcode),
        .c_ready_o(c_ready),
        .arb_valid(arb_valid),
        .arb_channel(arb_channel),
        .arb_master_oh(arb_master_oh),
        .arb_master_id(arb_master_id),
        .arb_ready(arb_ready),
        .arb_busy(arb_busy_unused)  // unused output
    );
    
    // Directory instantiation
    directory directory_inst (
        .clk(clk),
        .rst_n(rst_n),
        .lookup_req(dir_lookup_req),
        .lookup_addr(dir_lookup_addr),
        .lookup_valid(dir_lookup_valid),
        .lookup_state(dir_lookup_state),
        .lookup_presence(dir_lookup_presence),
        .lookup_tip_state(dir_lookup_tip_state),
        .update_req(dir_update_req),
        .update_addr(dir_update_addr),
        .update_state(dir_update_state),
        .update_presence(dir_update_presence),
        .update_tip_state(dir_update_tip_state),
        .update_done(dir_update_done)
    );
    
    // Sink ID Manager instantiation
    sink_id_manager sink_id_mgr (
        .clk(clk),
        .rst(~rst_n),
        .alloc_req(sink_id_alloc_req),
        .alloc_gnt(sink_id_alloc_gnt),
        .alloc_sink_id(sink_id_alloc_sink_id),
        .dealloc_req(sink_id_dealloc_req),
        .dealloc_sink_id(sink_id_dealloc_sink_id)
    );
    
    // Control logic for Sink ID allocation - simplified
    // Only allocate once per GRANT_SEND state entry
    assign sink_id_alloc_req = (state == STATE_GRANT_SEND) && 
                              ((pending_master_id == 0 && !d_0_valid) || (pending_master_id == 1 && !d_1_valid)) && 
                              (l2_response_valid || l2_response_buffered) &&
                              !sink_allocated; // Only if no sink ID has been allocated yet for this transaction
    assign sink_id_dealloc_req = (state == STATE_GRANTACK_WAIT) && 
                               ((pending_master_id == 0 && e_valid[0] && e_0_sink == sent_sink_id) ||
                                (pending_master_id == 1 && e_valid[1] && e_1_sink == sent_sink_id));

    // Simplified probe signal generation for 2 masters
    assign l1_0_probe_req_valid = (state == STATE_PROBE_SEND) && probe_sent[0] && !probe_acked[0];
    assign l1_1_probe_req_valid = (state == STATE_PROBE_SEND) && probe_sent[1] && !probe_acked[1];
    
    assign l1_0_probe_req_addr = l1_0_probe_req_valid ? pending_addr : 64'b0;
    assign l1_1_probe_req_addr = l1_1_probe_req_valid ? pending_addr : 64'b0;
    
    wire [2:0] probe_permissions = (pending_param == PARAM_NtoT || pending_param == PARAM_BtoT) ? PARAM_toN : PARAM_toB;
    assign l1_0_probe_req_permissions = l1_0_probe_req_valid ? probe_permissions : 3'b0;
    assign l1_1_probe_req_permissions = l1_1_probe_req_valid ? probe_permissions : 3'b0;
    
    // Connect to arbiter - ready when we can accept a new request
    // Only ready when in IDLE state to prevent overlapping transactions
    assign arb_ready = (state == STATE_IDLE);
    
    // Grant ready signal on Channel E (always ready to accept GrantAcks)
    assign e_ready = 2'b11;
    
    // Debug state transitions
    reg [3:0] prev_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_state <= STATE_IDLE;
        end else if (prev_state != state) begin
            // $display("[L2 DEBUG] State transition: %d -> %d", prev_state, state);
            prev_state <= state;
        end
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            state <= STATE_IDLE;
            
            // Reset pending transaction tracking
            pending_addr <= 64'b0;
            pending_master_id <= 1'b0;
            pending_opcode <= 3'b000;
            pending_param <= 3'b000;
            pending_source <= 4'b0;
            pending_sink <= 4'b0;
            sent_sink_id <= 4'b0;
            sink_allocated <= 1'b0;
            pending_data <= 512'b0;
            
            // Reset probe tracking
            probe_sent <= 2'b0;
            probe_acked <= 2'b0;
            
            // Reset latched directory results
            dir_result_valid <= 1'b0;
            dir_result_state <= 3'b000;
            dir_result_presence <= 2'b0;
            dir_result_tip_state <= 2'b0;
            
            // Reset L2 response buffering
            l2_response_buffered <= 1'b0;
            l2_response_data_buf <= 512'b0;
            l2_response_error_buf <= 1'b0;
            
            // Probe interfaces are continuous assignments
            
            // Reset directory interface
            dir_lookup_req <= 1'b0;
            dir_lookup_addr <= 64'b0;
            dir_update_req <= 1'b0;
            dir_update_addr <= 64'b0;
            dir_update_state <= 3'b000;
            dir_update_presence <= 2'b0;
            dir_update_tip_state <= 2'b0;
            
            // Reset L2 cache interface
            l2_cmd_valid <= 1'b0;
            l2_cmd_type <= 3'b000;
            l2_cmd_addr <= 64'b0;
            l2_cmd_data <= 512'b0;
            l2_cmd_size <= 4'b0;
            l2_cmd_dirty <= 1'b0;
            
            // Reset TileLink outputs - simplified for individual signals
            b_0_valid <= 1'b0;
            b_1_valid <= 1'b0;
            b_0_opcode <= 3'b0;
            b_1_opcode <= 3'b0;
            b_0_param <= 3'b0;
            b_1_param <= 3'b0;
            b_0_size <= 4'b0;
            b_1_size <= 4'b0;
            b_0_source <= 4'b0;
            b_1_source <= 4'b0;
            b_0_address <= 64'b0;
            b_1_address <= 64'b0;
            b_0_data <= 512'b0;
            b_1_data <= 512'b0;
            b_0_mask <= 64'b0;
            b_1_mask <= 64'b0;
            
            d_0_valid <= 1'b0;
            d_1_valid <= 1'b0;
            d_0_opcode <= 3'b0;
            d_1_opcode <= 3'b0;
            d_0_param <= 3'b0;
            d_1_param <= 3'b0;
            d_0_size <= 4'b0;
            d_1_size <= 4'b0;
            d_0_source <= 4'b0;
            d_1_source <= 4'b0;
            d_0_sink <= 4'b0;
            d_1_sink <= 4'b0;
            d_0_data <= 512'b0;
            d_1_data <= 512'b0;
            d_0_error <= 1'b0;
            d_1_error <= 1'b0;
            
            sink_id_dealloc_sink_id <= 4'b0;
        end
        else begin
            // Default values - clear one-shot signals
            dir_lookup_req <= 1'b0;
            dir_update_req <= 1'b0;
            l2_cmd_valid <= 1'b0;
            b_0_valid <= 1'b0;
            b_1_valid <= 1'b0;
            d_0_valid <= 1'b0;
            d_1_valid <= 1'b0;
            
            // State machine transitions
            state <= next_state;
            
            // Latch directory lookup results when they become valid
            if (dir_lookup_valid) begin
                dir_result_valid <= 1'b1;
                dir_result_state <= dir_lookup_state;
                dir_result_presence <= dir_lookup_presence;
                dir_result_tip_state <= dir_lookup_tip_state;
            end else if (state == STATE_ACQUIRE_PROCESS) begin
                // Clear latched results after processing
                dir_result_valid <= 1'b0;
            end
            
            // Buffer L2 response when it arrives during L2_ACCESS state
            if (state == STATE_L2_ACCESS && l2_response_valid && !l2_response_buffered) begin
                l2_response_buffered <= 1'b1;
                l2_response_data_buf <= l2_response_data;
                l2_response_error_buf <= l2_response_error;
                // $display("[L2 DEBUG] Buffering L2 response: data=%h", l2_response_data[63:0]);
            end
            // Clear buffer when returning to IDLE
            else if (next_state == STATE_IDLE) begin
                l2_response_buffered <= 1'b0;
                pending_sink <= 4'b0; // Reset sink ID for next transaction
                sent_sink_id <= 4'b0; // Reset sent sink ID for next transaction
                sink_allocated <= 1'b0; // Reset allocation flag for next transaction
                // $display("[L2 DEBUG] Clearing L2 response buffer");
            end
            
            // State-specific actions
            case (state)
                STATE_IDLE: begin
                    // When a request arrives via the arbiter, capture it
                    if (arb_valid) begin
                        // Save request details
                        pending_master_id <= arb_master_id;
                        
                        // Simplified channel extraction for 2 masters
                        if (arb_channel == 2'b00) begin // Channel A
                            if (arb_master_id == 0) begin
                                pending_addr <= a_0_address;
                                pending_opcode <= a_0_opcode;
                                pending_param <= a_0_param;
                                pending_source <= a_0_source;
                                pending_data <= a_0_data;
                            end else begin
                                pending_addr <= a_1_address;
                                pending_opcode <= a_1_opcode;
                                pending_param <= a_1_param;
                                pending_source <= a_1_source;
                                pending_data <= a_1_data;
                            end
                        end
                        else begin // Channel C
                            if (arb_master_id == 0) begin
                                pending_addr <= c_0_address;
                                pending_opcode <= c_0_opcode;
                                pending_param <= c_0_param;
                                pending_source <= c_0_source;
                                pending_data <= c_0_data;
                            end else begin
                                pending_addr <= c_1_address;
                                pending_opcode <= c_1_opcode;
                                pending_param <= c_1_param;
                                pending_source <= c_1_source;
                                pending_data <= c_1_data;
                            end
                        end
                    end
                end
                
                STATE_DIR_LOOKUP: begin
                    // Initiate directory lookup
                    dir_lookup_req <= 1'b1;
                    dir_lookup_addr <= pending_addr;
                end
                
                STATE_ACQUIRE_PROCESS: begin
                    // Process Acquire request based on directory state and requested permissions
                    // $display("[L2 DEBUG] ACQUIRE_PROCESS entered: dir_result_valid=%b", dir_result_valid);
                    if (dir_result_valid) begin
                        // Debug output for probe logic
                        // $display("[L2 DEBUG] ACQUIRE_PROCESS: addr=%h, param=%b, dir_state=%b, dir_presence=%b, master_id=%d", 
                        //          pending_addr, pending_param, dir_result_state, dir_result_presence, pending_master_id);
                        
                        // Determine which L1s need to be probed based on requested permissions
                        if (pending_param == PARAM_NtoT || pending_param == PARAM_BtoT) begin
                            // Exclusive access requested - need to invalidate/downgrade all sharers
                            if (dir_result_state == DIR_STATE_SHARED || dir_result_state == DIR_STATE_EXCLUSIVE) begin
                                // There are sharers that need to be probed
                                probe_sent <= dir_result_presence & ~(1 << pending_master_id); // Don't probe requesting L1
                                probe_acked <= 2'b0;
                                // $display("[L2 DEBUG] Setting probe_sent=%b (presence=%b, exclude_master=%b)", 
                                //          dir_result_presence & ~(1 << pending_master_id), dir_result_presence, 1 << pending_master_id);
                            end
                            else begin
                                // No sharers, can proceed directly to L2 access
                                probe_sent <= 2'b0;
                                probe_acked <= 2'b0;
                                // $display("[L2 DEBUG] No probes needed, dir_state=%b", dir_result_state);
                            end
                        end
                        else begin // NtoB - shared access
                            // No probes needed for shared access
                            probe_sent <= 2'b0;
                            probe_acked <= 2'b0;
                            // $display("[L2 DEBUG] Shared access, no probes needed");
                        end
                    end
                end
                
                STATE_PROBE_SEND: begin
                    // Probe sending is now handled by continuous assignments
                end
                
                STATE_PROBE_WAIT: begin
                    // Simplified probe acknowledgment handling for 2 masters
                    // Handle L1_0 probe ack
                    if (l1_0_probe_ack_valid && l1_0_probe_ack_addr == pending_addr && probe_sent[0]) begin
                        probe_acked[0] <= 1'b1;
                        
                        // If probe ack indicates dirty data, write it to L2 cache
                        if (l1_0_probe_ack_permissions == PARAM_TtoN || l1_0_probe_ack_permissions == PARAM_TtoB) begin
                            l2_cmd_valid <= 1'b1;
                            l2_cmd_type <= L2_CMD_WRITE_BACK;
                            l2_cmd_addr <= pending_addr;
                            l2_cmd_data <= l1_0_probe_ack_dirty_data;
                            l2_cmd_size <= L2_ACCESS_SIZE_FIELD[3:0];
                            l2_cmd_dirty <= 1'b1;
                        end
                    end
                    
                    // Handle L1_1 probe ack
                    if (l1_1_probe_ack_valid && l1_1_probe_ack_addr == pending_addr && probe_sent[1]) begin
                        probe_acked[1] <= 1'b1;
                        
                        // If probe ack indicates dirty data, write it to L2 cache
                        if (l1_1_probe_ack_permissions == PARAM_TtoN || l1_1_probe_ack_permissions == PARAM_TtoB) begin
                            l2_cmd_valid <= 1'b1;
                            l2_cmd_type <= L2_CMD_WRITE_BACK;
                            l2_cmd_addr <= pending_addr;
                            l2_cmd_data <= l1_1_probe_ack_dirty_data;
                            l2_cmd_size <= L2_ACCESS_SIZE_FIELD[3:0];
                            l2_cmd_dirty <= 1'b1;
                        end
                    end
                end
                
                STATE_L2_ACCESS: begin
                    // Access L2 cache for the data
                    if (pending_opcode == A_OPCODE_ACQUIRE_BLOCK) begin
                        l2_cmd_valid <= 1'b1;
                        l2_cmd_type <= L2_CMD_READ;
                        l2_cmd_addr <= pending_addr;
                        l2_cmd_data <= 512'b0;
                        l2_cmd_size <= L2_ACCESS_SIZE_FIELD[3:0];
                        l2_cmd_dirty <= 1'b0;
                    end
                end
                
                STATE_GRANT_SEND: begin
                    // Simplified Grant/GrantData sending for 2 masters
                    // $display("[L2 DEBUG] GRANT_SEND: master_id=%d, l2_valid=%b, buffered=%b, sink_gnt=%b, d_0_valid=%b", 
                    //         pending_master_id, l2_response_valid, l2_response_buffered, sink_id_alloc_gnt, d_0_valid);
                    
                    if ((l2_response_valid || l2_response_buffered) && sink_id_alloc_gnt) begin
                        // $display("[L2 DEBUG] Allocating sink_id=%d, storing in pending_sink", sink_id_alloc_sink_id);
                        pending_sink <= sink_id_alloc_sink_id;
                        sink_allocated <= 1'b1; // Mark that allocation has happened
                        
                        if (pending_master_id == 0 && !d_0_valid) begin
                            d_0_valid <= 1'b1;
                            d_0_opcode <= D_OPCODE_GRANT_DATA;
                            d_0_param <= pending_param; // Grant the requested permissions
                            d_0_size <= L2_ACCESS_SIZE_FIELD[3:0];
                            d_0_source <= pending_source;
                            d_0_sink <= sink_id_alloc_sink_id;
                            sent_sink_id <= sink_id_alloc_sink_id; // Store the sink ID we actually sent
                            d_0_data <= l2_response_buffered ? l2_response_data_buf : l2_response_data;
                            d_0_error <= l2_response_buffered ? l2_response_error_buf : l2_response_error;
                            // $display("[L2 DEBUG] Grant sent to L1_0 with sink_id=%d, pending_sink=%d", sink_id_alloc_sink_id, pending_sink);
                        end else if (pending_master_id == 1 && !d_1_valid) begin
                            d_1_valid <= 1'b1;
                            d_1_opcode <= D_OPCODE_GRANT_DATA;
                            d_1_param <= pending_param; // Grant the requested permissions
                            d_1_size <= L2_ACCESS_SIZE_FIELD[3:0];
                            d_1_source <= pending_source;
                            d_1_sink <= sink_id_alloc_sink_id;
                            sent_sink_id <= sink_id_alloc_sink_id; // Store the sink ID we actually sent
                            d_1_data <= l2_response_buffered ? l2_response_data_buf : l2_response_data;
                            d_1_error <= l2_response_buffered ? l2_response_error_buf : l2_response_error;
                            // $display("[L2 DEBUG] Grant sent to L1_1 with sink_id=%d", sink_id_alloc_sink_id);
                        end
                    end
                end
                
                STATE_RELEASE_PROCESS: begin
                    // Process Release/ReleaseData from L1
                    if (pending_opcode == C_OPCODE_RELEASE_DATA) begin
                        // Write the released data to L2 cache
                        l2_cmd_valid <= 1'b1;
                        l2_cmd_type <= L2_CMD_WRITE_BACK;
                        l2_cmd_addr <= pending_addr;
                        l2_cmd_data <= pending_data;
                        l2_cmd_size <= L2_ACCESS_SIZE_FIELD[3:0];
                        l2_cmd_dirty <= 1'b1;
                    end
                    
                    // Update directory to remove this L1 from presence vector
                    dir_update_req <= 1'b1;
                    dir_update_addr <= pending_addr;
                    
                    // Calculate new directory state
                    if (pending_param == PARAM_TtoN || pending_param == PARAM_BtoN) begin
                        // Remove this L1 from presence
                        dir_update_presence <= dir_lookup_presence & ~(1 << pending_master_id);
                        dir_update_tip_state <= dir_lookup_tip_state & ~(1 << pending_master_id);
                        
                        // Determine new global state
                        if ((dir_lookup_presence & ~(1 << pending_master_id)) == 0) begin
                            dir_update_state <= DIR_STATE_INVALID;
                        end
                        else if (|(dir_lookup_tip_state & ~(1 << pending_master_id))) begin
                            dir_update_state <= DIR_STATE_EXCLUSIVE;
                        end
                        else begin
                            dir_update_state <= DIR_STATE_SHARED;
                        end
                    end
                end
                
                STATE_RELEASEACK_SEND: begin
                    // Simplified ReleaseAck sending for 2 masters
                    if (pending_master_id == 0) begin
                        d_0_valid <= 1'b1;
                        d_0_opcode <= D_OPCODE_RELEASE_ACK;
                        d_0_param <= 3'b000;
                        d_0_size <= L2_ACCESS_SIZE_FIELD[3:0];
                        d_0_source <= pending_source;
                        d_0_sink <= 4'b0;
                        d_0_data <= 512'b0;
                        d_0_error <= 1'b0;
                    end else begin
                        d_1_valid <= 1'b1;
                        d_1_opcode <= D_OPCODE_RELEASE_ACK;
                        d_1_param <= 3'b000;
                        d_1_size <= L2_ACCESS_SIZE_FIELD[3:0];
                        d_1_source <= pending_source;
                        d_1_sink <= 4'b0;
                        d_1_data <= 512'b0;
                        d_1_error <= 1'b0;
                    end
                end
                
                STATE_GRANTACK_WAIT: begin
                    // Simplified GrantAck waiting for 2 masters
                    // $display("[L2 DEBUG] GRANTACK_WAIT: pending_master_id=%d, e_valid=%b, e_0_sink=%d, e_1_sink=%d, sent_sink_id=%d", 
                    //          pending_master_id, e_valid, e_0_sink, e_1_sink, sent_sink_id);
                    if ((pending_master_id == 0 && e_valid[0] && e_0_sink == sent_sink_id) ||
                        (pending_master_id == 1 && e_valid[1] && e_1_sink == sent_sink_id)) begin
                        // $display("[L2 DEBUG] GrantAck received! Updating directory and going to IDLE");
                        // Update directory with new state
                        dir_update_req <= 1'b1;
                        dir_update_addr <= pending_addr;
                        dir_update_presence <= dir_lookup_presence | (1 << pending_master_id);
                        
                        if (pending_param == PARAM_NtoT || pending_param == PARAM_BtoT) begin
                            // Exclusive access granted
                            dir_update_tip_state <= (1 << pending_master_id);
                            dir_update_state <= DIR_STATE_EXCLUSIVE;
                        end
                        else begin
                            // Shared access granted
                            dir_update_tip_state <= dir_lookup_tip_state & ~(1 << pending_master_id);
                            dir_update_state <= DIR_STATE_SHARED;
                        end
                        
                        // Deallocate sink ID
                        sink_id_dealloc_sink_id <= sent_sink_id;
                    end
                end
                
                STATE_UNCACHED_PROCESS: begin
                    // Handle uncached Get/Put operations
                    if (pending_opcode == A_OPCODE_GET) begin
                        // Uncached read
                        l2_cmd_valid <= 1'b1;
                        l2_cmd_type <= L2_CMD_READ;
                        l2_cmd_addr <= pending_addr;
                        l2_cmd_data <= 512'b0;
                        l2_cmd_size <= L2_ACCESS_SIZE_FIELD[3:0];
                        l2_cmd_dirty <= 1'b0;
                    end
                    else if (pending_opcode == A_OPCODE_PUT_FULL_DATA) begin
                        // Uncached write
                        l2_cmd_valid <= 1'b1;
                        l2_cmd_type <= L2_CMD_WRITE;
                        l2_cmd_addr <= pending_addr;
                        l2_cmd_data <= pending_data;
                        l2_cmd_size <= L2_ACCESS_SIZE_FIELD[3:0];
                        l2_cmd_dirty <= 1'b1;
                        
                        // Simplified AccessAck sending for 2 masters
                        if (pending_master_id == 0) begin
                            d_0_valid <= 1'b1;
                            d_0_opcode <= D_OPCODE_ACCESS_ACK;
                            d_0_param <= 3'b000;
                            d_0_size <= L2_ACCESS_SIZE_FIELD[3:0];
                            d_0_source <= pending_source;
                            d_0_sink <= 4'b0;
                            d_0_data <= 512'b0;
                            d_0_error <= l2_response_error;
                        end else begin
                            d_1_valid <= 1'b1;
                            d_1_opcode <= D_OPCODE_ACCESS_ACK;
                            d_1_param <= 3'b000;
                            d_1_size <= L2_ACCESS_SIZE_FIELD[3:0];
                            d_1_source <= pending_source;
                            d_1_sink <= 4'b0;
                            d_1_data <= 512'b0;
                            d_1_error <= l2_response_error;
                        end
                    end
                end
                
                default: begin
                    // Invalid state - do nothing
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        // Default: stay in current state
        next_state = state;
        
        case (state)
            STATE_IDLE: begin
                if (arb_valid) begin
                    next_state = STATE_DIR_LOOKUP;
                end
            end
            
            STATE_DIR_LOOKUP: begin
                if (dir_lookup_valid) begin
                    // $display("[L2 DEBUG] DIR_LOOKUP complete: opcode=%b, expected_ACQUIRE=%b", 
                    //          pending_opcode, A_OPCODE_ACQUIRE_BLOCK);
                    // Determine next state based on request type
                    if (pending_opcode == A_OPCODE_ACQUIRE_BLOCK) begin
                        next_state = STATE_ACQUIRE_PROCESS;
                        // $display("[L2 DEBUG] Going to ACQUIRE_PROCESS");
                    end
                    else if (pending_opcode == C_OPCODE_RELEASE || pending_opcode == C_OPCODE_RELEASE_DATA) begin
                        next_state = STATE_RELEASE_PROCESS;
                        // $display("[L2 DEBUG] Going to RELEASE_PROCESS");
                    end
                    else if (pending_opcode == A_OPCODE_GET || pending_opcode == A_OPCODE_PUT_FULL_DATA) begin
                        next_state = STATE_UNCACHED_PROCESS;
                        // $display("[L2 DEBUG] Going to UNCACHED_PROCESS");
                    end
                    else begin
                        next_state = STATE_IDLE; // Unknown opcode
                        // $display("[L2 DEBUG] Unknown opcode, going to IDLE");
                    end
                end
            end
            
            STATE_ACQUIRE_PROCESS: begin
                // Check if probes are needed based on directory state
                if (dir_result_valid && 
                    (pending_param == PARAM_NtoT || pending_param == PARAM_BtoT) &&
                    (dir_result_state == DIR_STATE_SHARED || dir_result_state == DIR_STATE_EXCLUSIVE) &&
                    |(dir_result_presence & ~(1 << pending_master_id))) begin
                    next_state = STATE_PROBE_SEND;
                end
                else begin
                    next_state = STATE_L2_ACCESS;
                end
            end
            
            STATE_PROBE_SEND: begin
                // Check if all required probes have been sent (valid && ready handshake)
                if (probe_sent == 2'b00) begin
                    // No probes needed, go directly to L2 access
                    next_state = STATE_L2_ACCESS;
                end else begin
                    // Stay in PROBE_SEND until all probes are successfully sent
                    next_state = STATE_PROBE_WAIT;
                end
            end
            
            STATE_PROBE_WAIT: begin
                // Check if all probes have been acknowledged
                if ((probe_sent & probe_acked) == probe_sent) begin
                    next_state = STATE_L2_ACCESS;
                end
            end
            
            STATE_L2_ACCESS: begin
                if (l2_response_valid) begin
                    next_state = STATE_GRANT_SEND;
                end
            end
            
            STATE_GRANT_SEND: begin
                // $display("[L2 DEBUG] GRANT_SEND next: master_id=%d", pending_master_id);
                if ((pending_master_id == 0 && d_0_valid && d_0_ready) ||
                    (pending_master_id == 1 && d_1_valid && d_1_ready)) begin
                    next_state = STATE_GRANTACK_WAIT;
                    // $display("[L2 DEBUG] Going to GRANTACK_WAIT");
                end
            end
            
            STATE_RELEASE_PROCESS: begin
                if (dir_update_done) begin
                    next_state = STATE_RELEASEACK_SEND;
                end
            end
            
            STATE_RELEASEACK_SEND: begin
                if ((pending_master_id == 0 && d_0_valid && d_0_ready) ||
                    (pending_master_id == 1 && d_1_valid && d_1_ready)) begin
                    next_state = STATE_IDLE;
                end
            end
            
            STATE_GRANTACK_WAIT: begin
                if ((pending_master_id == 0 && e_valid[0] && e_0_sink == sent_sink_id) ||
                    (pending_master_id == 1 && e_valid[1] && e_1_sink == sent_sink_id)) begin
                    if (dir_update_done) begin
                        next_state = STATE_IDLE;
                    end
                end
            end
            
            STATE_UNCACHED_PROCESS: begin
                if (pending_opcode == A_OPCODE_GET && l2_response_valid) begin
                    // Send AccessAckData for uncached read
                    next_state = STATE_IDLE;
                end
                else if (pending_opcode == A_OPCODE_PUT_FULL_DATA) begin
                    // AccessAck already sent for uncached write
                    next_state = STATE_IDLE;
                end
            end
            
            default: begin
                // Invalid state - return to idle
                next_state = STATE_IDLE;
            end
        endcase
    end
    
endmodule 