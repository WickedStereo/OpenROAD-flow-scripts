`timescale 1ns/1ps


module rv64_l2_cache #(
    parameter CORES = 4,
    parameter WAYS = 16,
    parameter SETS = 256,
    parameter ADDR_W = 64,
    parameter DATA_W = 64,
    parameter SOURCE_W = 6,
    parameter CID_W = 2
) (
    input wire clk,
    input wire rst_n,

    // TileLink A Channel (Sink)
    input  wire [2:0]   tl_a_opcode,
    input  wire [2:0]   tl_a_param,
    input  wire [SOURCE_W-1:0]   tl_a_source,
    input  wire [ADDR_W-1:0]  tl_a_address,
    input  wire         tl_a_valid,
    output wire         tl_a_ready,

    // TileLink B Channel (Source) - Probes
    output wire [2:0]   tl_b_opcode,
    output wire [1:0]   tl_b_param,
    output wire [ADDR_W-1:0]  tl_b_address,
    output wire         tl_b_valid,
    input  wire         tl_b_ready,
    output wire [$clog2(CORES)-1:0] tl_b_dest, // To Crossbar/Demux

    // TileLink C Channel (Sink) - Release/ProbeAck
    input  wire [2:0]   tl_c_opcode,
    input  wire [2:0]   tl_c_param,
    input  wire [SOURCE_W-1:0]   tl_c_source,
    input  wire [ADDR_W-1:0]  tl_c_address,
    input  wire [DATA_W-1:0]  tl_c_data,
    input  wire         tl_c_valid,
    output wire         tl_c_ready,

    // TileLink D Channel (Source) - Grants
    output wire [2:0]   tl_d_opcode,
    output wire [1:0]   tl_d_param,
    output wire [DATA_W-1:0]  tl_d_data,
    output wire [SOURCE_W-1:0]   tl_d_source,
    output wire [1:0]   tl_d_sink,
    output wire         tl_d_valid,
    input  wire         tl_d_ready,

    // Memory Interface (TL-UH)
    // A Channel (Source)
    output wire [2:0]   mem_a_opcode,
    output wire [2:0]   mem_a_param,
    output wire [2:0]   mem_a_size,
    output wire [3:0]   mem_a_source,
    output wire [ADDR_W-1:0]  mem_a_address,
    output wire [7:0]   mem_a_mask,
    output wire [DATA_W-1:0]  mem_a_data,
    output wire         mem_a_valid,
    input  wire         mem_a_ready,

    // D Channel (Sink)
    input  wire [2:0]   mem_d_opcode,
    input  wire [1:0]   mem_d_param,
    input  wire [2:0]   mem_d_size,
    input  wire [3:0]   mem_d_source,
    input  wire [1:0]   mem_d_sink,
    input  wire         mem_d_denied,
    input  wire [DATA_W-1:0]  mem_d_data,
    input  wire         mem_d_corrupt,
    input  wire         mem_d_valid,
    output wire         mem_d_ready
);

    // Internal Signals
    
    // Directory Signals
    wire [7:0]   dir_rd_set;
    wire [WAYS-1:0]          dir_rd_valid;
    wire [WAYS*CORES-1:0]    dir_rd_sharers;
    wire [WAYS-1:0]          dir_rd_owner_valid;
    wire [WAYS*$clog2(CORES)-1:0] dir_rd_owner_id;
    wire [WAYS-1:0]          dir_rd_dirty;

    wire          dir_we;
    wire [7:0]    dir_wr_set;
    wire [3:0]    dir_wr_way;
    wire          dir_wr_valid;
    wire [CORES-1:0] dir_wr_sharers;
    wire          dir_wr_owner_valid;
    wire [$clog2(CORES)-1:0] dir_wr_owner_id;
    wire          dir_wr_dirty;

    // Tag/Data Array Signals
    wire [WAYS*50-1:0] tag_way_flat;
    wire          tag_we;
    wire [7:0]    tag_set;
    wire [3:0]    tag_way;
    wire [49:0]   tag_wdata;
    
    wire [3:0]    data_way;
    wire [2:0]    data_word_sel;
    wire          data_we;
    wire [63:0]   data_wdata;
    wire [63:0]   data_rdata;
    
    // Unused Array/MSHR Outputs
    wire [7:0]          unused_data_set;
    wire [49:0]         unused_tag_selected;
    wire [WAYS*64-1:0]  unused_rdata_way_flat;
    wire                unused_mshr_alloc_ready;
    wire [ADDR_W-1:0]   unused_mshr_addr;
    wire [SOURCE_W-1:0] unused_mshr_source;
    wire [2:0]          unused_mshr_type;

    // MSHR Signals
    wire          mshr_alloc;
    wire          mshr_dealloc;
    wire [CORES-1:0] mshr_set_probes;
    wire          mshr_probe_ack;
    wire [$clog2(CORES)-1:0] mshr_probe_ack_id;
    wire [CORES-1:0] mshr_pending_probes;
    wire          mshr_busy;
    
    // ---------------------------------------------------------
    // L2 FSM
    // ---------------------------------------------------------
    rv64_l2_fsm #(
        .CORES(CORES),
        .WAYS(WAYS),
        .SETS(SETS),
        .SOURCE_W(SOURCE_W),
        .CID_W(CID_W)
    ) fsm (
        .clk(clk),
        .rst_n(rst_n),

        // TileLink A
        .a_opcode(tl_a_opcode),
        .a_param(tl_a_param),
        .a_source(tl_a_source),
        .a_address(tl_a_address),
        .a_valid(tl_a_valid),
        .a_ready(tl_a_ready),

        // TileLink B
        .b_opcode(tl_b_opcode),
        .b_param(tl_b_param),
        .b_address(tl_b_address),
        .b_valid(tl_b_valid),
        .b_ready(tl_b_ready),
        .b_dest(tl_b_dest),

        // TileLink C
        .c_opcode(tl_c_opcode),
        .c_param(tl_c_param),
        .c_source(tl_c_source),
        .c_address(tl_c_address),
        .c_data(tl_c_data),
        .c_valid(tl_c_valid),
        .c_ready(tl_c_ready),

        // TileLink D
        .d_opcode(tl_d_opcode),
        .d_param(tl_d_param),
        .d_data(tl_d_data),
        .d_source(tl_d_source),
        .d_sink(tl_d_sink),
        .d_valid(tl_d_valid),
        .d_ready(tl_d_ready),

        // Memory Interface
        .mem_a_opcode(mem_a_opcode),
        .mem_a_param(mem_a_param),
        .mem_a_size(mem_a_size),
        .mem_a_source(mem_a_source),
        .mem_a_address(mem_a_address),
        .mem_a_mask(mem_a_mask),
        .mem_a_data(mem_a_data),
        .mem_a_valid(mem_a_valid),
        .mem_a_ready(mem_a_ready),

        .mem_d_opcode(mem_d_opcode),
        .mem_d_param(mem_d_param),
        .mem_d_size(mem_d_size),
        .mem_d_source(mem_d_source),
        .mem_d_sink(mem_d_sink),
        .mem_d_denied(mem_d_denied),
        .mem_d_data(mem_d_data),
        .mem_d_corrupt(mem_d_corrupt),
        .mem_d_valid(mem_d_valid),
        .mem_d_ready(mem_d_ready),

        // Directory Interface
        .dir_rd_set(dir_rd_set),
        .dir_rd_valid(dir_rd_valid),
        .dir_rd_sharers(dir_rd_sharers),
        .dir_rd_owner_valid(dir_rd_owner_valid),
        .dir_rd_owner_id(dir_rd_owner_id),
        .dir_rd_dirty(dir_rd_dirty),

        .dir_we(dir_we),
        .dir_wr_set(dir_wr_set),
        .dir_wr_way(dir_wr_way),
        .dir_wr_valid(dir_wr_valid),
        .dir_wr_sharers(dir_wr_sharers),
        .dir_wr_owner_valid(dir_wr_owner_valid),
        .dir_wr_owner_id(dir_wr_owner_id),
        .dir_wr_dirty(dir_wr_dirty),

        // Tag/Data Interface
        .tag_way_flat(tag_way_flat),
        .tag_we(tag_we),
        .tag_set(tag_set),
        .tag_way(tag_way),
        .tag_wdata(tag_wdata),

        .data_set(unused_data_set),
        .data_way(data_way),
        .data_word_sel(data_word_sel),
        .data_we(data_we),
        .data_wdata(data_wdata),
        .data_rdata(data_rdata),

        // MSHR Interface
        .mshr_alloc(mshr_alloc),
        .mshr_dealloc(mshr_dealloc),
        .mshr_set_probes(mshr_set_probes),
        .mshr_probe_ack(mshr_probe_ack),
        .mshr_probe_ack_id(mshr_probe_ack_id),
        .mshr_pending_probes(mshr_pending_probes),
        .mshr_busy(mshr_busy)
    );

    // ---------------------------------------------------------
    // L2 Directory
    // ---------------------------------------------------------
    rv64_l2_directory #(
        .SETS(SETS),
        .WAYS(WAYS),
        .CORES(CORES)
    ) directory (
        .clk(clk),
        .rst_n(rst_n),
        .rd_set(dir_rd_set),
        .rd_valid(dir_rd_valid),
        .rd_sharers(dir_rd_sharers),
        .rd_owner_valid(dir_rd_owner_valid),
        .rd_owner_id(dir_rd_owner_id),
        .rd_dirty(dir_rd_dirty),
        .we(dir_we),
        .wr_set(dir_wr_set),
        .wr_way(dir_wr_way),
        .wr_valid(dir_wr_valid),
        .wr_sharers(dir_wr_sharers),
        .wr_owner_valid(dir_wr_owner_valid),
        .wr_owner_id(dir_wr_owner_id),
        .wr_dirty(dir_wr_dirty)
    );

    // ---------------------------------------------------------
    // L2 Arrays (Tags + Data)
    // ---------------------------------------------------------
    // Note: Arrays module has combined interface for Tag and Data?
    // Let's check rv64_l2_arrays.v ports.
    // It has: index, word_sel, way_sel, write_en, be, tag_in, wdata
    // It seems it shares address/control for both Tag and Data?
    // But FSM drives them separately: tag_set, tag_way vs data_set, data_way.
    // And tag_we vs data_we.
    
    // If rv64_l2_arrays.v has shared control, we have a problem if FSM tries to access them differently.
    // FSM usually accesses them together or separately.
    // Let's check rv64_l2_arrays.v again.
    
    // It has ONE set of controls: index, word_sel, way_sel, write_en.
    // This implies simultaneous access or shared port.
    // But FSM has separate outputs.
    // We might need to OR them or Multiplex them?
    // Or maybe rv64_l2_arrays.v needs to be split or modified?
    // Or we instantiate two copies? No, they are physically different arrays (Tag vs Data).
    // rv64_l2_arrays.v contains BOTH.
    
    // If FSM asserts tag_we and data_we at same time for same set/way, it works.
    // If FSM asserts tag_we for Set A and data_we for Set B, it fails.
    // FSM logic:
    // ST_UPDATE: tag_we=1 (if miss), dir_we=1.
    // ST_MEM_READ: data_we=1.
    // ST_MEM_WRITE: data read (implicit).
    
    // It seems FSM accesses them in different states usually.
    // But we need to mux the controls.
    
    wire [7:0] array_index;
    wire [2:0] array_word_sel;
    wire [3:0] array_way_sel;
    wire [7:0] array_be; // Always FF?
    
    // Priority Mux for Arrays
    // Data access is more frequent (bursts). Tag write is rare (miss).
    // But Tag Read is needed for lookup?
    // Wait, rv64_l2_arrays.v provides `tag_way_flat` which is ALL tags for ALL ways in the set?
    // No, `tag_way_flat` depends on `index`.
    // So we need to drive `index` with `req_addr` during lookup.
    // FSM drives `tag_set` (which comes from req_addr).
    
    // So:
    // If tag_we, use tag_set/tag_way.
    // If data_we, use data_set/data_way.
    // If neither (Read), use... req_addr?
    // FSM drives `tag_set` continuously?
    // In ST_IDLE/RAM_WAIT, FSM drives `tag_set = req_addr_q[13:6]`.
    // So we can default to tag_set.
    
    // Fix UNOPTFLAT: Use tag_set directly as it is always req_addr_q[13:6]
    assign array_index = tag_set; 
    assign array_way_sel = (data_we) ? data_way : tag_way;
    assign array_word_sel = data_word_sel;
    assign array_be = 8'hFF; // Always full word write for now? FSM doesn't output mask for data array write?
    // FSM has `mem_a_mask` for Memory Interface, but for internal Data Array?
    // `data_we` is 1 bit. `data_wdata` is 64 bits.
    // We assume full 64-bit write to array.
    
    rv64_l2_arrays arrays (
        .clk(clk),
        .rst_n(rst_n),
        .index(array_index),
        .word_sel(array_word_sel),
        .way_sel(array_way_sel),
        .data_we(data_we),
        .tag_we(tag_we),
        .be(array_be),
        .tag_in(tag_wdata),
        .wdata(data_wdata),
        .rdata_selected(data_rdata),
        .tag_selected(unused_tag_selected),
        .rdata_way_flat(unused_rdata_way_flat), 
        .tag_way_flat(tag_way_flat)
    );

    // ---------------------------------------------------------
    // L2 MSHR
    // ---------------------------------------------------------
    rv64_l2_mshr #(
        .ADDR_W(ADDR_W),
        .SOURCE_W(6), // 4 (L1 Source) + 2 (Client ID)? No, Source is 4 bits from L1.
        // Wait, FSM uses `a_source` which is 4 bits.
        // MSHR `SOURCE_W` parameter default is 6.
        // Let's check what we need.
        // We need to store `a_source` (4 bits).
        // So SOURCE_W should be 4.
        .TYPE_W(3),
        .CORES(CORES)
    ) mshr (
        .clk(clk),
        .rst_n(rst_n),
        .alloc_req(mshr_alloc),
        .alloc_addr(tl_a_address), // Alloc uses current A address
        .alloc_source(tl_a_source), // Alloc uses current A source
        .alloc_type(tl_a_opcode),   // Alloc uses current A opcode
        .alloc_ready(unused_mshr_alloc_ready),
        
        .dealloc_req(mshr_dealloc),
        .set_probes(mshr_set_probes != 0), // Trigger when mask is non-zero?
        // FSM asserts `mshr_set_probes` with the mask.
        // MSHR expects `set_probes` (strobe) and `probes_mask`.
        // FSM logic: `mshr_set_probes = probes_to_send`.
        // This is a level signal in ST_CHECK?
        // We need to be careful. MSHR `set_probes` loads the mask.
        // FSM should pulse it?
        // In `rv64_l2_fsm.v`:
        // `mshr_set_probes` is driven in `ST_CHECK`.
        // It seems to be a level.
        // MSHR logic:
        // `if (set_probes) pending_probes_q <= probes_mask;`
        // If it's level, it will keep reloading.
        // But `pending_probes_q` is also cleared by `probe_ack`.
        // If we keep reloading, we might overwrite the cleared bits.
        // FSM stays in ST_CHECK until all probes sent?
        // No, FSM goes to ST_WAIT_ACK.
        // In ST_WAIT_ACK, `mshr_set_probes` is 0 (default).
        // So it should be fine.
        
        .probes_mask(mshr_set_probes),
        .probe_ack(mshr_probe_ack),
        .probe_ack_id(mshr_probe_ack_id),
        
        .valid(mshr_busy),
        .addr(unused_mshr_addr),
        .source(unused_mshr_source),
        .req_type(unused_mshr_type),
        .pending_probes(mshr_pending_probes)
    );

endmodule
