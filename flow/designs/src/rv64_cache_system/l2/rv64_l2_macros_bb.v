`timescale 1ns/1ps

(* blackbox *)
module rv64_l2_probe_block #(
    parameter CORES = 4,
    parameter STATE_W = 4
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     hit,
    input  wire [2:0]               req_opcode,
    input  wire [63:0]              req_line_addr,
    input  wire [63:0]              victim_probe_addr,
    input  wire [2:0]               req_param,
    input  wire [CORES-1:0]         hit_sharers,
    input  wire                     hit_owner_valid,
    input  wire [$clog2(CORES)-1:0] hit_owner_id,
    input  wire [$clog2(CORES)-1:0] requester_id,
    input  wire [15:0]              dir_rd_valid,
    input  wire [16*CORES-1:0]      dir_rd_sharers,
    input  wire [15:0]              dir_rd_owner_valid,
    input  wire [16*$clog2(CORES)-1:0] dir_rd_owner_id,
    input  wire [3:0]               plru_victim_way,
    input  wire [CORES-1:0]         probes_sent,
    input  wire                     b_valid,
    input  wire                     b_ready,
    output wire [CORES-1:0]         probes_to_send,
    output wire [$clog2(CORES)-1:0] next_probe_target,
    output wire                     probe_needed,
    output wire [CORES-1:0]         mshr_set_probes,
    output wire                     b_launch,
    output wire [2:0]               b_launch_opcode,
    output wire [1:0]               b_launch_param,
    output wire [63:0]              b_launch_address,
    output wire [$clog2(CORES)-1:0] b_launch_dest,
    output wire [STATE_W-1:0]       next_state
);
endmodule

(* blackbox *)
module rv64_l2_grant_update_block #(
    parameter CORES = 4,
    parameter SOURCE_W = 6,
    parameter CID_W = 2,
    parameter STATE_W = 4
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     processing_release,
    input  wire [2:0]               req_opcode,
    input  wire [2:0]               req_param,
    input  wire [SOURCE_W-1:0]      req_source,
    input  wire [63:0]              req_addr,
    input  wire [CID_W-1:0]         req_core_id,
    input  wire [2:0]               burst_cnt,
    input  wire                     d_ready,
    input  wire [63:0]              data_rdata,
    input  wire                     latched_hit,
    input  wire [3:0]               latched_hit_way,
    input  wire [3:0]               victim_way,
    input  wire [CORES-1:0]         hit_sharers,
    input  wire                     hit_owner_valid,
    input  wire [CID_W-1:0]         hit_owner_id,
    input  wire                     hit_dirty,
    output wire                     grant_d_valid,
    output wire [2:0]               grant_d_opcode,
    output wire [1:0]               grant_d_param,
    output wire [63:0]              grant_d_data,
    output wire [SOURCE_W-1:0]      grant_d_source,
    output wire [7:0]               grant_data_set,
    output wire [3:0]               grant_data_way,
    output wire [2:0]               grant_data_word_sel,
    output wire [3:0]               grant_tag_way,
    output wire                     grant_drive_data_read,
    output wire [STATE_W-1:0]       grant_next_state,
    output wire                     update_dir_we,
    output wire                     update_dir_wr_valid,
    output wire [CORES-1:0]         update_dir_wr_sharers,
    output wire                     update_dir_wr_owner_valid,
    output wire [CID_W-1:0]         update_dir_wr_owner_id,
    output wire                     update_dir_wr_dirty,
    output wire                     update_tag_we,
    output wire [STATE_W-1:0]       update_next_state
);
endmodule
