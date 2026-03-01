`timescale 1ns/1ps

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

    reg                     processing_release_q;
    reg [2:0]               req_opcode_q;
    reg [2:0]               req_param_q;
    reg [SOURCE_W-1:0]      req_source_q;
    reg [63:0]              req_addr_q;
    reg [CID_W-1:0]         req_core_id_q;
    reg [2:0]               burst_cnt_q;
    reg                     d_ready_q;
    reg [63:0]              data_rdata_q;
    reg                     latched_hit_q;
    reg [3:0]               latched_hit_way_q;
    reg [3:0]               victim_way_q;
    reg [CORES-1:0]         hit_sharers_q;
    reg                     hit_owner_valid_q;
    reg [CID_W-1:0]         hit_owner_id_q;
    reg                     hit_dirty_q;

    wire                    engine_grant_d_valid;
    wire [2:0]              engine_grant_d_opcode;
    wire [1:0]              engine_grant_d_param;
    wire [63:0]             engine_grant_d_data;
    wire [SOURCE_W-1:0]     engine_grant_d_source;
    wire [7:0]              engine_grant_data_set;
    wire [3:0]              engine_grant_data_way;
    wire [2:0]              engine_grant_data_word_sel;
    wire [3:0]              engine_grant_tag_way;
    wire                    engine_grant_drive_data_read;
    wire [STATE_W-1:0]      engine_grant_next_state;
    wire                    engine_update_dir_we;
    wire                    engine_update_dir_wr_valid;
    wire [CORES-1:0]        engine_update_dir_wr_sharers;
    wire                    engine_update_dir_wr_owner_valid;
    wire [CID_W-1:0]        engine_update_dir_wr_owner_id;
    wire                    engine_update_dir_wr_dirty;
    wire                    engine_update_tag_we;
    wire [STATE_W-1:0]      engine_update_next_state;

    rv64_l2_grant_update_engine #(
        .CORES(CORES),
        .SOURCE_W(SOURCE_W),
        .CID_W(CID_W),
        .STATE_W(STATE_W)
    ) engine (
        .processing_release(processing_release_q),
        .req_opcode(req_opcode_q),
        .req_param(req_param_q),
        .req_source(req_source_q),
        .req_addr(req_addr_q),
        .req_core_id(req_core_id_q),
        .burst_cnt(burst_cnt_q),
        .d_ready(d_ready_q),
        .data_rdata(data_rdata_q),
        .latched_hit(latched_hit_q),
        .latched_hit_way(latched_hit_way_q),
        .victim_way(victim_way_q),
        .hit_sharers(hit_sharers_q),
        .hit_owner_valid(hit_owner_valid_q),
        .hit_owner_id(hit_owner_id_q),
        .hit_dirty(hit_dirty_q),
        .grant_d_valid(engine_grant_d_valid),
        .grant_d_opcode(engine_grant_d_opcode),
        .grant_d_param(engine_grant_d_param),
        .grant_d_data(engine_grant_d_data),
        .grant_d_source(engine_grant_d_source),
        .grant_data_set(engine_grant_data_set),
        .grant_data_way(engine_grant_data_way),
        .grant_data_word_sel(engine_grant_data_word_sel),
        .grant_tag_way(engine_grant_tag_way),
        .grant_drive_data_read(engine_grant_drive_data_read),
        .grant_next_state(engine_grant_next_state),
        .update_dir_we(engine_update_dir_we),
        .update_dir_wr_valid(engine_update_dir_wr_valid),
        .update_dir_wr_sharers(engine_update_dir_wr_sharers),
        .update_dir_wr_owner_valid(engine_update_dir_wr_owner_valid),
        .update_dir_wr_owner_id(engine_update_dir_wr_owner_id),
        .update_dir_wr_dirty(engine_update_dir_wr_dirty),
        .update_tag_we(engine_update_tag_we),
        .update_next_state(engine_update_next_state)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing_release_q <= 1'b0;
            req_opcode_q <= 3'd0;
            req_param_q <= 3'd0;
            req_source_q <= {SOURCE_W{1'b0}};
            req_addr_q <= 64'd0;
            req_core_id_q <= {CID_W{1'b0}};
            burst_cnt_q <= 3'd0;
            d_ready_q <= 1'b0;
            data_rdata_q <= 64'd0;
            latched_hit_q <= 1'b0;
            latched_hit_way_q <= 4'd0;
            victim_way_q <= 4'd0;
            hit_sharers_q <= {CORES{1'b0}};
            hit_owner_valid_q <= 1'b0;
            hit_owner_id_q <= {CID_W{1'b0}};
            hit_dirty_q <= 1'b0;
            grant_d_valid <= 1'b0;
            grant_d_opcode <= 3'd0;
            grant_d_param <= 2'd0;
            grant_d_data <= 64'd0;
            grant_d_source <= {SOURCE_W{1'b0}};
            grant_data_set <= 8'd0;
            grant_data_way <= 4'd0;
            grant_data_word_sel <= 3'd0;
            grant_tag_way <= 4'd0;
            grant_drive_data_read <= 1'b0;
            grant_next_state <= {STATE_W{1'b0}};
            update_dir_we <= 1'b0;
            update_dir_wr_valid <= 1'b0;
            update_dir_wr_sharers <= {CORES{1'b0}};
            update_dir_wr_owner_valid <= 1'b0;
            update_dir_wr_owner_id <= {CID_W{1'b0}};
            update_dir_wr_dirty <= 1'b0;
            update_tag_we <= 1'b0;
            update_next_state <= {STATE_W{1'b0}};
        end else begin
            processing_release_q <= processing_release;
            req_opcode_q <= req_opcode;
            req_param_q <= req_param;
            req_source_q <= req_source;
            req_addr_q <= req_addr;
            req_core_id_q <= req_core_id;
            burst_cnt_q <= burst_cnt;
            d_ready_q <= d_ready;
            data_rdata_q <= data_rdata;
            latched_hit_q <= latched_hit;
            latched_hit_way_q <= latched_hit_way;
            victim_way_q <= victim_way;
            hit_sharers_q <= hit_sharers;
            hit_owner_valid_q <= hit_owner_valid;
            hit_owner_id_q <= hit_owner_id;
            hit_dirty_q <= hit_dirty;
            grant_d_valid <= engine_grant_d_valid;
            grant_d_opcode <= engine_grant_d_opcode;
            grant_d_param <= engine_grant_d_param;
            grant_d_data <= engine_grant_d_data;
            grant_d_source <= engine_grant_d_source;
            grant_data_set <= engine_grant_data_set;
            grant_data_way <= engine_grant_data_way;
            grant_data_word_sel <= engine_grant_data_word_sel;
            grant_tag_way <= engine_grant_tag_way;
            grant_drive_data_read <= engine_grant_drive_data_read;
            grant_next_state <= engine_grant_next_state;
            update_dir_we <= engine_update_dir_we;
            update_dir_wr_valid <= engine_update_dir_wr_valid;
            update_dir_wr_sharers <= engine_update_dir_wr_sharers;
            update_dir_wr_owner_valid <= engine_update_dir_wr_owner_valid;
            update_dir_wr_owner_id <= engine_update_dir_wr_owner_id;
            update_dir_wr_dirty <= engine_update_dir_wr_dirty;
            update_tag_we <= engine_update_tag_we;
            update_next_state <= engine_update_next_state;
        end
    end

endmodule
