// =============================================================================
// Project: TileLink Inclusive Directory Coherence (TIDC) System
// Module: L1 TileLink Adapter
// Description: Translates L1 Cache Controller requests into TileLink messages
//              and processes responses/probes from the L2 TileLink Adapter
// =============================================================================

// Include shared parameter definitions
`include "tidc_params.v"

module l1_tilelink_adapter (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // ID for this adapter (0-3 for the four L1 caches)
    input  wire [1:0]                   l1_id,
    
    // L1 Cache Controller Interface - requests from L1
    input  wire                         l1_request_valid,
    input  wire [63:0]                  l1_request_addr,
    input  wire [2:0]                   l1_request_type,  // 000=ReadMiss, 001=WriteMiss, 010=WriteBack
    input  wire [511:0]                 l1_request_data,  // Data for write-back requests
    input  wire [2:0]                   l1_request_permissions, // NtoB, NtoT, BtoT
    output wire                         l1_request_ready,
    
    // L1 Cache Controller Interface - data to L1
    output reg                          data_to_l1_valid,
    output reg  [511:0]                 data_to_l1_data,
    output reg                          data_to_l1_error,
    
    // L1 Cache Controller Interface - probe requests to L1 (INPUTS - L1 receives probes)
    input  wire                         probe_req_to_l1_valid,
    input  wire [63:0]                  probe_req_to_l1_addr,
    input  wire [2:0]                   probe_req_to_l1_permissions, // toN, toB, toT
    
    // L1 Cache Controller Interface - probe acknowledgements from L1
    input  wire                         probe_ack_from_l1_valid,
    input  wire [63:0]                  probe_ack_from_l1_addr,
    input  wire [2:0]                   probe_ack_from_l1_permissions, // TtoT, TtoB, TtoN, BtoB, BtoN, NtoN
    input  wire [511:0]                 probe_ack_from_l1_dirty_data,  // Dirty data if being written back
    
    // TileLink Channel A (requests to L2)
    output reg                          a_valid,
    output reg  [2:0]                   a_opcode,
    output reg  [2:0]                   a_param,
    output reg  [3:0]                   a_size,
    output reg  [3:0]                   a_source,
    output reg  [63:0]                  a_address,
    output reg  [511:0]                 a_data,
    output reg  [63:0]                  a_mask,
    input  wire                         a_ready,
    
    // TileLink Channel B (probes from L2)
    input  wire                         b_valid,
    input  wire [2:0]                   b_opcode,
    input  wire [2:0]                   b_param,
    input  wire [3:0]                   b_size,
    input  wire [3:0]                   b_source,
    input  wire [63:0]                  b_address,
    input  wire [511:0]                 b_data,
    input  wire [63:0]                  b_mask,
    output reg                          b_ready,
    
    // TileLink Channel C (responses to L2)
    output reg                          c_valid,
    output reg  [2:0]                   c_opcode,
    output reg  [2:0]                   c_param,
    output reg  [3:0]                   c_size,
    output reg  [3:0]                   c_source,
    output reg  [63:0]                  c_address,
    output reg  [511:0]                 c_data,
    output reg                          c_error,
    input  wire                         c_ready,
    
    // TileLink Channel D (responses from L2)
    input  wire                         d_valid,
    input  wire [2:0]                   d_opcode,
    input  wire [2:0]                   d_param,
    input  wire [3:0]                   d_size,
    input  wire [3:0]                   d_source,
    input  wire [3:0]                   d_sink,
    input  wire [511:0]                 d_data,
    input  wire                         d_error,
    output reg                          d_ready,
    
    // TileLink Channel E (acknowledgements to L2)
    output reg                          e_valid,
    output reg  [3:0]                   e_sink,
    input  wire                         e_ready
);

    // State definitions for the main state machine
    localparam STATE_IDLE                = 4'd0;  // Idle state, waiting for requests
    localparam STATE_ACQUIRE_SEND        = 4'd1;  // Sending Acquire on A channel
    localparam STATE_ACQUIRE_WAIT        = 4'd2;  // Waiting for Grant/GrantData on D channel
    localparam STATE_GRANT_ACK_SEND      = 4'd3;  // Sending GrantAck on E channel
    localparam STATE_RELEASE_SEND        = 4'd4;  // Sending Release on C channel
    localparam STATE_RELEASE_WAIT        = 4'd5;  // Waiting for ReleaseAck on D channel
    localparam STATE_PROBE_PROCESS       = 4'd6;  // Processing probe from L2
    localparam STATE_PROBE_WAIT          = 4'd7;  // Waiting for probe response from L1
    localparam STATE_PROBE_ACK_SEND      = 4'd8;  // Sending ProbeAck on C channel
    localparam STATE_UNCACHED_REQ_SEND   = 4'd9;  // Sending uncached request (Get/Put) on A channel
    localparam STATE_UNCACHED_RSP_WAIT   = 4'd10; // Waiting for uncached response
    
    // Main state machine registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Pending transaction storage
    reg [63:0] pending_addr;
    reg [2:0] pending_req_type;
    reg [2:0] pending_permissions;
    reg [511:0] pending_data;
    reg pending_has_data;
    
    // Probe tracking
    reg [63:0] probe_addr;
    reg [2:0] probe_param;
    reg [3:0] probe_source;
    
    // Grant tracking
    reg [3:0] grant_sink;
    
    // Source ID management signals
    wire alloc_source_id_req;
    wire alloc_source_id_gnt;
    wire [3:0] alloc_source_id;
    wire dealloc_source_id_req;
    reg [3:0] dealloc_source_id;
    
    // Instantiate the Source ID Manager
    source_id_manager source_id_mgr (
        .clk(clk),
        .rst(~rst_n),
        .alloc_req(alloc_source_id_req),
        .alloc_gnt(alloc_source_id_gnt),
        .alloc_source_id(alloc_source_id),
        .dealloc_req(dealloc_source_id_req),
        .dealloc_source_id(dealloc_source_id)
    );
    
    // Pending source IDs (for tracking multiple outstanding transactions)
    reg [3:0] pending_source_id;
    
    // Simplified source ID allocation logic
    assign alloc_source_id_req = (state == STATE_IDLE) && l1_request_valid;
    
    assign dealloc_source_id_req = (state == STATE_ACQUIRE_WAIT && d_valid && 
                                   (d_opcode == D_OPCODE_GRANT || d_opcode == D_OPCODE_GRANT_DATA) && 
                                    d_source == pending_source_id) ||
                                   (state == STATE_RELEASE_WAIT && d_valid && 
                                    d_opcode == D_OPCODE_RELEASE_ACK && d_source == pending_source_id) ||
                                   (state == STATE_UNCACHED_RSP_WAIT && d_valid && 
                                    (d_opcode == D_OPCODE_ACCESS_ACK || d_opcode == D_OPCODE_ACCESS_ACK_DATA) && 
                                     d_source == pending_source_id);
    
    // Simplified ready signal - ready when idle and source ID available
    assign l1_request_ready = (state == STATE_IDLE) && alloc_source_id_gnt;
    
    // Cache line size calculation for TileLink size field (log2 of bytes)
    localparam CACHE_LINE_SIZE = CACHE_LINE_SIZE_FIELD;  // $clog2(64) = 6
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= STATE_IDLE;
            pending_addr <= 64'b0;
            pending_req_type <= 3'b000;
            pending_permissions <= 3'b000;
            pending_data <= 512'b0;
            pending_has_data <= 1'b0;
            pending_source_id <= 4'b0;
            
            probe_addr <= 64'b0;
            probe_param <= 3'b000;
            probe_source <= 4'b0;
            
            grant_sink <= 4'b0;
            
            dealloc_source_id <= 4'b0;
            
            // Reset outputs
            data_to_l1_valid <= 1'b0;
            data_to_l1_data <= 512'b0;
            data_to_l1_error <= 1'b0;
            
            // Reset TileLink A channel outputs
            a_valid <= 1'b0;
            a_opcode <= 3'b000;
            a_param <= 3'b000;
            a_size <= 4'b0;
            a_source <= 4'b0;
            a_address <= 64'b0;
            a_data <= 512'b0;
            a_mask <= 64'b0;
            
            // Reset TileLink B channel outputs
            b_ready <= 1'b1;  // Always ready to receive probes
            
            // Reset TileLink C channel outputs
            c_valid <= 1'b0;
            c_opcode <= 3'b000;
            c_param <= 3'b000;
            c_size <= 4'b0;
            c_source <= 4'b0;
            c_address <= 64'b0;
            c_data <= 512'b0;
            c_error <= 1'b0;
            
            // Reset TileLink D channel outputs
            d_ready <= 1'b1;  // Always ready to receive responses
            
            // Reset TileLink E channel outputs
            e_valid <= 1'b0;
            e_sink <= 4'b0;
        end
        else begin
            // Update state
            state <= next_state;
            
            // Default signal values
            a_valid <= 1'b0;
            c_valid <= 1'b0;
            e_valid <= 1'b0;
            
            data_to_l1_valid <= 1'b0;
            // Note: probe_req_to_l1_valid is now an input, not driven here
            
            // Always ready to receive responses on D channel
            d_ready <= 1'b1;
            // Always ready to receive probes on B channel (except during an active probe)
            b_ready <= (state != STATE_PROBE_WAIT && state != STATE_PROBE_ACK_SEND);
            
            // Transaction processing based on state
            case (state)
                STATE_IDLE: begin
                    // If we have a valid request from L1 and handshake completes
                    if (l1_request_valid && l1_request_ready) begin
                        // Save the request details
                        pending_addr <= l1_request_addr;
                        pending_req_type <= l1_request_type;
                        pending_permissions <= l1_request_permissions;
                        pending_data <= l1_request_data;
                        pending_source_id <= alloc_source_id;  // Use directly from manager
                        
                        // Set data flag based on request type
                        pending_has_data <= (l1_request_type == L1_REQ_WRITE_BACK);
                        
                        // Prepare deallocation source ID for later use
                        dealloc_source_id <= alloc_source_id;
                    end
                end
                
                STATE_ACQUIRE_SEND: begin
                    // Send an Acquire message on Channel A
                    a_valid <= 1'b1;
                    a_opcode <= A_OPCODE_ACQUIRE_BLOCK;
                    a_param <= pending_permissions; // NtoB, NtoT, BtoT
                    a_size <= CACHE_LINE_SIZE[3:0]; // Size of a cache line
                    a_source <= pending_source_id;  // Use stored source ID for consistency
                    a_address <= pending_addr;
                    a_data <= 512'b0;  // No data for Acquire
                    a_mask <= 64'hFFFFFFFFFFFFFFFF;    // Full mask
                    
                    // If the message was accepted by the network
                    if (a_ready) begin
                        // Nothing to do here, next_state logic handles the transition
                    end
                end
                
                STATE_ACQUIRE_WAIT: begin
                    // Wait for Grant/GrantData on Channel D
                    if (d_valid && (d_opcode == D_OPCODE_GRANT || d_opcode == D_OPCODE_GRANT_DATA) && 
                        d_source == pending_source_id) begin
                        
                        // $display("[L1 DEBUG] Grant received: d_sink=%d, d_source=%d, pending_source=%d", d_sink, d_source, pending_source_id);
                        // Save the sink ID for the GrantAck
                        grant_sink <= d_sink;
                        
                        // If this was a GrantData, forward the data to the L1 cache
                        if (d_opcode == D_OPCODE_GRANT_DATA) begin
                            data_to_l1_valid <= 1'b1;
                            data_to_l1_data <= d_data;  // Full 512-bit data
                            data_to_l1_error <= d_error;
                        end
                        
                        // Prepare for source ID deallocation
                        dealloc_source_id <= d_source;
                    end
                end
                
                STATE_GRANT_ACK_SEND: begin
                    // Send GrantAck on Channel E
                    // $display("[L1 DEBUG] Sending GrantAck: e_valid=1, e_sink=%d, e_ready=%b", grant_sink, e_ready);
                    e_valid <= 1'b1;
                    e_sink <= grant_sink;
                    
                    // If the message was accepted by the network
                    if (e_ready) begin
                        // $display("[L1 DEBUG] GrantAck accepted!");
                        // Nothing to do here, next_state logic handles the transition
                    end
                end
                
                STATE_RELEASE_SEND: begin
                    // Send Release/ReleaseData on Channel C
                    c_valid <= 1'b1;
                    c_opcode <= pending_has_data ? C_OPCODE_RELEASE_DATA : C_OPCODE_RELEASE;
                    c_param <= pending_permissions; // TtoN, BtoN
                    c_size <= CACHE_LINE_SIZE[3:0]; // Size of a cache line
                    c_source <= pending_source_id;  // Use stored source ID for consistency
                    c_address <= pending_addr;
                    c_data <= pending_has_data ? pending_data : 512'b0;
                    c_error <= 1'b0;
                    
                    // If the message was accepted by the network
                    if (c_ready) begin
                        // Nothing to do here, next_state logic handles the transition
                    end
                end
                
                STATE_RELEASE_WAIT: begin
                    // Wait for ReleaseAck on Channel D
                    if (d_valid && d_opcode == D_OPCODE_RELEASE_ACK && d_source == pending_source_id) begin
                        // Prepare for source ID deallocation
                        dealloc_source_id <= d_source;
                    end
                end
                
                STATE_PROBE_PROCESS: begin
                    // Process a probe from L2
                    if (b_valid && b_opcode == B_OPCODE_PROBE_BLOCK) begin
                        // Save probe details for response
                        probe_addr <= b_address;
                        probe_param <= b_param;
                        probe_source <= b_source;
                        
                        // The probe request is now forwarded directly to L1 via external connections
                        // No need to drive probe_req_to_l1_* signals here
                    end
                end
                
                STATE_PROBE_WAIT: begin
                    // Wait for acknowledgment from L1 cache
                    // This is handled in the next_state logic
                end
                
                STATE_PROBE_ACK_SEND: begin
                    // If we have a valid probe acknowledgment from L1
                    if (probe_ack_from_l1_valid) begin
                        // Generate ProbeAck or ProbeAckData based on permissions and dirty flag
                        c_valid <= 1'b1;
                        
                        // Determine if we're sending data back (Tip downgrade with dirty data)
                        if (probe_ack_from_l1_permissions == PARAM_TtoB || 
                            probe_ack_from_l1_permissions == PARAM_TtoN) begin
                            // We're sending data back
                            c_opcode <= C_OPCODE_PROBE_ACK_DATA;
                            c_data <= probe_ack_from_l1_dirty_data;
                        end
                        else begin
                            // No data
                            c_opcode <= C_OPCODE_PROBE_ACK;
                            c_data <= 512'b0;
                        end
                        
                        c_param <= probe_ack_from_l1_permissions; // TtoT, TtoB, TtoN, BtoB, BtoN, NtoN
                        c_size <= CACHE_LINE_SIZE[3:0]; // Size of a cache line
                        c_source <= probe_source;
                        c_address <= probe_ack_from_l1_addr;
                        c_error <= 1'b0;
                        
                        // If the message was accepted by the network
                        if (c_ready) begin
                            // Nothing to do here, next_state logic handles the transition
                        end
                    end
                end
                
                STATE_UNCACHED_REQ_SEND: begin
                    // Send an uncached request (Get/Put) on Channel A
                    a_valid <= 1'b1;
                    
                    // Determine opcode based on request type
                    if (pending_req_type == L1_REQ_UNCACHED_READ) begin
                        a_opcode <= A_OPCODE_GET;
                                            a_data <= 512'b0;   
                    a_mask <= 64'hFFFFFFFFFFFFFFFF;  // Full mask for Get
                    end
                    else begin // UNCACHED_WRITE
                        a_opcode <= A_OPCODE_PUT_FULL_DATA;
                        a_data <= pending_data;  // Full 512-bit data
                        a_mask <= 64'hFFFFFFFFFFFFFFFF;  // Full mask for PutFullData
                    end
                    
                    a_param <= 3'b000;  // No special parameters for uncached requests
                    a_size <= CACHE_LINE_SIZE[3:0]; // Size of a cache line
                    a_source <= pending_source_id;  // Use stored source ID for consistency
                    a_address <= pending_addr;
                    
                    // If the message was accepted by the network
                    if (a_ready) begin
                        // Nothing to do here, next_state logic handles the transition
                    end
                end
                
                STATE_UNCACHED_RSP_WAIT: begin
                    // Wait for AccessAck/AccessAckData on Channel D
                    if (d_valid && (d_opcode == D_OPCODE_ACCESS_ACK || d_opcode == D_OPCODE_ACCESS_ACK_DATA) && 
                        d_source == pending_source_id) begin
                        
                        // If this was a read (AccessAckData), forward the data to the L1 cache
                        if (d_opcode == D_OPCODE_ACCESS_ACK_DATA) begin
                            data_to_l1_valid <= 1'b1;
                            data_to_l1_data <= d_data;  // Full 512-bit data
                            data_to_l1_error <= d_error;
                        end
                        
                        // Prepare for source ID deallocation
                        dealloc_source_id <= d_source;
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
                // FIX: Use l1_request_ready instead of can_process_l1_request to break circular dependency
                if (l1_request_valid && l1_request_ready) begin
                    case (l1_request_type)
                        L1_REQ_READ_MISS, L1_REQ_WRITE_MISS: begin
                            next_state = STATE_ACQUIRE_SEND;
                        end
                        L1_REQ_WRITE_BACK: begin
                            next_state = STATE_RELEASE_SEND;
                        end
                        L1_REQ_UNCACHED_READ, L1_REQ_UNCACHED_WRITE: begin
                            next_state = STATE_UNCACHED_REQ_SEND;
                        end
                        default: begin
                            next_state = STATE_IDLE;
                        end
                    endcase
                end
                else if (b_valid && b_opcode == B_OPCODE_PROBE_BLOCK) begin
                    next_state = STATE_PROBE_PROCESS;
                end
            end
            
            STATE_ACQUIRE_SEND: begin
                if (a_valid && a_ready) begin
                    next_state = STATE_ACQUIRE_WAIT;
                end
            end
            
            STATE_ACQUIRE_WAIT: begin
                if (d_valid && (d_opcode == D_OPCODE_GRANT || d_opcode == D_OPCODE_GRANT_DATA) && 
                    d_source == pending_source_id) begin
                    next_state = STATE_GRANT_ACK_SEND;
                end
            end
            
            STATE_GRANT_ACK_SEND: begin
                if (e_valid && e_ready) begin
                    next_state = STATE_IDLE;
                end
            end
            
            STATE_RELEASE_SEND: begin
                if (c_valid && c_ready) begin
                    next_state = STATE_RELEASE_WAIT;
                end
            end
            
            STATE_RELEASE_WAIT: begin
                if (d_valid && d_opcode == D_OPCODE_RELEASE_ACK && d_source == pending_source_id) begin
                    next_state = STATE_IDLE;
                end
            end
            
            STATE_PROBE_PROCESS: begin
                if (probe_req_to_l1_valid) begin
                    next_state = STATE_PROBE_WAIT;
                end
            end
            
            STATE_PROBE_WAIT: begin
                if (probe_ack_from_l1_valid) begin
                    next_state = STATE_PROBE_ACK_SEND;
                end
            end
            
            STATE_PROBE_ACK_SEND: begin
                if (c_valid && c_ready) begin
                    next_state = STATE_IDLE;
                end
            end
            
            STATE_UNCACHED_REQ_SEND: begin
                if (a_valid && a_ready) begin
                    next_state = STATE_UNCACHED_RSP_WAIT;
                end
            end
            
            STATE_UNCACHED_RSP_WAIT: begin
                if (d_valid && (d_opcode == D_OPCODE_ACCESS_ACK || d_opcode == D_OPCODE_ACCESS_ACK_DATA) && 
                    d_source == pending_source_id) begin
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