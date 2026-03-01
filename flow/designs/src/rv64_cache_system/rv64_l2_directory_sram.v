`timescale 1ns/1ps
`include "params.vh"

module rv64_l2_directory_sram #(
	parameter SETS = 256,
	parameter WAYS = 16,
	parameter CORES = 4
) (
	input  wire clk,
	input  wire rst_n,
	input  wire [7:0]               rd_set,
	output wire [15:0]              rd_valid,
	output wire [63:0]              rd_sharers,
	output wire [15:0]              rd_owner_valid,
	output wire [31:0]              rd_owner_id,
	output wire [15:0]              rd_dirty,
	input  wire                     we,
	input  wire [7:0]               wr_set,
	input  wire [3:0]               wr_way,
	input  wire                     wr_valid,
	input  wire [3:0]               wr_sharers,
	input  wire                     wr_owner_valid,
	input  wire [1:0]               wr_owner_id,
	input  wire                     wr_dirty
);

	wire safe_valid = wr_valid;
	wire safe_owner_valid = wr_dirty ? 1'b1 : wr_owner_valid;
	wire [3:0] safe_sharers = safe_owner_valid ? 4'b0 : wr_sharers;
	wire [1:0] safe_owner_id = wr_owner_id;
	wire safe_dirty = wr_dirty;

	wire [8:0] wr_entry_packed = {safe_dirty, safe_owner_id, safe_owner_valid, safe_sharers, safe_valid};

	// Each entry is 16 bits. Ways 0..7 go to macro 0, Ways 8..15 go to macro 1.
	wire [15:0] wr_wmask_0 = (we && ~wr_way[3]) ? (16'h0003 << (wr_way[2:0] * 2)) : 16'h0000;
	wire [15:0] wr_wmask_1 = (we &&  wr_way[3]) ? (16'h0003 << (wr_way[2:0] * 2)) : 16'h0000;
	wire [127:0] wr_din_0;
	wire [127:0] wr_din_1;
	assign wr_din_0[15:0] = {7'b0, wr_entry_packed};
	assign wr_din_1[15:0] = {7'b0, wr_entry_packed};
	assign wr_din_0[31:16] = {7'b0, wr_entry_packed};
	assign wr_din_1[31:16] = {7'b0, wr_entry_packed};
	assign wr_din_0[47:32] = {7'b0, wr_entry_packed};
	assign wr_din_1[47:32] = {7'b0, wr_entry_packed};
	assign wr_din_0[63:48] = {7'b0, wr_entry_packed};
	assign wr_din_1[63:48] = {7'b0, wr_entry_packed};
	assign wr_din_0[79:64] = {7'b0, wr_entry_packed};
	assign wr_din_1[79:64] = {7'b0, wr_entry_packed};
	assign wr_din_0[95:80] = {7'b0, wr_entry_packed};
	assign wr_din_1[95:80] = {7'b0, wr_entry_packed};
	assign wr_din_0[111:96] = {7'b0, wr_entry_packed};
	assign wr_din_1[111:96] = {7'b0, wr_entry_packed};
	assign wr_din_0[127:112] = {7'b0, wr_entry_packed};
	assign wr_din_1[127:112] = {7'b0, wr_entry_packed};

	wire [127:0] dout_0;
	wire [127:0] dout_1;

	wire csb_write_0 = ~(we & ~wr_way[3]);
	wire csb_write_1 = ~(we &  wr_way[3]);
	sky130_sram_1rw1r_128x256_8 dir_sram_0 (
		.clk0(clk), .csb0(csb_write_0), .web0(csb_write_0),
		.wmask0(wr_wmask_0), .addr0(wr_set), .din0(wr_din_0), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(rd_set), .dout1(dout_0)
	);

	sky130_sram_1rw1r_128x256_8 dir_sram_1 (
		.clk0(clk), .csb0(csb_write_1), .web0(csb_write_1),
		.wmask0(wr_wmask_1), .addr0(wr_set), .din0(wr_din_1), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(rd_set), .dout1(dout_1)
	);
	wire [8:0] rd_entry_0 = dout_0[8:0];
	assign rd_valid[0] = rd_entry_0[0];
	assign rd_sharers[3:0] = rd_entry_0[4:1];
	assign rd_owner_valid[0] = rd_entry_0[5];
	assign rd_owner_id[1:0] = rd_entry_0[7:6];
	assign rd_dirty[0] = rd_entry_0[8];
	wire [8:0] rd_entry_1 = dout_0[24:16];
	assign rd_valid[1] = rd_entry_1[0];
	assign rd_sharers[7:4] = rd_entry_1[4:1];
	assign rd_owner_valid[1] = rd_entry_1[5];
	assign rd_owner_id[3:2] = rd_entry_1[7:6];
	assign rd_dirty[1] = rd_entry_1[8];
	wire [8:0] rd_entry_2 = dout_0[40:32];
	assign rd_valid[2] = rd_entry_2[0];
	assign rd_sharers[11:8] = rd_entry_2[4:1];
	assign rd_owner_valid[2] = rd_entry_2[5];
	assign rd_owner_id[5:4] = rd_entry_2[7:6];
	assign rd_dirty[2] = rd_entry_2[8];
	wire [8:0] rd_entry_3 = dout_0[56:48];
	assign rd_valid[3] = rd_entry_3[0];
	assign rd_sharers[15:12] = rd_entry_3[4:1];
	assign rd_owner_valid[3] = rd_entry_3[5];
	assign rd_owner_id[7:6] = rd_entry_3[7:6];
	assign rd_dirty[3] = rd_entry_3[8];
	wire [8:0] rd_entry_4 = dout_0[72:64];
	assign rd_valid[4] = rd_entry_4[0];
	assign rd_sharers[19:16] = rd_entry_4[4:1];
	assign rd_owner_valid[4] = rd_entry_4[5];
	assign rd_owner_id[9:8] = rd_entry_4[7:6];
	assign rd_dirty[4] = rd_entry_4[8];
	wire [8:0] rd_entry_5 = dout_0[88:80];
	assign rd_valid[5] = rd_entry_5[0];
	assign rd_sharers[23:20] = rd_entry_5[4:1];
	assign rd_owner_valid[5] = rd_entry_5[5];
	assign rd_owner_id[11:10] = rd_entry_5[7:6];
	assign rd_dirty[5] = rd_entry_5[8];
	wire [8:0] rd_entry_6 = dout_0[104:96];
	assign rd_valid[6] = rd_entry_6[0];
	assign rd_sharers[27:24] = rd_entry_6[4:1];
	assign rd_owner_valid[6] = rd_entry_6[5];
	assign rd_owner_id[13:12] = rd_entry_6[7:6];
	assign rd_dirty[6] = rd_entry_6[8];
	wire [8:0] rd_entry_7 = dout_0[120:112];
	assign rd_valid[7] = rd_entry_7[0];
	assign rd_sharers[31:28] = rd_entry_7[4:1];
	assign rd_owner_valid[7] = rd_entry_7[5];
	assign rd_owner_id[15:14] = rd_entry_7[7:6];
	assign rd_dirty[7] = rd_entry_7[8];
	wire [8:0] rd_entry_8 = dout_1[8:0];
	assign rd_valid[8] = rd_entry_8[0];
	assign rd_sharers[35:32] = rd_entry_8[4:1];
	assign rd_owner_valid[8] = rd_entry_8[5];
	assign rd_owner_id[17:16] = rd_entry_8[7:6];
	assign rd_dirty[8] = rd_entry_8[8];
	wire [8:0] rd_entry_9 = dout_1[24:16];
	assign rd_valid[9] = rd_entry_9[0];
	assign rd_sharers[39:36] = rd_entry_9[4:1];
	assign rd_owner_valid[9] = rd_entry_9[5];
	assign rd_owner_id[19:18] = rd_entry_9[7:6];
	assign rd_dirty[9] = rd_entry_9[8];
	wire [8:0] rd_entry_10 = dout_1[40:32];
	assign rd_valid[10] = rd_entry_10[0];
	assign rd_sharers[43:40] = rd_entry_10[4:1];
	assign rd_owner_valid[10] = rd_entry_10[5];
	assign rd_owner_id[21:20] = rd_entry_10[7:6];
	assign rd_dirty[10] = rd_entry_10[8];
	wire [8:0] rd_entry_11 = dout_1[56:48];
	assign rd_valid[11] = rd_entry_11[0];
	assign rd_sharers[47:44] = rd_entry_11[4:1];
	assign rd_owner_valid[11] = rd_entry_11[5];
	assign rd_owner_id[23:22] = rd_entry_11[7:6];
	assign rd_dirty[11] = rd_entry_11[8];
	wire [8:0] rd_entry_12 = dout_1[72:64];
	assign rd_valid[12] = rd_entry_12[0];
	assign rd_sharers[51:48] = rd_entry_12[4:1];
	assign rd_owner_valid[12] = rd_entry_12[5];
	assign rd_owner_id[25:24] = rd_entry_12[7:6];
	assign rd_dirty[12] = rd_entry_12[8];
	wire [8:0] rd_entry_13 = dout_1[88:80];
	assign rd_valid[13] = rd_entry_13[0];
	assign rd_sharers[55:52] = rd_entry_13[4:1];
	assign rd_owner_valid[13] = rd_entry_13[5];
	assign rd_owner_id[27:26] = rd_entry_13[7:6];
	assign rd_dirty[13] = rd_entry_13[8];
	wire [8:0] rd_entry_14 = dout_1[104:96];
	assign rd_valid[14] = rd_entry_14[0];
	assign rd_sharers[59:56] = rd_entry_14[4:1];
	assign rd_owner_valid[14] = rd_entry_14[5];
	assign rd_owner_id[29:28] = rd_entry_14[7:6];
	assign rd_dirty[14] = rd_entry_14[8];
	wire [8:0] rd_entry_15 = dout_1[120:112];
	assign rd_valid[15] = rd_entry_15[0];
	assign rd_sharers[63:60] = rd_entry_15[4:1];
	assign rd_owner_valid[15] = rd_entry_15[5];
	assign rd_owner_id[31:30] = rd_entry_15[7:6];
	assign rd_dirty[15] = rd_entry_15[8];
endmodule
