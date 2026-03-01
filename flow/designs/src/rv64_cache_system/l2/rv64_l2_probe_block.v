`timescale 1ns/1ps

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
    input  wire [7:0]              dir_rd_valid,
    input  wire [8*CORES-1:0]      dir_rd_sharers,
    input  wire [7:0]              dir_rd_owner_valid,
    input  wire [8*$clog2(CORES)-1:0] dir_rd_owner_id,
    input  wire [3:0]               plru_victim_way,
    input  wire [CORES-1:0]         probes_sent,
    input  wire                     b_valid,
    input  wire                     b_ready,
    output reg  [CORES-1:0]         probes_to_send,
    output reg  [$clog2(CORES)-1:0] next_probe_target,
    output reg                      probe_needed,
    output reg  [CORES-1:0]         mshr_set_probes,
    output reg                      b_launch,
    output reg  [2:0]               b_launch_opcode,
    output reg  [1:0]               b_launch_param,
    output reg  [63:0]              b_launch_address,
    output reg  [$clog2(CORES)-1:0] b_launch_dest,
    output reg  [STATE_W-1:0]       next_state
);

    reg                     hit_q;
    reg [2:0]               req_opcode_q;
    reg [63:0]              req_line_addr_q;
    reg [63:0]              victim_probe_addr_q;
    reg [2:0]               req_param_q;
    reg [CORES-1:0]         hit_sharers_q;
    reg                     hit_owner_valid_q;
    reg [$clog2(CORES)-1:0] hit_owner_id_q;
    reg [$clog2(CORES)-1:0] requester_id_q;
    reg [7:0]              dir_rd_valid_q;
    reg [8*CORES-1:0]      dir_rd_sharers_q;
    reg [7:0]              dir_rd_owner_valid_q;
    reg [8*$clog2(CORES)-1:0] dir_rd_owner_id_q;
    reg [3:0]               plru_victim_way_q;
    reg [CORES-1:0]         probes_sent_q;
    reg                     b_valid_q;
    reg                     b_ready_q;

    wire [CORES-1:0] planner_probes_to_send;
    wire [$clog2(CORES)-1:0] planner_next_probe_target;
    wire planner_probe_needed;

    wire [CORES-1:0] engine_mshr_set_probes;
    wire engine_b_launch;
    wire [2:0] engine_b_launch_opcode;
    wire [1:0] engine_b_launch_param;
    wire [63:0] engine_b_launch_address;
    wire [$clog2(CORES)-1:0] engine_b_launch_dest;
    wire [STATE_W-1:0] engine_next_state;

    rv64_l2_probe_planner #(
        .CORES(CORES),
        .WAYS(16)
    ) planner (
        .hit(hit_q),
        .req_opcode(req_opcode_q),
        .req_param(req_param_q),
        .hit_sharers(hit_sharers_q),
        .hit_owner_valid(hit_owner_valid_q),
        .hit_owner_id(hit_owner_id_q),
        .requester_id(requester_id_q),
        .dir_rd_valid(dir_rd_valid_q),
        .dir_rd_sharers(dir_rd_sharers_q),
        .dir_rd_owner_valid(dir_rd_owner_valid_q),
        .dir_rd_owner_id(dir_rd_owner_id_q),
        .plru_victim_way(plru_victim_way_q),
        .probes_sent(probes_sent_q),
        .probes_to_send(planner_probes_to_send),
        .next_probe_target(planner_next_probe_target),
        .probe_needed(planner_probe_needed)
    );

    rv64_l2_probe_engine #(
        .CORES(CORES),
        .CID_W($clog2(CORES)),
        .STATE_W(STATE_W)
    ) engine (
        .hit(hit_q),
        .req_opcode(req_opcode_q),
        .req_line_addr(req_line_addr_q),
        .victim_probe_addr(victim_probe_addr_q),
        .probes_to_send(planner_probes_to_send),
        .probes_sent(probes_sent_q),
        .next_probe_target(planner_next_probe_target),
        .probe_needed(planner_probe_needed),
        .b_valid(b_valid_q),
        .b_ready(b_ready_q),
        .mshr_set_probes(engine_mshr_set_probes),
        .b_launch(engine_b_launch),
        .b_launch_opcode(engine_b_launch_opcode),
        .b_launch_param(engine_b_launch_param),
        .b_launch_address(engine_b_launch_address),
        .b_launch_dest(engine_b_launch_dest),
        .next_state(engine_next_state)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hit_q <= 1'b0;
            req_opcode_q <= 3'd0;
            req_line_addr_q <= 64'd0;
            victim_probe_addr_q <= 64'd0;
            req_param_q <= 3'd0;
            hit_sharers_q <= {CORES{1'b0}};
            hit_owner_valid_q <= 1'b0;
            hit_owner_id_q <= {($clog2(CORES)){1'b0}};
            requester_id_q <= {($clog2(CORES)){1'b0}};
            dir_rd_valid_q <= 16'd0;
            dir_rd_sharers_q <= {(8*CORES){1'b0}};
            dir_rd_owner_valid_q <= 16'd0;
            dir_rd_owner_id_q <= {(8*$clog2(CORES)){1'b0}};
            plru_victim_way_q <= 4'd0;
            probes_sent_q <= {CORES{1'b0}};
            b_valid_q <= 1'b0;
            b_ready_q <= 1'b0;
            probes_to_send <= {CORES{1'b0}};
            next_probe_target <= {($clog2(CORES)){1'b0}};
            probe_needed <= 1'b0;
            mshr_set_probes <= {CORES{1'b0}};
            b_launch <= 1'b0;
            b_launch_opcode <= 3'd0;
            b_launch_param <= 2'd0;
            b_launch_address <= 64'd0;
            b_launch_dest <= {($clog2(CORES)){1'b0}};
            next_state <= {STATE_W{1'b0}};
        end else begin
            hit_q <= hit;
            req_opcode_q <= req_opcode;
            req_line_addr_q <= req_line_addr;
            victim_probe_addr_q <= victim_probe_addr;
            req_param_q <= req_param;
            hit_sharers_q <= hit_sharers;
            hit_owner_valid_q <= hit_owner_valid;
            hit_owner_id_q <= hit_owner_id;
            requester_id_q <= requester_id;
            dir_rd_valid_q <= dir_rd_valid;
            dir_rd_sharers_q <= dir_rd_sharers;
            dir_rd_owner_valid_q <= dir_rd_owner_valid;
            dir_rd_owner_id_q <= dir_rd_owner_id;
            plru_victim_way_q <= plru_victim_way;
            probes_sent_q <= probes_sent;
            b_valid_q <= b_valid;
            b_ready_q <= b_ready;
            probes_to_send <= planner_probes_to_send;
            next_probe_target <= planner_next_probe_target;
            probe_needed <= planner_probe_needed;
            mshr_set_probes <= engine_mshr_set_probes;
            b_launch <= engine_b_launch;
            b_launch_opcode <= engine_b_launch_opcode;
            b_launch_param <= engine_b_launch_param;
            b_launch_address <= engine_b_launch_address;
            b_launch_dest <= engine_b_launch_dest;
            next_state <= engine_next_state;
        end
    end

endmodule
