`timescale 1ns/1ps
`include "params.vh"

module rv64_l1_arrays_sram (
	input               clk,
	input               rst_n,
	input               invalidate_all,
	input       [4:0]   index,
	input       [2:0]   word_sel,
	input       [2:0]   way_sel,
	input               write_en,
	input       [1:0]   state,
	input       [7:0]   be,
	input      [52:0]   tag_in,
	input      [63:0]   wdata,
	output     [63:0]   rdata_selected,
	output     [52:0]   tag_selected,
	output     [1:0]    state_selected,
	output [8*64-1:0]   rdata_way_flat,
	output [8*53-1:0]   tag_way_flat,
	output [8*2-1:0]    state_way_flat
);

	reg [1:0] state_q[0:7][0:31];
	assign state_selected = state_q[way_sel][index];
	assign state_way_flat[1:0] = state_q[0][index];
	assign state_way_flat[3:2] = state_q[1][index];
	assign state_way_flat[5:4] = state_q[2][index];
	assign state_way_flat[7:6] = state_q[3][index];
	assign state_way_flat[9:8] = state_q[4][index];
	assign state_way_flat[11:10] = state_q[5][index];
	assign state_way_flat[13:12] = state_q[6][index];
	assign state_way_flat[15:14] = state_q[7][index];
	integer i, j;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			for (i = 0; i < 8; i = i + 1) begin
				for (j = 0; j < 32; j = j + 1) begin
					state_q[i][j] <= 2'b0; // MESI_N = 0
				end
			end
		end else if (invalidate_all) begin
			for (i = 0; i < 8; i = i + 1) begin
				for (j = 0; j < 32; j = j + 1) begin
					state_q[i][j] <= 2'b0;
				end
			end
		end else if (write_en) begin
			state_q[way_sel][index] <= state;
		end
	end
	// Tag Array: 8 ways * 53 bits (Macro: 80x64)
	wire [79:0] tag_dout_0;
	assign tag_way_flat[52:0] = tag_dout_0[52:0];
	wire tag_we_0 = write_en & (way_sel == 3'd0);
	sky130_sram_1rw1r_80x64_8 tag_sram_0 (
		.clk0(clk), .csb0(~tag_we_0), .web0(~tag_we_0),
		.wmask0(10'h3FF), .addr0({1'b0, index}), .din0({27'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({1'b0, index}), .dout1(tag_dout_0)
	);
	wire [79:0] tag_dout_1;
	assign tag_way_flat[105:53] = tag_dout_1[52:0];
	wire tag_we_1 = write_en & (way_sel == 3'd1);
	sky130_sram_1rw1r_80x64_8 tag_sram_1 (
		.clk0(clk), .csb0(~tag_we_1), .web0(~tag_we_1),
		.wmask0(10'h3FF), .addr0({1'b0, index}), .din0({27'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({1'b0, index}), .dout1(tag_dout_1)
	);
	wire [79:0] tag_dout_2;
	assign tag_way_flat[158:106] = tag_dout_2[52:0];
	wire tag_we_2 = write_en & (way_sel == 3'd2);
	sky130_sram_1rw1r_80x64_8 tag_sram_2 (
		.clk0(clk), .csb0(~tag_we_2), .web0(~tag_we_2),
		.wmask0(10'h3FF), .addr0({1'b0, index}), .din0({27'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({1'b0, index}), .dout1(tag_dout_2)
	);
	wire [79:0] tag_dout_3;
	assign tag_way_flat[211:159] = tag_dout_3[52:0];
	wire tag_we_3 = write_en & (way_sel == 3'd3);
	sky130_sram_1rw1r_80x64_8 tag_sram_3 (
		.clk0(clk), .csb0(~tag_we_3), .web0(~tag_we_3),
		.wmask0(10'h3FF), .addr0({1'b0, index}), .din0({27'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({1'b0, index}), .dout1(tag_dout_3)
	);
	wire [79:0] tag_dout_4;
	assign tag_way_flat[264:212] = tag_dout_4[52:0];
	wire tag_we_4 = write_en & (way_sel == 3'd4);
	sky130_sram_1rw1r_80x64_8 tag_sram_4 (
		.clk0(clk), .csb0(~tag_we_4), .web0(~tag_we_4),
		.wmask0(10'h3FF), .addr0({1'b0, index}), .din0({27'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({1'b0, index}), .dout1(tag_dout_4)
	);
	wire [79:0] tag_dout_5;
	assign tag_way_flat[317:265] = tag_dout_5[52:0];
	wire tag_we_5 = write_en & (way_sel == 3'd5);
	sky130_sram_1rw1r_80x64_8 tag_sram_5 (
		.clk0(clk), .csb0(~tag_we_5), .web0(~tag_we_5),
		.wmask0(10'h3FF), .addr0({1'b0, index}), .din0({27'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({1'b0, index}), .dout1(tag_dout_5)
	);
	wire [79:0] tag_dout_6;
	assign tag_way_flat[370:318] = tag_dout_6[52:0];
	wire tag_we_6 = write_en & (way_sel == 3'd6);
	sky130_sram_1rw1r_80x64_8 tag_sram_6 (
		.clk0(clk), .csb0(~tag_we_6), .web0(~tag_we_6),
		.wmask0(10'h3FF), .addr0({1'b0, index}), .din0({27'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({1'b0, index}), .dout1(tag_dout_6)
	);
	wire [79:0] tag_dout_7;
	assign tag_way_flat[423:371] = tag_dout_7[52:0];
	wire tag_we_7 = write_en & (way_sel == 3'd7);
	sky130_sram_1rw1r_80x64_8 tag_sram_7 (
		.clk0(clk), .csb0(~tag_we_7), .web0(~tag_we_7),
		.wmask0(10'h3FF), .addr0({1'b0, index}), .din0({27'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({1'b0, index}), .dout1(tag_dout_7)
	);

	// Data Array: 8 ways * 64 bits (Macro: 64x256) indexed by {index, word_sel}
	wire [63:0] data_dout_0;
	assign rdata_way_flat[63:0] = data_dout_0;
	wire data_we_0 = write_en & (way_sel == 3'd0);
	sky130_sram_1rw1r_64x256_8 data_sram_0 (
		.clk0(clk), .csb0(~data_we_0), .web0(~data_we_0),
		.wmask0(be), .addr0({index, word_sel}), .din0(wdata), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({index, word_sel}), .dout1(data_dout_0)
	);
	wire [63:0] data_dout_1;
	assign rdata_way_flat[127:64] = data_dout_1;
	wire data_we_1 = write_en & (way_sel == 3'd1);
	sky130_sram_1rw1r_64x256_8 data_sram_1 (
		.clk0(clk), .csb0(~data_we_1), .web0(~data_we_1),
		.wmask0(be), .addr0({index, word_sel}), .din0(wdata), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({index, word_sel}), .dout1(data_dout_1)
	);
	wire [63:0] data_dout_2;
	assign rdata_way_flat[191:128] = data_dout_2;
	wire data_we_2 = write_en & (way_sel == 3'd2);
	sky130_sram_1rw1r_64x256_8 data_sram_2 (
		.clk0(clk), .csb0(~data_we_2), .web0(~data_we_2),
		.wmask0(be), .addr0({index, word_sel}), .din0(wdata), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({index, word_sel}), .dout1(data_dout_2)
	);
	wire [63:0] data_dout_3;
	assign rdata_way_flat[255:192] = data_dout_3;
	wire data_we_3 = write_en & (way_sel == 3'd3);
	sky130_sram_1rw1r_64x256_8 data_sram_3 (
		.clk0(clk), .csb0(~data_we_3), .web0(~data_we_3),
		.wmask0(be), .addr0({index, word_sel}), .din0(wdata), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({index, word_sel}), .dout1(data_dout_3)
	);
	wire [63:0] data_dout_4;
	assign rdata_way_flat[319:256] = data_dout_4;
	wire data_we_4 = write_en & (way_sel == 3'd4);
	sky130_sram_1rw1r_64x256_8 data_sram_4 (
		.clk0(clk), .csb0(~data_we_4), .web0(~data_we_4),
		.wmask0(be), .addr0({index, word_sel}), .din0(wdata), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({index, word_sel}), .dout1(data_dout_4)
	);
	wire [63:0] data_dout_5;
	assign rdata_way_flat[383:320] = data_dout_5;
	wire data_we_5 = write_en & (way_sel == 3'd5);
	sky130_sram_1rw1r_64x256_8 data_sram_5 (
		.clk0(clk), .csb0(~data_we_5), .web0(~data_we_5),
		.wmask0(be), .addr0({index, word_sel}), .din0(wdata), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({index, word_sel}), .dout1(data_dout_5)
	);
	wire [63:0] data_dout_6;
	assign rdata_way_flat[447:384] = data_dout_6;
	wire data_we_6 = write_en & (way_sel == 3'd6);
	sky130_sram_1rw1r_64x256_8 data_sram_6 (
		.clk0(clk), .csb0(~data_we_6), .web0(~data_we_6),
		.wmask0(be), .addr0({index, word_sel}), .din0(wdata), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({index, word_sel}), .dout1(data_dout_6)
	);
	wire [63:0] data_dout_7;
	assign rdata_way_flat[511:448] = data_dout_7;
	wire data_we_7 = write_en & (way_sel == 3'd7);
	sky130_sram_1rw1r_64x256_8 data_sram_7 (
		.clk0(clk), .csb0(~data_we_7), .web0(~data_we_7),
		.wmask0(be), .addr0({index, word_sel}), .din0(wdata), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1({index, word_sel}), .dout1(data_dout_7)
	);

	assign rdata_selected = 
		(way_sel == 3'd0) ? data_dout_0 : 
		(way_sel == 3'd1) ? data_dout_1 : 
		(way_sel == 3'd2) ? data_dout_2 : 
		(way_sel == 3'd3) ? data_dout_3 : 
		(way_sel == 3'd4) ? data_dout_4 : 
		(way_sel == 3'd5) ? data_dout_5 : 
		(way_sel == 3'd6) ? data_dout_6 : 
		(way_sel == 3'd7) ? data_dout_7 : 
		64'b0;

	assign tag_selected = 
		(way_sel == 3'd0) ? tag_dout_0[52:0] : 
		(way_sel == 3'd1) ? tag_dout_1[52:0] : 
		(way_sel == 3'd2) ? tag_dout_2[52:0] : 
		(way_sel == 3'd3) ? tag_dout_3[52:0] : 
		(way_sel == 3'd4) ? tag_dout_4[52:0] : 
		(way_sel == 3'd5) ? tag_dout_5[52:0] : 
		(way_sel == 3'd6) ? tag_dout_6[52:0] : 
		(way_sel == 3'd7) ? tag_dout_7[52:0] : 
		53'b0;
endmodule
