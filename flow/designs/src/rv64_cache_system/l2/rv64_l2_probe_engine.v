`timescale 1ns/1ps

module rv64_l2_probe_engine #(
    parameter CORES = 4,
    parameter CID_W = 2,
    parameter STATE_W = 4,
    parameter [STATE_W-1:0] ST_CHECK      = 4'd2,
    parameter [STATE_W-1:0] ST_WAIT_ACK   = 4'd3,
    parameter [STATE_W-1:0] ST_GRANT      = 4'd4,
    parameter [STATE_W-1:0] ST_EVICT_WAIT = 4'd7,
    parameter [STATE_W-1:0] ST_MEM_READ   = 4'd8
) (
    input  wire                     hit,
    input  wire [2:0]               req_opcode,
    input  wire [63:0]              req_line_addr,
    input  wire [63:0]              victim_probe_addr,
    input  wire [CORES-1:0]         probes_to_send,
    input  wire [CORES-1:0]         probes_sent,
    input  wire [CID_W-1:0]         next_probe_target,
    input  wire                     probe_needed,
    input  wire                     b_valid,
    input  wire                     b_ready,

    output reg  [CORES-1:0]         mshr_set_probes,
    output reg                      b_launch,
    output reg  [2:0]               b_launch_opcode,
    output reg  [1:0]               b_launch_param,
    output reg  [63:0]              b_launch_address,
    output reg  [CID_W-1:0]         b_launch_dest,
    output reg  [STATE_W-1:0]       next_state
);

    reg [CORES-1:0] next_probe_mask;

    always @* begin
        mshr_set_probes = {CORES{1'b0}};
        b_launch = 1'b0;
        b_launch_opcode = 3'd6;
        b_launch_param = 2'd0;
        b_launch_address = req_line_addr;
        b_launch_dest = {CID_W{1'b0}};
        next_state = ST_CHECK;
        next_probe_mask = ({{(CORES-1){1'b0}}, 1'b1} << next_probe_target);

        if (probes_to_send != {CORES{1'b0}}) begin
            if (probes_sent == {CORES{1'b0}}) begin
                mshr_set_probes = probes_to_send;
            end

            if (probe_needed && !b_valid) begin
                b_launch = 1'b1;
                b_launch_dest = next_probe_target;

                if (hit) begin
                    b_launch_address = req_line_addr;
                    if (req_opcode == 3'd7) begin
                        b_launch_opcode = 3'd7;
                        b_launch_param = 2'd0;
                    end else begin
                        b_launch_opcode = 3'd6;
                        b_launch_param = 2'd1;
                    end
                end else begin
                    b_launch_address = victim_probe_addr;
                    b_launch_opcode = 3'd6;
                    b_launch_param = 2'd2;
                end
            end

            if (b_valid && b_ready) begin
                if (probes_to_send == (probes_sent | next_probe_mask)) begin
                    next_state = hit ? ST_WAIT_ACK : ST_EVICT_WAIT;
                end
            end
        end else begin
            next_state = hit ? ST_GRANT : ST_MEM_READ;
        end
    end

endmodule
