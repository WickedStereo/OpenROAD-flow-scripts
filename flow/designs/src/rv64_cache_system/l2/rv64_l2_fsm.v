`timescale 1ns/1ps
`include "params.vh"


module rv64_l2_fsm #(
    parameter CORES = 4,
    parameter WAYS = 16,
    parameter SETS = 256,
    parameter SOURCE_W = 6,
    parameter CID_W = 2
) (
    input wire clk,
    input wire rst_n,

    // TileLink A Channel (Sink)
    input  wire [2:0]   a_opcode,
    input  wire [2:0]   a_param,
    input  wire [SOURCE_W-1:0]   a_source,
    input  wire [63:0]  a_address,
    input  wire         a_valid,
    output reg          a_ready,

    // TileLink B Channel (Source) - Probes
    output reg  [2:0]   b_opcode,
    output reg  [1:0]   b_param,
    output reg  [63:0]  b_address,
    output reg          b_valid,
    input  wire         b_ready,
    output reg  [$clog2(CORES)-1:0] b_dest,

    // TileLink C Channel (Sink) - Release/ProbeAck
    input  wire [2:0]   c_opcode,
    input  wire [2:0]   c_param,
    input  wire [SOURCE_W-1:0]   c_source, // L1 Source ID + Core ID
    input  wire [63:0]  c_address,
    input  wire [63:0]  c_data,
    input  wire         c_valid,
    output reg          c_ready,

    // TileLink D Channel (Source) - Grants
    output reg  [2:0]   d_opcode,
    output reg  [1:0]   d_param,
    output reg  [63:0]  d_data,
    output reg  [SOURCE_W-1:0]   d_source,
    output reg  [1:0]   d_sink,
    output reg          d_valid,
    input  wire         d_ready,

    // Memory Interface (TL-UH)
    // A Channel (Source)
    output reg  [2:0]   mem_a_opcode,
    output reg  [2:0]   mem_a_param,
    output reg  [2:0]   mem_a_size,
    output reg  [3:0]   mem_a_source,
    output reg  [63:0]  mem_a_address,
    output reg  [7:0]   mem_a_mask,
    output reg  [63:0]  mem_a_data,
    output reg          mem_a_valid,
    input  wire         mem_a_ready,

    // D Channel (Sink)
    input  wire [2:0]   mem_d_opcode,
    input  wire [1:0]   mem_d_param,
    input  wire [2:0]   mem_d_size,
    input  wire [3:0]   mem_d_source,
    input  wire [1:0]   mem_d_sink,
    input  wire         mem_d_denied,
    input  wire [63:0]  mem_d_data,
    input  wire         mem_d_corrupt,
    input  wire         mem_d_valid,
    output reg          mem_d_ready,

    // Directory Read Interface
    output reg  [7:0]   dir_rd_set,
    input  wire [WAYS-1:0]          dir_rd_valid,
    input  wire [WAYS*CORES-1:0]    dir_rd_sharers,
    input  wire [WAYS-1:0]          dir_rd_owner_valid,
    input  wire [WAYS*$clog2(CORES)-1:0] dir_rd_owner_id,
    input  wire [WAYS-1:0]          dir_rd_dirty,

    // Directory Write Interface
    output reg          dir_we,
    output reg  [7:0]   dir_wr_set,
    output reg  [3:0]   dir_wr_way,
    output reg          dir_wr_valid,
    output reg  [CORES-1:0] dir_wr_sharers,
    output reg          dir_wr_owner_valid,
    output reg  [$clog2(CORES)-1:0] dir_wr_owner_id,
    output reg          dir_wr_dirty,

    // Tag Array Interface (Read/Write)
    input  wire [WAYS*50-1:0] tag_way_flat,
    output reg          tag_we,
    output reg  [7:0]   tag_set,
    output reg  [3:0]   tag_way,
    output reg  [49:0]  tag_wdata,

    // Data Array Interface (Read/Write)
    output reg  [7:0]   data_set,
    output reg  [3:0]   data_way,
    output reg  [2:0]   data_word_sel, // Added for Burst
    output reg          data_we,
    output reg  [63:0]  data_wdata,
    input  wire [63:0]  data_rdata,

    // MSHR Interface
    output reg          mshr_alloc,
    output reg          mshr_dealloc,
    output reg  [CORES-1:0] mshr_set_probes,
    output reg          mshr_probe_ack,
    output reg  [$clog2(CORES)-1:0] mshr_probe_ack_id,
    input  wire [CORES-1:0] mshr_pending_probes,
    input  wire         mshr_busy
);

    // FSM States
    localparam ST_IDLE       = 4'd0;
    localparam ST_RAM_WAIT   = 4'd1; // Wait for RAM read
    localparam ST_CHECK      = 4'd2; // Check Hit/Miss, Send Probes
    localparam ST_WAIT_ACK   = 4'd3; // Wait for Probe Acks
    localparam ST_GRANT      = 4'd4; // Send Grant
    localparam ST_UPDATE     = 4'd5; // Write Directory
    localparam ST_COMPLETE   = 4'd6; // Done
    localparam ST_EVICT_WAIT = 4'd7; // Wait for Eviction Probes
    localparam ST_MEM_READ   = 4'd8; // Read from Memory (Refill)
    localparam ST_MEM_WRITE  = 4'd9; // Write to Memory (Writeback)
    localparam ST_MEM_RESP   = 4'd10; // Wait for Writeback Ack

    reg [3:0] next_state, state_q;
    reg [2:0] burst_cnt; // Burst Counter for Memory Access
    reg [2:0] probe_data_cnt; // Counter for ProbeAckData beats
    reg mem_req_sent_q; // Flag to track if Memory Request (Get) was sent
    reg [63:0] req_line_addr_q;
    reg [63:0] victim_probe_addr_q;

    // Latched Request
    reg [63:0] req_addr_q;
    reg [63:0] req_data_q; // Added for ReleaseData
    reg [2:0]  req_opcode_q;
    reg [2:0]  req_param_q;
    reg [SOURCE_W-1:0]  req_source_q;

    wire [CID_W-1:0] req_core_id = req_source_q[SOURCE_W-1 -: CID_W];

    // Hit Logic
    wire hit;
    wire [3:0] hit_way;
    wire [CORES-1:0] hit_sharers;
    wire hit_owner_valid;
    wire [$clog2(CORES)-1:0] hit_owner_id;
    wire hit_dirty;
    
    // Latched Hit Info (for ST_WAIT_ACK/ST_UPDATE)
    reg [3:0] latched_hit_way;
    reg       latched_hit;
    reg       processing_release; // Flag to indicate we are handling a Release

    // Tag Comparison
    reg [49:0] req_tag;
    
    always @* begin
        req_tag = req_addr_q[63:14]; // Assuming 64B lines, 256 sets -> 6+8=14 bits offset+index
    end

    rv64_l2_dir_lookup #(
        .CORES(CORES),
        .WAYS(WAYS)
    ) dir_lookup (
        .req_tag(req_tag),
        .dir_rd_valid(dir_rd_valid),
        .dir_rd_sharers(dir_rd_sharers),
        .dir_rd_owner_valid(dir_rd_owner_valid),
        .dir_rd_owner_id(dir_rd_owner_id),
        .dir_rd_dirty(dir_rd_dirty),
        .tag_way_flat(tag_way_flat),
        .hit(hit),
        .hit_way(hit_way),
        .hit_sharers(hit_sharers),
        .hit_owner_valid(hit_owner_valid),
        .hit_owner_id(hit_owner_id),
        .hit_dirty(hit_dirty)
    );
    
    // Latch Hit Info
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_hit_way <= 4'd0;
            latched_hit <= 1'b0;
        end else if (state_q == ST_CHECK) begin
            latched_hit_way <= hit_way;
            latched_hit <= hit;
        end
    end

    // PLRU Instance
    wire [3:0] plru_victim_way;
    reg plru_access_q;
    reg [3:0] plru_used_way_q;
    
    rv64_l2_plru plru (
        .clk(clk),
        .rst_n(rst_n),
        .set(req_addr_q[13:6]),
        .access(plru_access_q),
        .used_way(plru_used_way_q),
        .valid(dir_rd_valid), // Use current valid bits
        .victim(plru_victim_way)
    );

    // Victim Info
    reg [3:0] victim_way_q;
    reg victim_valid_q;
    reg [CORES-1:0] victim_sharers_q;
    reg victim_owner_valid_q;
    reg [$clog2(CORES)-1:0] victim_owner_id_q;
    reg victim_dirty_q;
    reg [49:0] victim_tag_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            victim_way_q <= 4'd0;
            victim_valid_q <= 1'b0;
            victim_sharers_q <= 0;
            victim_owner_valid_q <= 0;
            victim_owner_id_q <= 0;
            victim_dirty_q <= 0;
            victim_tag_q <= 0;
        end else if (state_q == ST_CHECK && !hit) begin
            victim_way_q <= plru_victim_way;
            victim_valid_q <= dir_rd_valid[plru_victim_way];
            victim_sharers_q <= dir_rd_sharers[plru_victim_way*CORES +: CORES];
            victim_owner_valid_q <= dir_rd_owner_valid[plru_victim_way];
            victim_owner_id_q <= dir_rd_owner_id[plru_victim_way*$clog2(CORES) +: $clog2(CORES)];
            victim_dirty_q <= dir_rd_dirty[plru_victim_way];
            victim_tag_q <= tag_way_flat[plru_victim_way*50 +: 50];
        end else if (c_valid && c_opcode == C_PROBE_ACK_DATA && !latched_hit) begin
            victim_dirty_q <= 1'b1;
        end
    end

    // Probe Logic
    wire [CORES-1:0] probes_to_send;
    reg [CORES-1:0] probes_sent_q;
    wire [$clog2(CORES)-1:0] next_probe_target;
    wire                      probe_needed;
    wire [CORES-1:0] probe_mshr_set_probes;
    wire probe_engine_b_launch;
    wire [2:0] probe_engine_b_launch_opcode;
    wire [1:0] probe_engine_b_launch_param;
    wire [63:0] probe_engine_b_launch_address;
    wire [$clog2(CORES)-1:0] probe_engine_b_launch_dest;
    wire [3:0] probe_engine_next_state;

    rv64_l2_probe_planner #(
        .CORES(CORES),
        .WAYS(WAYS)
    ) probe_planner (
        .hit(hit),
        .req_opcode(req_opcode_q),
        .req_param(req_param_q),
        .hit_sharers(hit_sharers),
        .hit_owner_valid(hit_owner_valid),
        .hit_owner_id(hit_owner_id),
        .requester_id(req_core_id),
        .dir_rd_valid(dir_rd_valid),
        .dir_rd_sharers(dir_rd_sharers),
        .dir_rd_owner_valid(dir_rd_owner_valid),
        .dir_rd_owner_id(dir_rd_owner_id),
        .plru_victim_way(plru_victim_way),
        .probes_sent(probes_sent_q),
        .probes_to_send(probes_to_send),
        .next_probe_target(next_probe_target),
        .probe_needed(probe_needed)
    );

    rv64_l2_probe_engine #(
        .CORES(CORES),
        .CID_W($clog2(CORES))
    ) probe_engine (
        .hit(hit),
        .req_opcode(req_opcode_q),
        .req_line_addr(req_line_addr_q),
        .victim_probe_addr(victim_probe_addr_q),
        .probes_to_send(probes_to_send),
        .probes_sent(probes_sent_q),
        .next_probe_target(next_probe_target),
        .probe_needed(probe_needed),
        .b_valid(b_valid),
        .b_ready(b_ready),
        .mshr_set_probes(probe_mshr_set_probes),
        .b_launch(probe_engine_b_launch),
        .b_launch_opcode(probe_engine_b_launch_opcode),
        .b_launch_param(probe_engine_b_launch_param),
        .b_launch_address(probe_engine_b_launch_address),
        .b_launch_dest(probe_engine_b_launch_dest),
        .next_state(probe_engine_next_state)
    );

    wire grant_d_valid;
    wire [2:0] grant_d_opcode;
    wire [1:0] grant_d_param;
    wire [63:0] grant_d_data;
    wire [SOURCE_W-1:0] grant_d_source;
    wire [7:0] grant_data_set;
    wire [3:0] grant_data_way;
    wire [2:0] grant_data_word_sel;
    wire [3:0] grant_tag_way;
    wire grant_drive_data_read;
    wire [3:0] grant_next_state;

    wire update_dir_we;
    wire update_dir_wr_valid;
    wire [CORES-1:0] update_dir_wr_sharers;
    wire update_dir_wr_owner_valid;
    wire [$clog2(CORES)-1:0] update_dir_wr_owner_id;
    wire update_dir_wr_dirty;
    wire update_tag_we;
    wire [3:0] update_next_state;

    rv64_l2_grant_update_engine #(
        .CORES(CORES),
        .SOURCE_W(SOURCE_W),
        .CID_W($clog2(CORES))
    ) grant_update_engine (
        .processing_release(processing_release),
        .req_opcode(req_opcode_q),
        .req_param(req_param_q),
        .req_source(req_source_q),
        .req_addr(req_addr_q),
        .req_core_id(req_core_id),
        .burst_cnt(burst_cnt),
        .d_ready(d_ready),
        .data_rdata(data_rdata),
        .latched_hit(latched_hit),
        .latched_hit_way(latched_hit_way),
        .victim_way(victim_way_q),
        .hit_sharers(hit_sharers),
        .hit_owner_valid(hit_owner_valid),
        .hit_owner_id(hit_owner_id),
        .hit_dirty(hit_dirty),
        .grant_d_valid(grant_d_valid),
        .grant_d_opcode(grant_d_opcode),
        .grant_d_param(grant_d_param),
        .grant_d_data(grant_d_data),
        .grant_d_source(grant_d_source),
        .grant_data_set(grant_data_set),
        .grant_data_way(grant_data_way),
        .grant_data_word_sel(grant_data_word_sel),
        .grant_tag_way(grant_tag_way),
        .grant_drive_data_read(grant_drive_data_read),
        .grant_next_state(grant_next_state),
        .update_dir_we(update_dir_we),
        .update_dir_wr_valid(update_dir_wr_valid),
        .update_dir_wr_sharers(update_dir_wr_sharers),
        .update_dir_wr_owner_valid(update_dir_wr_owner_valid),
        .update_dir_wr_owner_id(update_dir_wr_owner_id),
        .update_dir_wr_dirty(update_dir_wr_dirty),
        .update_tag_we(update_tag_we),
        .update_next_state(update_next_state)
    );



    // FSM Next State Logic (Moved to end)


    // C-Channel Handling
    // We need to arbitrate between FSM (Acquire) and C-Channel (Release/ProbeAck)
    // Priority:
    // 1. ProbeAck (Critical for FSM progress)
    // 2. Release (Important to free resources)
    // 3. Acquire (FSM)
    
    // However, FSM is stateful. C-Channel is transaction based.
    // If FSM is in ST_WAIT_ACK, it is waiting for ProbeAck.
    // ProbeAck comes on C.
    
    // Let's use C-Channel opcodes from params.vh

    reg c_handled;
    reg c_is_probe_ack;
    reg c_is_release;
    reg b_launch;
    reg [2:0] b_launch_opcode;
    reg [1:0] b_launch_param;
    reg [63:0] b_launch_address;
    reg [$clog2(CORES)-1:0] b_launch_dest;
    
    always @* begin
        c_is_probe_ack = (c_opcode == C_PROBE_ACK || c_opcode == C_PROBE_ACK_DATA);
        c_is_release   = (c_opcode == C_RELEASE   || c_opcode == C_RELEASE_DATA);
    end

    always @* begin
        next_state = state_q;
        a_ready = 1'b0;
        b_launch = 1'b0;
        b_launch_opcode = 3'd6; // ProbeBlock
        b_launch_param = 2'd0; // To N
        b_launch_address = req_line_addr_q;
        b_launch_dest = 0;
        d_valid = 1'b0;
        d_opcode = 3'd0;
        d_param = 2'd0;
        d_data = 64'd0;
        d_source = req_source_q;
        d_sink = 2'd0;
        
        dir_rd_set = req_addr_q[13:6];
        dir_we = 1'b0;
        dir_wr_set = req_addr_q[13:6];
        dir_wr_way = (latched_hit) ? latched_hit_way : victim_way_q;
        dir_wr_valid = 1'b0;
        dir_wr_sharers = {CORES{1'b0}};
        dir_wr_owner_valid = 1'b0;
        dir_wr_owner_id = 0;
        dir_wr_dirty = 1'b0;

        tag_we = 1'b0;
        tag_set = req_addr_q[13:6];
        tag_way = (latched_hit) ? latched_hit_way : victim_way_q;
        tag_wdata = req_addr_q[63:14];

        data_set = req_addr_q[13:6];
        data_way = (latched_hit) ? latched_hit_way : victim_way_q;
        data_word_sel = 3'd0;
        data_we = 1'b0;
        data_wdata = 64'd0;

        mshr_alloc = 1'b0;
        mshr_dealloc = 1'b0;
        mshr_set_probes = {CORES{1'b0}};
        mshr_probe_ack = 1'b0;
        mshr_probe_ack_id = 0;
        
        c_ready = 1'b0;
        
        // Memory Interface Defaults
        mem_a_opcode = 3'd0;
        mem_a_param = 3'd0;
        mem_a_size = 3'd6; // 64 Bytes
        mem_a_source = 4'd0;
        mem_a_address = 64'd0;
        mem_a_mask = 8'hFF;
        mem_a_data = 64'd0;
        mem_a_valid = 1'b0;
        mem_d_ready = 1'b0;

        // C-Channel Processing (High Priority for ProbeAck)
        if (c_valid) begin
            if (c_is_probe_ack) begin
                // Always accept ProbeAck
                c_ready = 1'b1;
                // Map Source ID to Core ID. Assuming Source[1:0] is Core ID.
                mshr_probe_ack_id = c_source[SOURCE_W-1 -: CID_W];
                
                if (c_opcode == C_PROBE_ACK_DATA) begin
                    // Write Data
                    data_we = 1'b1;
                    data_way = (latched_hit) ? latched_hit_way : victim_way_q;
                    data_set = req_addr_q[13:6];
                    data_word_sel = probe_data_cnt; 
                    data_wdata = c_data;

                    // Only signal MSHR on last beat
                    if (probe_data_cnt == 3'd7) begin
                        mshr_probe_ack = 1'b1;
                    end else begin
                        mshr_probe_ack = 1'b0;
                    end
                end else begin
                    mshr_probe_ack = 1'b1;
                end
            end else if (c_is_release) begin
                // Handle Release
                // Needs Directory Write access.
                // Only process if FSM is not using Directory Write.
                // FSM uses Dir Write in ST_UPDATE.
                if (state_q != ST_UPDATE && state_q != ST_RAM_WAIT && state_q != ST_CHECK) begin
                    // We can process Release
                    // But we need to Read Directory first to find the way?
                    // Or does Release carry enough info?
                    // Release has Address. We need to lookup Way.
                    // This implies a Read-Modify-Write on Directory.
                    // This is complex to do in one cycle if we don't know the way.
                    // We need a Release FSM?
                    // Or we steal cycles.
                    
                    // For now, let's assume we can't handle Release in one cycle without knowing the way.
                    // We need to:
                    // 1. Read Directory (using c_address)
                    // 2. Find Way
                    // 3. Write Directory (clear sharer/owner)
                    // 4. Write Data (if ReleaseData)
                    // 5. Send ReleaseAck
                    
                    // This requires a state machine.
                    // Since we are single-threaded (blocking), we can only handle Release if FSM is IDLE?
                    // Or we can interrupt?
                    // If FSM is IDLE, we can use the main FSM states?
                    // Let's add ST_RELEASE states.
                end
            end
        end

        case (state_q)
            ST_IDLE: begin
                a_ready = !mshr_busy;
                
                if (c_valid && c_is_release) begin
                    c_ready = 1'b1; // Accept Release
                    next_state = ST_RAM_WAIT;
                end else if (a_valid && !mshr_busy) begin
                    mshr_alloc = 1'b1;
                    next_state = ST_RAM_WAIT;
                end
            end

            ST_RAM_WAIT: begin
                // Just wait for RAM access
                next_state = ST_CHECK;
            end

            ST_CHECK: begin
                if (processing_release) begin
                    // Release Handling
                    if (hit) begin
                        // If ReleaseData, write data
                        if (req_opcode_q == C_RELEASE_DATA) begin
                            data_we = 1'b1;
                            data_way = hit_way;
                            data_set = req_addr_q[13:6];
                            data_word_sel = req_addr_q[5:3]; // Use address offset
                            data_wdata = req_data_q; // Use latched data
                        end
                        next_state = ST_UPDATE;
                    end else begin
                        // Miss on Release? Just Ack.
                        next_state = ST_GRANT; 
                    end
                end else begin
                    mshr_set_probes = probe_mshr_set_probes;
                    b_launch = probe_engine_b_launch;
                    b_launch_opcode = probe_engine_b_launch_opcode;
                    b_launch_param = probe_engine_b_launch_param;
                    b_launch_address = probe_engine_b_launch_address;
                    b_launch_dest = probe_engine_b_launch_dest;
                    next_state = probe_engine_next_state;
                end
            end

            ST_WAIT_ACK: begin
                if (mshr_pending_probes == 0) begin
                    next_state = ST_GRANT;
                end
            end

            ST_EVICT_WAIT: begin
                if (mshr_pending_probes == 0) begin
                    // All probes acked. Victim is now Invalid (in L1s).
                    if (victim_dirty_q) begin
                        next_state = ST_MEM_WRITE;
                    end else begin
                        next_state = ST_MEM_READ;
                    end
                end
            end

            ST_MEM_READ: begin
                // Send Get
                if (!mem_req_sent_q) begin
                    mem_a_valid = 1'b1;
                    mem_a_opcode = 3'd4; // Get
                    mem_a_address = {req_addr_q[63:6], 6'b0}; // Align to line
                end
                
                // Receive Data
                mem_d_ready = 1'b1;
                if (mem_d_valid) begin
                    data_we = 1'b1;
                    data_way = victim_way_q;
                    data_set = req_addr_q[13:6];
                    data_word_sel = burst_cnt;
                    data_wdata = mem_d_data;
                    
                    if (burst_cnt == 3'd7) begin
                        next_state = ST_GRANT;
                    end
                end
            end

            ST_MEM_WRITE: begin
                // Send PutFullData
                mem_a_valid = 1'b1;
                mem_a_opcode = 3'd0; // PutFullData
                mem_a_address = {victim_tag_q, req_addr_q[13:6], 6'b0}; // Victim Address
                mem_a_data = data_rdata;
                
                // Read Data from Array
                data_set = req_addr_q[13:6];
                data_way = victim_way_q;
                tag_way = victim_way_q; // Fix: Ensure way_sel is correct for Read
                data_word_sel = burst_cnt; // Read current word
                
                if (mem_a_ready) begin
                    if (burst_cnt == 3'd7) begin
                        next_state = ST_MEM_RESP;
                    end
                end
            end
            
            ST_MEM_RESP: begin
                mem_d_ready = 1'b1;
                if (mem_d_valid) begin
                    // AccessAck
                    next_state = ST_MEM_READ; // Proceed to refill
                end
            end

            ST_GRANT: begin
                d_valid = grant_d_valid;
                d_opcode = grant_d_opcode;
                d_param = grant_d_param;
                d_source = grant_d_source;
                d_data = grant_d_data;
                if (grant_drive_data_read) begin
                    data_set = grant_data_set;
                    data_way = grant_data_way;
                    tag_way = grant_tag_way;
                    data_word_sel = grant_data_word_sel;
                end
                next_state = grant_next_state;
            end

            ST_UPDATE: begin
                dir_we = update_dir_we;
                dir_wr_valid = update_dir_wr_valid;
                dir_wr_sharers = update_dir_wr_sharers;
                dir_wr_owner_valid = update_dir_wr_owner_valid;
                dir_wr_owner_id = update_dir_wr_owner_id;
                dir_wr_dirty = update_dir_wr_dirty;
                tag_we = update_tag_we;
                next_state = update_next_state;
            end

            ST_COMPLETE: begin
                mshr_dealloc = 1'b1;
                next_state = ST_IDLE;
            end
            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    // FSM Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= ST_IDLE;
            req_addr_q <= 64'd0;
            req_opcode_q <= 3'd0;
            req_param_q <= 3'd0;
            req_source_q <= 6'd0;
            req_line_addr_q <= 64'd0;
            victim_probe_addr_q <= 64'd0;
            probes_sent_q <= {CORES{1'b0}};
            burst_cnt <= 3'd0;
            probe_data_cnt <= 3'd0;
            mem_req_sent_q <= 1'b0;
            plru_access_q <= 1'b0;
            plru_used_way_q <= 4'd0;
            b_valid <= 1'b0;
            b_opcode <= 3'd6;
            b_param <= 2'd0;
            b_address <= 64'd0;
            b_dest <= 0;
        end else begin
            state_q <= next_state;

            if (b_launch) begin
                b_valid <= 1'b1;
                b_opcode <= b_launch_opcode;
                b_param <= b_launch_param;
                b_address <= b_launch_address;
                b_dest <= b_launch_dest;
            end else if (b_valid && b_ready) begin
                b_valid <= 1'b0;
            end

            plru_access_q <= (state_q == ST_UPDATE) && !processing_release;
            if ((state_q == ST_UPDATE) && !processing_release) begin
                plru_used_way_q <= (latched_hit) ? latched_hit_way : victim_way_q;
            end

            // Probe Data Counter Logic
            if (c_valid && c_ready && c_opcode == C_PROBE_ACK_DATA) begin
                probe_data_cnt <= probe_data_cnt + 1;
            end else if (state_q == ST_IDLE) begin
                probe_data_cnt <= 3'd0;
            end

            // Burst Counter Logic
            if (state_q == ST_MEM_READ) begin
                if (mem_d_valid && mem_d_ready) begin
                    burst_cnt <= burst_cnt + 1;
                end
                // Track if Get sent
                if (mem_a_valid && mem_a_ready) begin
                    mem_req_sent_q <= 1'b1;
                end
            end else if (state_q == ST_MEM_WRITE) begin
                if (mem_a_valid && mem_a_ready) begin
                    burst_cnt <= burst_cnt + 1;
                end
            end else if (state_q == ST_GRANT) begin
                if (d_valid && d_ready) begin
                    burst_cnt <= burst_cnt + 1;
                end
            end else begin
                burst_cnt <= 3'd0;
                mem_req_sent_q <= 1'b0;
            end

            // Latch request
            if (state_q == ST_IDLE) begin
                if (c_valid && c_is_release) begin
                    req_addr_q <= c_address;
                    req_data_q <= c_data;
                    req_opcode_q <= c_opcode;
                    req_param_q <= c_param;
                    req_source_q <= c_source;
                    req_line_addr_q <= {c_address[63:6], 6'b0};
                    processing_release <= 1'b1;
                end else if (a_valid && a_ready) begin
                    req_addr_q <= a_address;
                    req_opcode_q <= a_opcode;
                    req_param_q <= a_param;
                    req_source_q <= a_source;
                    req_line_addr_q <= {a_address[63:6], 6'b0};
                    processing_release <= 1'b0;
                end
            end

            if (state_q == ST_CHECK && !hit) begin
                victim_probe_addr_q <= {tag_way_flat[plru_victim_way*50 +: 50], req_addr_q[13:6], 6'b0};
            end

            // Reset probes sent mask when starting check
            if (state_q == ST_RAM_WAIT) begin
                probes_sent_q <= {CORES{1'b0}};
            end else if (state_q == ST_CHECK && b_valid && b_ready) begin
                 probes_sent_q[next_probe_target] <= 1'b1;
            end
        end
    end

endmodule
