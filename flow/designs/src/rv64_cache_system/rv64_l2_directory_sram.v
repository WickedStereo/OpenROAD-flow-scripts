`timescale 1ns/1ps
`include "params.vh"

module rv64_l2_directory_sram #(
	parameter SETS = 256,
	parameter WAYS = 8,
	parameter CORES = 4
) (
	input  wire clk,
	input  wire rst_n,
	input  wire [7:0]               rd_set,
	output wire [7:0]              rd_valid,
	output wire [31:0]              rd_sharers,
	output wire [7:0]              rd_owner_valid,
	output wire [15:0]              rd_owner_id,
	output wire [7:0]              rd_dirty,
	input  wire                     we,
	input  wire [7:0]               wr_set,
	input  wire [2:0]               wr_way,
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

	// All 8 ways fit in 1 macro (128x256): 8 * 16 bits = 128 bits <= 128 bits.
	wire [15:0] wr_wmask_0 = we ? (16'h0003 << (wr_way * 2)) : 16'h0000;
	wire [127:0] wr_din_0;
	assign wr_din_0[15:0] = {7'b0, wr_entry_packed};
	assign wr_din_0[31:16] = {7'b0, wr_entry_packed};
	assign wr_din_0[47:32] = {7'b0, wr_entry_packed};
	assign wr_din_0[63:48] = {7'b0, wr_entry_packed};
	assign wr_din_0[79:64] = {7'b0, wr_entry_packed};
	assign wr_din_0[95:80] = {7'b0, wr_entry_packed};
	assign wr_din_0[111:96] = {7'b0, wr_entry_packed};
	assign wr_din_0[127:112] = {7'b0, wr_entry_packed};

	wire [127:0] dout_0;
	wire csb_write_0 = ~we;
	sky130_sram_1rw1r_128x256_8 dir_sram_0 (
		.clk0(clk), .csb0(csb_write_0), .web0(csb_write_0),
		.wmask0(wr_wmask_0), .addr0(wr_set), .din0(wr_din_0), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(rd_set), .dout1(dout_0)
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
endmodule
