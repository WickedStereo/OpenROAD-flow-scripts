// rv64_cache_system.v — 4-core TileLink-C cache system (L1 + xbar + L2)
`timescale 1ns/1ps

`include "params.vh"

/* verilator lint_off UNUSEDSIGNAL */

module rv64_cache_system #(
    parameter CORES       = 4,
    parameter ADDR_W      = 64,
    parameter DATA_W      = 64,
    parameter SOURCE_W    = 4,                             // L1 source-ID width
    parameter SINK_W      = 4,
    parameter M_SOURCE_W  = SOURCE_W + $clog2(CORES)       // L2 source-ID width (extended)
) (
    input  wire clk,
    input  wire rst_n,

    // ---- CPU Interfaces (flattened array of CORES ports) ----
    input  wire [CORES-1:0]        cpu_req,
    input  wire [CORES-1:0]        cpu_we,
    input  wire [CORES*8-1:0]      cpu_be,
    input  wire [CORES*64-1:0]     cpu_addr,
    input  wire [CORES*64-1:0]     cpu_wdata,
    output wire [CORES-1:0]        cpu_gnt,
    output wire [CORES-1:0]        cpu_rvalid,
    output wire [CORES*64-1:0]     cpu_rdata,

    // Atomic Operation Interfaces (flattened, active-low tie-off ok)
    input  wire [CORES-1:0]        cpu_amo,
    input  wire [CORES-1:0]        cpu_lr,
    input  wire [CORES-1:0]        cpu_sc,
    input  wire [CORES*5-1:0]      cpu_amo_op,
    input  wire [CORES-1:0]        cpu_amo_word,

    // ---- Memory Interface (TL-UH from L2 to main memory) ----
    output wire [2:0]              mem_a_opcode,
    output wire [2:0]              mem_a_param,
    output wire [2:0]              mem_a_size,
    output wire [3:0]              mem_a_source,
    output wire [ADDR_W-1:0]       mem_a_address,
    output wire [7:0]              mem_a_mask,
    output wire [DATA_W-1:0]       mem_a_data,
    output wire                    mem_a_valid,
    input  wire                    mem_a_ready,

    input  wire [2:0]              mem_d_opcode,
    input  wire [1:0]              mem_d_param,
    input  wire [2:0]              mem_d_size,
    input  wire [3:0]              mem_d_source,
    input  wire [1:0]              mem_d_sink,
    input  wire                    mem_d_denied,
    input  wire [DATA_W-1:0]       mem_d_data,
    input  wire                    mem_d_corrupt,
    input  wire                    mem_d_valid,
    output wire                    mem_d_ready
);

    // ================================================================
    //  Wires: L1 <-> Xbar
    // ================================================================

    // -- Channel A (L1 → Xbar) --
    wire [CORES-1:0]          l1_a_valid;
    wire [CORES-1:0]          l1_a_ready;
    wire [CORES*3-1:0]        l1_a_opcode;
    wire [CORES*3-1:0]        l1_a_param;
    wire [CORES*4-1:0]        l1_a_size;
    wire [CORES*SOURCE_W-1:0] l1_a_source;
    wire [CORES*ADDR_W-1:0]   l1_a_address;
    wire [CORES*8-1:0]        l1_a_mask;
    wire [CORES*DATA_W-1:0]   l1_a_data;
    wire [CORES-1:0]          l1_a_corrupt;

    // -- Channel B (Xbar → L1) --
    wire [CORES-1:0]          l1_b_valid;
    wire [CORES-1:0]          l1_b_ready;
    wire [CORES*3-1:0]        l1_b_opcode;
    wire [CORES*3-1:0]        l1_b_param;
    wire [CORES*4-1:0]        l1_b_size;
    wire [CORES*SOURCE_W-1:0] l1_b_source;
    wire [CORES*ADDR_W-1:0]   l1_b_address;
    wire [CORES*8-1:0]        l1_b_mask;
    wire [CORES*DATA_W-1:0]   l1_b_data;
    wire [CORES-1:0]          l1_b_corrupt;

    // -- Channel C (L1 → Xbar) --
    wire [CORES-1:0]          l1_c_valid;
    wire [CORES-1:0]          l1_c_ready;
    wire [CORES*3-1:0]        l1_c_opcode;
    wire [CORES*3-1:0]        l1_c_param;
    wire [CORES*4-1:0]        l1_c_size;
    wire [CORES*SOURCE_W-1:0] l1_c_source;
    wire [CORES*ADDR_W-1:0]   l1_c_address;
    wire [CORES*DATA_W-1:0]   l1_c_data;
    wire [CORES-1:0]          l1_c_corrupt;

    // -- Channel D (Xbar → L1) --
    wire [CORES-1:0]          l1_d_valid;
    wire [CORES-1:0]          l1_d_ready;
    wire [CORES*3-1:0]        l1_d_opcode;
    wire [CORES*3-1:0]        l1_d_param;
    wire [CORES*4-1:0]        l1_d_size;
    wire [CORES*SOURCE_W-1:0] l1_d_source;
    wire [CORES*SINK_W-1:0]   l1_d_sink;
    wire [CORES-1:0]          l1_d_denied;
    wire [CORES*DATA_W-1:0]   l1_d_data;
    wire [CORES-1:0]          l1_d_corrupt;

    // -- Channel E (L1 → Xbar) --
    wire [CORES-1:0]          l1_e_valid;
    wire [CORES-1:0]          l1_e_ready;
    wire [CORES*SINK_W-1:0]   l1_e_sink;

    // ================================================================
    //  Wires: Xbar <-> L2
    // ================================================================

    wire          l2_a_valid;
    wire          l2_a_ready;
    wire [2:0]    l2_a_opcode;
    wire [2:0]    l2_a_param;
    wire [M_SOURCE_W-1:0] l2_a_source;
    wire [ADDR_W-1:0]     l2_a_address;

    wire          l2_b_valid;
    wire          l2_b_ready;
    wire [2:0]    l2_b_opcode;
    wire [1:0]    l2_b_param;
    wire [3:0]    l2_b_size;
    wire [SOURCE_W-1:0] l2_b_source;
    wire [ADDR_W-1:0]   l2_b_address;
    wire [7:0]    l2_b_mask;
    wire [DATA_W-1:0]   l2_b_data;
    wire          l2_b_corrupt;
    wire [$clog2(CORES)-1:0] l2_b_dest;

    wire          l2_c_valid;
    wire          l2_c_ready;
    wire [2:0]    l2_c_opcode;
    wire [2:0]    l2_c_param;
    wire [M_SOURCE_W-1:0] l2_c_source;
    wire [ADDR_W-1:0]     l2_c_address;
    wire [DATA_W-1:0]     l2_c_data;

    wire          l2_d_valid;
    wire          l2_d_ready;
    wire [2:0]    l2_d_opcode;
    wire [1:0]    l2_d_param;
    wire [3:0]    l2_d_size;
    wire [M_SOURCE_W-1:0] l2_d_source;
    wire [1:0]    l2_d_sink;
    wire          l2_d_denied;
    wire [DATA_W-1:0]     l2_d_data;
    wire          l2_d_corrupt;

    wire          l2_e_ready;

    // Unused xbar manager-side signals (not consumed by L2)
    wire [3:0]           unused_l2_a_size;
    wire [7:0]           unused_l2_a_mask;
    wire [DATA_W-1:0]    unused_l2_a_data;
    wire                 unused_l2_a_corrupt;
    wire [3:0]           unused_l2_c_size;
    wire                 unused_l2_c_corrupt;
    wire                 unused_l2_e_valid;
    wire [SINK_W-1:0]    unused_l2_e_sink;

    // ================================================================
    //  L1 Instances (per-core)
    // ================================================================

    genvar i;
    generate
        for (i = 0; i < CORES; i = i + 1) begin : gen_l1

            rv64_l1_dcache l1 (
                .clk            (clk),
                .rst_n          (rst_n),
                .invalidate_all (1'b0),

                // CPU interface
                .req            (cpu_req[i]),
                .we             (cpu_we[i]),
                .be             (cpu_be[i*8 +: 8]),
                .addr           (cpu_addr[i*64 +: 64]),
                .wdata          (cpu_wdata[i*64 +: 64]),
                .gnt            (cpu_gnt[i]),
                .rvalid         (cpu_rvalid[i]),
                .rdata          (cpu_rdata[i*64 +: 64]),

                // Atomic operation ports (active-low defaults at top-level)
                .amo            (cpu_amo[i]),
                .lr             (cpu_lr[i]),
                .sc             (cpu_sc[i]),
                .amo_op         (cpu_amo_op[i*5 +: 5]),
                .amo_word       (cpu_amo_word[i]),

                // TileLink A (Request  → Xbar)
                .tl_a_valid     (l1_a_valid[i]),
                .tl_a_ready     (l1_a_ready[i]),
                .tl_a_opcode    (l1_a_opcode[i*3 +: 3]),
                .tl_a_param     (l1_a_param[i*3 +: 3]),
                .tl_a_size      (l1_a_size[i*4 +: 4]),
                .tl_a_source    (l1_a_source[i*SOURCE_W +: SOURCE_W]),
                .tl_a_address   (l1_a_address[i*ADDR_W +: ADDR_W]),
                .tl_a_mask      (l1_a_mask[i*8 +: 8]),
                .tl_a_data      (l1_a_data[i*DATA_W +: DATA_W]),
                .tl_a_corrupt   (l1_a_corrupt[i]),

                // TileLink B (Probe  ← Xbar)
                .tl_b_valid     (l1_b_valid[i]),
                .tl_b_ready     (l1_b_ready[i]),
                .tl_b_opcode    (l1_b_opcode[i*3 +: 3]),
                .tl_b_param     (l1_b_param[i*3 +: 3]),
                .tl_b_size      (l1_b_size[i*4 +: 4]),
                .tl_b_source    (l1_b_source[i*SOURCE_W +: SOURCE_W]),
                .tl_b_address   (l1_b_address[i*ADDR_W +: ADDR_W]),
                .tl_b_mask      (l1_b_mask[i*8 +: 8]),
                .tl_b_data      (l1_b_data[i*DATA_W +: DATA_W]),
                .tl_b_corrupt   (l1_b_corrupt[i]),

                // TileLink C (Release → Xbar)
                .tl_c_valid     (l1_c_valid[i]),
                .tl_c_ready     (l1_c_ready[i]),
                .tl_c_opcode    (l1_c_opcode[i*3 +: 3]),
                .tl_c_param     (l1_c_param[i*3 +: 3]),
                .tl_c_size      (l1_c_size[i*4 +: 4]),
                .tl_c_source    (l1_c_source[i*SOURCE_W +: SOURCE_W]),
                .tl_c_address   (l1_c_address[i*ADDR_W +: ADDR_W]),
                .tl_c_data      (l1_c_data[i*DATA_W +: DATA_W]),
                .tl_c_corrupt   (l1_c_corrupt[i]),

                // TileLink D (Grant  ← Xbar)
                .tl_d_valid     (l1_d_valid[i]),
                .tl_d_ready     (l1_d_ready[i]),
                .tl_d_opcode    (l1_d_opcode[i*3 +: 3]),
                .tl_d_param     (l1_d_param[i*3 +: 2]),  // D param is 2-bit
                .tl_d_size      (l1_d_size[i*4 +: 4]),
                .tl_d_source    (l1_d_source[i*SOURCE_W +: SOURCE_W]),
                .tl_d_sink      (l1_d_sink[i*SINK_W +: SINK_W]),
                .tl_d_denied    (l1_d_denied[i]),
                .tl_d_data      (l1_d_data[i*DATA_W +: DATA_W]),
                .tl_d_corrupt   (l1_d_corrupt[i]),

                // TileLink E (Ack    → Xbar)
                .tl_e_valid     (l1_e_valid[i]),
                .tl_e_ready     (l1_e_ready[i]),
                .tl_e_sink      (l1_e_sink[i*SINK_W +: SINK_W])
            );

        end
    endgenerate

    // ================================================================
    //  Crossbar (N-to-1 TileLink socket)
    // ================================================================

    tl_socket_m1 #(
        .N_CLIENTS (CORES),
        .DATA_W    (DATA_W),
        .ADDR_W    (ADDR_W),
        .SOURCE_W  (SOURCE_W),
        .SINK_W    (SINK_W)
    ) xbar (
        .clk        (clk),
        .rst_n      (rst_n),

        // Client-side (L1s)
        .cli_a_valid_i   (l1_a_valid),
        .cli_a_ready_o   (l1_a_ready),
        .cli_a_opcode_i  (l1_a_opcode),
        .cli_a_param_i   (l1_a_param),
        .cli_a_size_i    (l1_a_size),
        .cli_a_source_i  (l1_a_source),
        .cli_a_address_i (l1_a_address),
        .cli_a_mask_i    (l1_a_mask),
        .cli_a_data_i    (l1_a_data),
        .cli_a_corrupt_i (l1_a_corrupt),

        .cli_b_valid_o   (l1_b_valid),
        .cli_b_ready_i   (l1_b_ready),
        .cli_b_opcode_o  (l1_b_opcode),
        .cli_b_param_o   (l1_b_param),
        .cli_b_size_o    (l1_b_size),
        .cli_b_source_o  (l1_b_source),
        .cli_b_address_o (l1_b_address),
        .cli_b_mask_o    (l1_b_mask),
        .cli_b_data_o    (l1_b_data),
        .cli_b_corrupt_o (l1_b_corrupt),

        .cli_c_valid_i   (l1_c_valid),
        .cli_c_ready_o   (l1_c_ready),
        .cli_c_opcode_i  (l1_c_opcode),
        .cli_c_param_i   (l1_c_param),
        .cli_c_size_i    (l1_c_size),
        .cli_c_source_i  (l1_c_source),
        .cli_c_address_i (l1_c_address),
        .cli_c_data_i    (l1_c_data),
        .cli_c_corrupt_i (l1_c_corrupt),

        .cli_d_valid_o   (l1_d_valid),
        .cli_d_ready_i   (l1_d_ready),
        .cli_d_opcode_o  (l1_d_opcode),
        .cli_d_param_o   (l1_d_param),
        .cli_d_size_o    (l1_d_size),
        .cli_d_source_o  (l1_d_source),
        .cli_d_sink_o    (l1_d_sink),
        .cli_d_denied_o  (l1_d_denied),
        .cli_d_data_o    (l1_d_data),
        .cli_d_corrupt_o (l1_d_corrupt),

        .cli_e_valid_i   (l1_e_valid),
        .cli_e_ready_o   (l1_e_ready),
        .cli_e_sink_i    (l1_e_sink),

        // Manager-side (L2)
        .mgr_a_valid_o   (l2_a_valid),
        .mgr_a_ready_i   (l2_a_ready),
        .mgr_a_opcode_o  (l2_a_opcode),
        .mgr_a_param_o   (l2_a_param),
        .mgr_a_size_o    (unused_l2_a_size),
        .mgr_a_source_o  (l2_a_source),
        .mgr_a_address_o (l2_a_address),
        .mgr_a_mask_o    (unused_l2_a_mask),
        .mgr_a_data_o    (unused_l2_a_data),
        .mgr_a_corrupt_o (unused_l2_a_corrupt),

        .mgr_b_valid_i   (l2_b_valid),
        .mgr_b_ready_o   (l2_b_ready),
        .mgr_b_opcode_i  (l2_b_opcode),
        .mgr_b_param_i   ({1'b0, l2_b_param}),  // 2-bit → 3-bit zero-extension
        .mgr_b_size_i    (l2_b_size),
        .mgr_b_source_i  (l2_b_source),
        .mgr_b_address_i (l2_b_address),
        .mgr_b_mask_i    (l2_b_mask),
        .mgr_b_data_i    (l2_b_data),
        .mgr_b_corrupt_i (l2_b_corrupt),
        .mgr_b_dest_i    (l2_b_dest),

        .mgr_c_valid_o   (l2_c_valid),
        .mgr_c_ready_i   (l2_c_ready),
        .mgr_c_opcode_o  (l2_c_opcode),
        .mgr_c_param_o   (l2_c_param),
        .mgr_c_size_o    (unused_l2_c_size),
        .mgr_c_source_o  (l2_c_source),
        .mgr_c_address_o (l2_c_address),
        .mgr_c_data_o    (l2_c_data),
        .mgr_c_corrupt_o (unused_l2_c_corrupt),

        .mgr_d_valid_i   (l2_d_valid),
        .mgr_d_ready_o   (l2_d_ready),
        .mgr_d_opcode_i  (l2_d_opcode),
        .mgr_d_param_i   ({1'b0, l2_d_param}),  // 2-bit → 3-bit zero-extension
        .mgr_d_size_i    (l2_d_size),
        .mgr_d_source_i  (l2_d_source),
        .mgr_d_sink_i    ({2'b00, l2_d_sink}),   // 2-bit → 4-bit zero-extension
        .mgr_d_denied_i  (l2_d_denied),
        .mgr_d_data_i    (l2_d_data),
        .mgr_d_corrupt_i (l2_d_corrupt),

        .mgr_e_valid_o   (unused_l2_e_valid),
        .mgr_e_ready_i   (l2_e_ready),
        .mgr_e_sink_o    (unused_l2_e_sink)
    );

    // ================================================================
    //  L2 default signals (bus fields L2 doesn't drive)
    // ================================================================

    assign l2_b_size    = 4'd6;    // 64 bytes = cache-line
    assign l2_b_source  = {SOURCE_W{1'b0}};
    assign l2_b_mask    = 8'hFF;
    assign l2_b_data    = {DATA_W{1'b0}};
    assign l2_b_corrupt = 1'b0;

    assign l2_d_size    = 4'd6;
    assign l2_d_denied  = 1'b0;
    assign l2_d_corrupt = 1'b0;

    assign l2_e_ready   = 1'b1;    // Always accept E-channel from xbar

    // ================================================================
    //  L2 Cache Instance
    // ================================================================

    rv64_l2_cache #(
        .CORES     (CORES),
        .SOURCE_W  (M_SOURCE_W),
        .CID_W     ($clog2(CORES))
    ) l2 (
        .clk             (clk),
        .rst_n           (rst_n),

        // TileLink A (from xbar)
        .tl_a_opcode     (l2_a_opcode),
        .tl_a_param      (l2_a_param),
        .tl_a_source     (l2_a_source),
        .tl_a_address    (l2_a_address),
        .tl_a_valid      (l2_a_valid),
        .tl_a_ready      (l2_a_ready),

        // TileLink B (probes → xbar)
        .tl_b_opcode     (l2_b_opcode),
        .tl_b_param      (l2_b_param),
        .tl_b_address    (l2_b_address),
        .tl_b_valid      (l2_b_valid),
        .tl_b_ready      (l2_b_ready),
        .tl_b_dest       (l2_b_dest),

        // TileLink C (releases from xbar)
        .tl_c_opcode     (l2_c_opcode),
        .tl_c_param      (l2_c_param),
        .tl_c_source     (l2_c_source),
        .tl_c_address    (l2_c_address),
        .tl_c_data       (l2_c_data),
        .tl_c_valid      (l2_c_valid),
        .tl_c_ready      (l2_c_ready),

        // TileLink D (grants → xbar)
        .tl_d_opcode     (l2_d_opcode),
        .tl_d_param      (l2_d_param),
        .tl_d_data       (l2_d_data),
        .tl_d_source     (l2_d_source),
        .tl_d_sink       (l2_d_sink),
        .tl_d_valid      (l2_d_valid),
        .tl_d_ready      (l2_d_ready),

        // Memory Interface (TL-UH → main memory)
        .mem_a_opcode    (mem_a_opcode),
        .mem_a_param     (mem_a_param),
        .mem_a_size      (mem_a_size),
        .mem_a_source    (mem_a_source),
        .mem_a_address   (mem_a_address),
        .mem_a_mask      (mem_a_mask),
        .mem_a_data      (mem_a_data),
        .mem_a_valid     (mem_a_valid),
        .mem_a_ready     (mem_a_ready),

        .mem_d_opcode    (mem_d_opcode),
        .mem_d_param     (mem_d_param),
        .mem_d_size      (mem_d_size),
        .mem_d_source    (mem_d_source),
        .mem_d_sink      (mem_d_sink),
        .mem_d_denied    (mem_d_denied),
        .mem_d_data      (mem_d_data),
        .mem_d_corrupt   (mem_d_corrupt),
        .mem_d_valid     (mem_d_valid),
        .mem_d_ready     (mem_d_ready)
    );

endmodule
