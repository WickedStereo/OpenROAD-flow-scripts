`timescale 1ns/1ps

module rv64_l2_dir_lookup #(
    parameter CORES = 4,
    parameter WAYS = 8
) (
    input  wire [49:0] req_tag,
    input  wire [WAYS-1:0] dir_rd_valid,
    input  wire [WAYS*CORES-1:0] dir_rd_sharers,
    input  wire [WAYS-1:0] dir_rd_owner_valid,
    input  wire [WAYS*$clog2(CORES)-1:0] dir_rd_owner_id,
    input  wire [WAYS-1:0] dir_rd_dirty,
    input  wire [WAYS*50-1:0] tag_way_flat,
    output reg         hit,
    output reg  [3:0]  hit_way,
    output reg  [CORES-1:0] hit_sharers,
    output reg         hit_owner_valid,
    output reg  [$clog2(CORES)-1:0] hit_owner_id,
    output reg         hit_dirty
);

    integer way_idx;
    reg [49:0] current_tag;

    always @* begin
        hit = 1'b0;
        hit_way = 4'd0;
        hit_sharers = {CORES{1'b0}};
        hit_owner_valid = 1'b0;
        hit_owner_id = {($clog2(CORES)){1'b0}};
        hit_dirty = 1'b0;

        for (way_idx = 0; way_idx < WAYS; way_idx = way_idx + 1) begin
            current_tag = tag_way_flat[way_idx*50 +: 50];
            if (dir_rd_valid[way_idx] && current_tag == req_tag) begin
                hit = 1'b1;
                hit_way = way_idx[3:0];
                hit_sharers = dir_rd_sharers[way_idx*CORES +: CORES];
                hit_owner_valid = dir_rd_owner_valid[way_idx];
                hit_owner_id = dir_rd_owner_id[way_idx*$clog2(CORES) +: $clog2(CORES)];
                hit_dirty = dir_rd_dirty[way_idx];
            end
        end
    end

endmodule
