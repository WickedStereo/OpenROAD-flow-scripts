`timescale 1ns/1ps

module rv64_l2_probe_planner #(
    parameter CORES = 4,
    parameter WAYS = 8
) (
    input  wire                     hit,
    input  wire [2:0]               req_opcode,
    input  wire [2:0]               req_param,
    input  wire [CORES-1:0]         hit_sharers,
    input  wire                     hit_owner_valid,
    input  wire [$clog2(CORES)-1:0] hit_owner_id,
    input  wire [$clog2(CORES)-1:0] requester_id,
    input  wire [WAYS-1:0]          dir_rd_valid,
    input  wire [WAYS*CORES-1:0]    dir_rd_sharers,
    input  wire [WAYS-1:0]          dir_rd_owner_valid,
    input  wire [WAYS*$clog2(CORES)-1:0] dir_rd_owner_id,
    input  wire [3:0]               plru_victim_way,
    input  wire [CORES-1:0]         probes_sent,
    output reg  [CORES-1:0]         probes_to_send,
    output reg  [$clog2(CORES)-1:0] next_probe_target,
    output reg                      probe_needed
);

    integer core_idx;
    always @* begin
        probes_to_send = {CORES{1'b0}};

        if (hit) begin
            if (req_opcode == 3'd6) begin
                if (req_param == 3'd0) begin
                    if (hit_owner_valid) begin
                        probes_to_send[hit_owner_id] = 1'b1;
                    end
                end else begin
                    probes_to_send = hit_sharers;
                    if (hit_owner_valid) begin
                        probes_to_send[hit_owner_id] = 1'b1;
                    end
                end
            end else if (req_opcode == 3'd7) begin
                probes_to_send = hit_sharers;
                if (hit_owner_valid) begin
                    probes_to_send[hit_owner_id] = 1'b1;
                end
            end

            probes_to_send[requester_id] = 1'b0;
        end else begin
            if (dir_rd_valid[plru_victim_way]) begin
                probes_to_send = dir_rd_sharers[plru_victim_way*CORES +: CORES];
                if (dir_rd_owner_valid[plru_victim_way]) begin
                    probes_to_send[dir_rd_owner_id[plru_victim_way*$clog2(CORES) +: $clog2(CORES)]] = 1'b1;
                end
            end
        end

        next_probe_target = {($clog2(CORES)){1'b0}};
        probe_needed = 1'b0;
        for (core_idx = 0; core_idx < CORES; core_idx = core_idx + 1) begin
            if (probes_to_send[core_idx] && !probes_sent[core_idx]) begin
                next_probe_target = core_idx[$clog2(CORES)-1:0];
                probe_needed = 1'b1;
            end
        end
    end

endmodule
