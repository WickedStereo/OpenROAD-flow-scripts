`timescale 1ns/1ps

module tl_socket_m1 #(
    parameter N_CLIENTS = 4,
    parameter DATA_W = 64,
    parameter ADDR_W = 64,
    parameter SOURCE_W = 4,
    parameter SINK_W = 4,
    parameter M_SOURCE_W = SOURCE_W + $clog2(N_CLIENTS)
) (
    input clk,
    input rst_n,

    // ---------------------------------------------------------
    // Client Interfaces (N_CLIENTS) - Flattened Arrays
    // ---------------------------------------------------------
    
    // Channel A (Request)
    input  [N_CLIENTS-1:0]          cli_a_valid_i,
    output [N_CLIENTS-1:0]          cli_a_ready_o,
    input  [N_CLIENTS*3-1:0]        cli_a_opcode_i,
    input  [N_CLIENTS*3-1:0]        cli_a_param_i,
    input  [N_CLIENTS*4-1:0]        cli_a_size_i,
    input  [N_CLIENTS*SOURCE_W-1:0] cli_a_source_i,
    input  [N_CLIENTS*ADDR_W-1:0]   cli_a_address_i,
    input  [N_CLIENTS*8-1:0]        cli_a_mask_i,
    input  [N_CLIENTS*DATA_W-1:0]   cli_a_data_i,
    input  [N_CLIENTS-1:0]          cli_a_corrupt_i,

    // Channel B (Probe)
    output [N_CLIENTS-1:0]          cli_b_valid_o,
    input  [N_CLIENTS-1:0]          cli_b_ready_i,
    output [N_CLIENTS*3-1:0]        cli_b_opcode_o,
    output [N_CLIENTS*3-1:0]        cli_b_param_o,
    output [N_CLIENTS*4-1:0]        cli_b_size_o,
    output [N_CLIENTS*SOURCE_W-1:0] cli_b_source_o, // L2 Source ID
    output [N_CLIENTS*ADDR_W-1:0]   cli_b_address_o,
    output [N_CLIENTS*8-1:0]        cli_b_mask_o,
    output [N_CLIENTS*DATA_W-1:0]   cli_b_data_o,
    output [N_CLIENTS-1:0]          cli_b_corrupt_o,

    // Channel C (Release)
    input  [N_CLIENTS-1:0]          cli_c_valid_i,
    output [N_CLIENTS-1:0]          cli_c_ready_o,
    input  [N_CLIENTS*3-1:0]        cli_c_opcode_i,
    input  [N_CLIENTS*3-1:0]        cli_c_param_i,
    input  [N_CLIENTS*4-1:0]        cli_c_size_i,
    input  [N_CLIENTS*SOURCE_W-1:0] cli_c_source_i,
    input  [N_CLIENTS*ADDR_W-1:0]   cli_c_address_i,
    input  [N_CLIENTS*DATA_W-1:0]   cli_c_data_i,
    input  [N_CLIENTS-1:0]          cli_c_corrupt_i,

    // Channel D (Grant)
    output [N_CLIENTS-1:0]          cli_d_valid_o,
    input  [N_CLIENTS-1:0]          cli_d_ready_i,
    output [N_CLIENTS*3-1:0]        cli_d_opcode_o,
    output [N_CLIENTS*3-1:0]        cli_d_param_o,
    output [N_CLIENTS*4-1:0]        cli_d_size_o,
    output [N_CLIENTS*SOURCE_W-1:0] cli_d_source_o,
    output [N_CLIENTS*SINK_W-1:0]   cli_d_sink_o,
    output [N_CLIENTS-1:0]          cli_d_denied_o,
    output [N_CLIENTS*DATA_W-1:0]   cli_d_data_o,
    output [N_CLIENTS-1:0]          cli_d_corrupt_o,

    // Channel E (GrantAck)
    input  [N_CLIENTS-1:0]          cli_e_valid_i,
    output [N_CLIENTS-1:0]          cli_e_ready_o,
    input  [N_CLIENTS*SINK_W-1:0]   cli_e_sink_i,

    // ---------------------------------------------------------
    // Manager Interface (1 L2)
    // ---------------------------------------------------------

    // Channel A
    output                          mgr_a_valid_o,
    input                           mgr_a_ready_i,
    output [2:0]                    mgr_a_opcode_o,
    output [2:0]                    mgr_a_param_o,
    output [3:0]                    mgr_a_size_o,
    output [M_SOURCE_W-1:0]         mgr_a_source_o, // Extended Source
    output [ADDR_W-1:0]             mgr_a_address_o,
    output [7:0]                    mgr_a_mask_o,
    output [DATA_W-1:0]             mgr_a_data_o,
    output                          mgr_a_corrupt_o,

    // Channel B
    input                           mgr_b_valid_i,
    output                          mgr_b_ready_o,
    input  [2:0]                    mgr_b_opcode_i,
    input  [2:0]                    mgr_b_param_i,
    input  [3:0]                    mgr_b_size_i,
    input  [SOURCE_W-1:0]           mgr_b_source_i, // L2 Source ID
    input  [ADDR_W-1:0]             mgr_b_address_i,
    input  [7:0]                    mgr_b_mask_i,
    input  [DATA_W-1:0]             mgr_b_data_i,
    input                           mgr_b_corrupt_i,
    input  [$clog2(N_CLIENTS)-1:0]  mgr_b_dest_i,   // Destination Client ID

    // Channel C
    output                          mgr_c_valid_o,
    input                           mgr_c_ready_i,
    output [2:0]                    mgr_c_opcode_o,
    output [2:0]                    mgr_c_param_o,
    output [3:0]                    mgr_c_size_o,
    output [M_SOURCE_W-1:0]         mgr_c_source_o, // Extended Source
    output [ADDR_W-1:0]             mgr_c_address_o,
    output [DATA_W-1:0]             mgr_c_data_o,
    output                          mgr_c_corrupt_o,

    // Channel D
    input                           mgr_d_valid_i,
    output                          mgr_d_ready_o,
    input  [2:0]                    mgr_d_opcode_i,
    input  [2:0]                    mgr_d_param_i,
    input  [3:0]                    mgr_d_size_i,
    input  [M_SOURCE_W-1:0]         mgr_d_source_i, // Extended Source
    input  [SINK_W-1:0]             mgr_d_sink_i,
    input                           mgr_d_denied_i,
    input  [DATA_W-1:0]             mgr_d_data_i,
    input                           mgr_d_corrupt_i,

    // Channel E
    output                          mgr_e_valid_o,
    input                           mgr_e_ready_i,
    output [SINK_W-1:0]             mgr_e_sink_o
);

    localparam CID_W = (N_CLIENTS > 1) ? $clog2(N_CLIENTS) : 1;

    // ========================================================================
    // Channel A: N -> 1 Arbiter
    // ========================================================================
    
    // Pack A-Channel Data + Client ID
    // A Bundle Width = 3+3+4+SOURCE_W+ADDR_W+8+DATA_W+1 = 151 + SOURCE_W
    localparam A_WIDTH = 3+3+4+SOURCE_W+ADDR_W+8+DATA_W+1;
    localparam A_PACKED_W = A_WIDTH + CID_W;

    wire [N_CLIENTS*A_PACKED_W-1:0] a_packed_i;
    wire [A_PACKED_W-1:0]           a_packed_o;

    genvar i;
    generate
        for (i = 0; i < N_CLIENTS; i = i + 1) begin : pack_a
            assign a_packed_i[i*A_PACKED_W +: A_PACKED_W] = {
                i[CID_W-1:0], // Client ID
                cli_a_opcode_i[i*3 +: 3],
                cli_a_param_i[i*3 +: 3],
                cli_a_size_i[i*4 +: 4],
                cli_a_source_i[i*SOURCE_W +: SOURCE_W],
                cli_a_address_i[i*ADDR_W +: ADDR_W],
                cli_a_mask_i[i*8 +: 8],
                cli_a_data_i[i*DATA_W +: DATA_W],
                cli_a_corrupt_i[i]
            };
        end
    endgenerate

    tl_arbiter #(
        .N(N_CLIENTS),
        .DATA_W(A_PACKED_W)
    ) arb_a (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(cli_a_valid_i),
        .ready_o(cli_a_ready_o),
        .data_i(a_packed_i),
        .valid_o(mgr_a_valid_o),
        .ready_i(mgr_a_ready_i),
        .data_o(a_packed_o)
    );

    // Unpack A and Extend Source
    wire [CID_W-1:0] a_winner_id;
    wire [SOURCE_W-1:0] a_orig_source;
    
    assign {
        a_winner_id,
        mgr_a_opcode_o,
        mgr_a_param_o,
        mgr_a_size_o,
        a_orig_source,
        mgr_a_address_o,
        mgr_a_mask_o,
        mgr_a_data_o,
        mgr_a_corrupt_o
    } = a_packed_o;

    assign mgr_a_source_o = {a_winner_id, a_orig_source};


    // ========================================================================
    // Channel C: N -> 1 Arbiter
    // ========================================================================
    
    // C Bundle Width = 3+3+4+SOURCE_W+ADDR_W+DATA_W+1
    localparam C_WIDTH = 3+3+4+SOURCE_W+ADDR_W+DATA_W+1;
    localparam C_PACKED_W = C_WIDTH + CID_W;

    wire [N_CLIENTS*C_PACKED_W-1:0] c_packed_i;
    wire [C_PACKED_W-1:0]           c_packed_o;

    generate
        for (i = 0; i < N_CLIENTS; i = i + 1) begin : pack_c
            assign c_packed_i[i*C_PACKED_W +: C_PACKED_W] = {
                i[CID_W-1:0],
                cli_c_opcode_i[i*3 +: 3],
                cli_c_param_i[i*3 +: 3],
                cli_c_size_i[i*4 +: 4],
                cli_c_source_i[i*SOURCE_W +: SOURCE_W],
                cli_c_address_i[i*ADDR_W +: ADDR_W],
                cli_c_data_i[i*DATA_W +: DATA_W],
                cli_c_corrupt_i[i]
            };
        end
    endgenerate

    tl_arbiter #(
        .N(N_CLIENTS),
        .DATA_W(C_PACKED_W)
    ) arb_c (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(cli_c_valid_i),
        .ready_o(cli_c_ready_o),
        .data_i(c_packed_i),
        .valid_o(mgr_c_valid_o),
        .ready_i(mgr_c_ready_i),
        .data_o(c_packed_o)
    );

    wire [CID_W-1:0] c_winner_id;
    wire [SOURCE_W-1:0] c_orig_source;

    assign {
        c_winner_id,
        mgr_c_opcode_o,
        mgr_c_param_o,
        mgr_c_size_o,
        c_orig_source,
        mgr_c_address_o,
        mgr_c_data_o,
        mgr_c_corrupt_o
    } = c_packed_o;

    assign mgr_c_source_o = {c_winner_id, c_orig_source};


    // ========================================================================
    // Channel E: N -> 1 Arbiter
    // ========================================================================
    
    // E Bundle Width = SINK_W
    // We don't strictly need to extend Sink ID if L2 manages it globally.
    // But let's just pass it through.
    // Wait, if multiple clients send E, we need to arbitrate.
    
    localparam E_WIDTH = SINK_W;
    
    tl_arbiter #(
        .N(N_CLIENTS),
        .DATA_W(E_WIDTH)
    ) arb_e (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(cli_e_valid_i),
        .ready_o(cli_e_ready_o),
        .data_i(cli_e_sink_i), // Flattened array matches
        .valid_o(mgr_e_valid_o),
        .ready_i(mgr_e_ready_i),
        .data_o(mgr_e_sink_o)
    );


    // ========================================================================
    // Channel D: 1 -> N Demux
    // ========================================================================
    
    // D Bundle Width = 3+3+4+SOURCE_W+SINK_W+1+DATA_W+1
    // Note: We use SOURCE_W (original) for the output to client.
    localparam D_WIDTH = 3+3+4+SOURCE_W+SINK_W+1+DATA_W+1;
    
    wire [CID_W-1:0] d_dest_id;
    wire [SOURCE_W-1:0] d_orig_source;
    
    // Extract Dest ID from Extended Source
    assign d_dest_id = mgr_d_source_i[M_SOURCE_W-1 : SOURCE_W];
    assign d_orig_source = mgr_d_source_i[SOURCE_W-1 : 0];
    
    wire [D_WIDTH-1:0] d_packed_in;
    assign d_packed_in = {
        mgr_d_opcode_i,
        mgr_d_param_i,
        mgr_d_size_i,
        d_orig_source,
        mgr_d_sink_i,
        mgr_d_denied_i,
        mgr_d_data_i,
        mgr_d_corrupt_i
    };
    
    wire [N_CLIENTS*D_WIDTH-1:0] d_packed_out;
    
    tl_demux #(
        .N(N_CLIENTS),
        .DATA_W(D_WIDTH),
        .SEL_W(CID_W)
    ) demux_d (
        .valid_i(mgr_d_valid_i),
        .ready_o(mgr_d_ready_o),
        .data_i(d_packed_in),
        .sel_i(d_dest_id),
        .valid_o(cli_d_valid_o),
        .ready_i(cli_d_ready_i),
        .data_o(d_packed_out)
    );
    
    // Unpack D to Clients
    generate
        for (i = 0; i < N_CLIENTS; i = i + 1) begin : unpack_d
            assign {
                cli_d_opcode_o[i*3 +: 3],
                cli_d_param_o[i*3 +: 3],
                cli_d_size_o[i*4 +: 4],
                cli_d_source_o[i*SOURCE_W +: SOURCE_W],
                cli_d_sink_o[i*SINK_W +: SINK_W],
                cli_d_denied_o[i],
                cli_d_data_o[i*DATA_W +: DATA_W],
                cli_d_corrupt_o[i]
            } = d_packed_out[i*D_WIDTH +: D_WIDTH];
        end
    endgenerate


    // ========================================================================
    // Channel B: 1 -> N Demux (Directed Probe)
    // ========================================================================
    
    // B Bundle Width = 3+3+4+SOURCE_W+ADDR_W+8+DATA_W+1
    localparam B_WIDTH = 3+3+4+SOURCE_W+ADDR_W+8+DATA_W+1;
    
    wire [B_WIDTH-1:0] b_packed_in;
    assign b_packed_in = {
        mgr_b_opcode_i,
        mgr_b_param_i,
        mgr_b_size_i,
        mgr_b_source_i,
        mgr_b_address_i,
        mgr_b_mask_i,
        mgr_b_data_i,
        mgr_b_corrupt_i
    };
    
    wire [N_CLIENTS*B_WIDTH-1:0] b_packed_out;
    
    tl_demux #(
        .N(N_CLIENTS),
        .DATA_W(B_WIDTH),
        .SEL_W(CID_W)
    ) demux_b (
        .valid_i(mgr_b_valid_i),
        .ready_o(mgr_b_ready_o),
        .data_i(b_packed_in),
        .sel_i(mgr_b_dest_i),
        .valid_o(cli_b_valid_o),
        .ready_i(cli_b_ready_i),
        .data_o(b_packed_out)
    );
    
    generate
        for (i = 0; i < N_CLIENTS; i = i + 1) begin : unpack_b
            assign {
                cli_b_opcode_o[i*3 +: 3],
                cli_b_param_o[i*3 +: 3],
                cli_b_size_o[i*4 +: 4],
                cli_b_source_o[i*SOURCE_W +: SOURCE_W],
                cli_b_address_o[i*ADDR_W +: ADDR_W],
                cli_b_mask_o[i*8 +: 8],
                cli_b_data_o[i*DATA_W +: DATA_W],
                cli_b_corrupt_o[i]
            } = b_packed_out[i*B_WIDTH +: B_WIDTH];
        end
    endgenerate



endmodule
