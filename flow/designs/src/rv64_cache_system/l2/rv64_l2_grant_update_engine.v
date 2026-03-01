`timescale 1ns/1ps

module rv64_l2_grant_update_engine #(
    parameter CORES = 4,
    parameter SOURCE_W = 6,
    parameter CID_W = 2,
    parameter STATE_W = 4,
    parameter [STATE_W-1:0] ST_GRANT    = 4'd4,
    parameter [STATE_W-1:0] ST_UPDATE   = 4'd5,
    parameter [STATE_W-1:0] ST_COMPLETE = 4'd6
) (
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

    output reg                      grant_d_valid,
    output reg  [2:0]               grant_d_opcode,
    output reg  [1:0]               grant_d_param,
    output reg  [63:0]              grant_d_data,
    output reg  [SOURCE_W-1:0]      grant_d_source,
    output reg  [7:0]               grant_data_set,
    output reg  [3:0]               grant_data_way,
    output reg  [2:0]               grant_data_word_sel,
    output reg  [3:0]               grant_tag_way,
    output reg                      grant_drive_data_read,
    output reg  [STATE_W-1:0]       grant_next_state,

    output reg                      update_dir_we,
    output reg                      update_dir_wr_valid,
    output reg  [CORES-1:0]         update_dir_wr_sharers,
    output reg                      update_dir_wr_owner_valid,
    output reg  [CID_W-1:0]         update_dir_wr_owner_id,
    output reg                      update_dir_wr_dirty,
    output reg                      update_tag_we,
    output reg  [STATE_W-1:0]       update_next_state
);

    always @* begin
        grant_d_valid = 1'b1;
        grant_d_opcode = 3'd0;
        grant_d_param = 2'd0;
        grant_d_data = 64'd0;
        grant_d_source = req_source;
        grant_data_set = req_addr[13:6];
        grant_data_way = latched_hit ? latched_hit_way : victim_way;
        grant_data_word_sel = burst_cnt;
        grant_tag_way = latched_hit ? latched_hit_way : victim_way;
        grant_drive_data_read = 1'b0;
        grant_next_state = ST_GRANT;

        if (processing_release) begin
            grant_d_opcode = 3'd6;
            grant_d_param = 2'd0;
            grant_d_data = 64'd0;
            if (d_ready) begin
                grant_next_state = ST_COMPLETE;
            end
        end else begin
            if (req_opcode == 3'd6) begin
                grant_d_opcode = 3'd5;
                grant_d_param = 2'd1;
                grant_drive_data_read = 1'b1;
                grant_d_data = data_rdata;
                if (d_ready && (burst_cnt == 3'd7)) begin
                    grant_next_state = ST_UPDATE;
                end
            end else begin
                grant_d_opcode = 3'd4;
                grant_d_param = 2'd2;
                grant_d_data = 64'd0;
                if (d_ready) begin
                    grant_next_state = ST_UPDATE;
                end
            end
        end
    end

    always @* begin
        update_dir_we = 1'b1;
        update_dir_wr_valid = 1'b1;
        update_dir_wr_sharers = {CORES{1'b0}};
        update_dir_wr_owner_valid = 1'b0;
        update_dir_wr_owner_id = {CID_W{1'b0}};
        update_dir_wr_dirty = 1'b0;
        update_tag_we = !latched_hit && !processing_release;
        update_next_state = ST_COMPLETE;

        if (processing_release) begin
            update_dir_wr_sharers = hit_sharers & ~( {{(CORES-1){1'b0}}, 1'b1} << req_core_id );
            if (hit_owner_valid && (hit_owner_id == req_core_id)) begin
                update_dir_wr_owner_valid = 1'b0;
                update_dir_wr_owner_id = {CID_W{1'b0}};
                update_dir_wr_dirty = 1'b0;
            end else begin
                update_dir_wr_owner_valid = hit_owner_valid;
                update_dir_wr_owner_id = hit_owner_id;
                update_dir_wr_dirty = hit_dirty;
            end
            update_next_state = ST_GRANT;
        end else begin
            if (req_opcode == 3'd6) begin
                if (req_param == 3'd0) begin
                    update_dir_wr_sharers = hit_sharers | ({{(CORES-1){1'b0}}, 1'b1} << req_core_id);
                    update_dir_wr_owner_valid = hit_owner_valid;
                    update_dir_wr_owner_id = hit_owner_id;
                    update_dir_wr_dirty = hit_dirty;
                end else begin
                    update_dir_wr_sharers = ({{(CORES-1){1'b0}}, 1'b1} << req_core_id);
                    update_dir_wr_owner_valid = 1'b1;
                    update_dir_wr_owner_id = req_core_id;
                    update_dir_wr_dirty = 1'b1;
                end
            end else begin
                update_dir_wr_sharers = ({{(CORES-1){1'b0}}, 1'b1} << req_core_id);
                update_dir_wr_owner_valid = 1'b1;
                update_dir_wr_owner_id = req_core_id;
                update_dir_wr_dirty = 1'b1;
            end
        end
    end

endmodule
