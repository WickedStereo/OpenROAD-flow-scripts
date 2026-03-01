`timescale 1ns/1ps
`include "params.vh"

module rv64_l2_arrays_sram (
	input               clk,
	input               rst_n,
	input       [7:0]   index,
	input       [2:0]   word_sel,
	input       [3:0]   way_sel,
	input               data_we,
	input               tag_we,
	input       [7:0]   be,
	input      [49:0]   tag_in,
	input      [63:0]   wdata,
	output     [63:0]   rdata_selected,
	output     [49:0]   tag_selected,
	output [16*64-1:0]  rdata_way_flat,
	output [16*50-1:0]  tag_way_flat
);

	// Tag Array: 16 ways * 50 bits. Macro: 64x256. 1 per way -> 16 macros.
	wire [63:0] tag_dout_0;
	assign tag_way_flat[49:0] = tag_dout_0[49:0];
	wire tag_we_0 = tag_we & (way_sel == 4'd0);
	sky130_sram_1rw1r_64x256_8 tag_sram_0 (
		.clk0(clk), .csb0(~tag_we_0), .web0(~tag_we_0),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_0)
	);
	wire [63:0] tag_dout_1;
	assign tag_way_flat[99:50] = tag_dout_1[49:0];
	wire tag_we_1 = tag_we & (way_sel == 4'd1);
	sky130_sram_1rw1r_64x256_8 tag_sram_1 (
		.clk0(clk), .csb0(~tag_we_1), .web0(~tag_we_1),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_1)
	);
	wire [63:0] tag_dout_2;
	assign tag_way_flat[149:100] = tag_dout_2[49:0];
	wire tag_we_2 = tag_we & (way_sel == 4'd2);
	sky130_sram_1rw1r_64x256_8 tag_sram_2 (
		.clk0(clk), .csb0(~tag_we_2), .web0(~tag_we_2),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_2)
	);
	wire [63:0] tag_dout_3;
	assign tag_way_flat[199:150] = tag_dout_3[49:0];
	wire tag_we_3 = tag_we & (way_sel == 4'd3);
	sky130_sram_1rw1r_64x256_8 tag_sram_3 (
		.clk0(clk), .csb0(~tag_we_3), .web0(~tag_we_3),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_3)
	);
	wire [63:0] tag_dout_4;
	assign tag_way_flat[249:200] = tag_dout_4[49:0];
	wire tag_we_4 = tag_we & (way_sel == 4'd4);
	sky130_sram_1rw1r_64x256_8 tag_sram_4 (
		.clk0(clk), .csb0(~tag_we_4), .web0(~tag_we_4),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_4)
	);
	wire [63:0] tag_dout_5;
	assign tag_way_flat[299:250] = tag_dout_5[49:0];
	wire tag_we_5 = tag_we & (way_sel == 4'd5);
	sky130_sram_1rw1r_64x256_8 tag_sram_5 (
		.clk0(clk), .csb0(~tag_we_5), .web0(~tag_we_5),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_5)
	);
	wire [63:0] tag_dout_6;
	assign tag_way_flat[349:300] = tag_dout_6[49:0];
	wire tag_we_6 = tag_we & (way_sel == 4'd6);
	sky130_sram_1rw1r_64x256_8 tag_sram_6 (
		.clk0(clk), .csb0(~tag_we_6), .web0(~tag_we_6),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_6)
	);
	wire [63:0] tag_dout_7;
	assign tag_way_flat[399:350] = tag_dout_7[49:0];
	wire tag_we_7 = tag_we & (way_sel == 4'd7);
	sky130_sram_1rw1r_64x256_8 tag_sram_7 (
		.clk0(clk), .csb0(~tag_we_7), .web0(~tag_we_7),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_7)
	);
	wire [63:0] tag_dout_8;
	assign tag_way_flat[449:400] = tag_dout_8[49:0];
	wire tag_we_8 = tag_we & (way_sel == 4'd8);
	sky130_sram_1rw1r_64x256_8 tag_sram_8 (
		.clk0(clk), .csb0(~tag_we_8), .web0(~tag_we_8),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_8)
	);
	wire [63:0] tag_dout_9;
	assign tag_way_flat[499:450] = tag_dout_9[49:0];
	wire tag_we_9 = tag_we & (way_sel == 4'd9);
	sky130_sram_1rw1r_64x256_8 tag_sram_9 (
		.clk0(clk), .csb0(~tag_we_9), .web0(~tag_we_9),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_9)
	);
	wire [63:0] tag_dout_10;
	assign tag_way_flat[549:500] = tag_dout_10[49:0];
	wire tag_we_10 = tag_we & (way_sel == 4'd10);
	sky130_sram_1rw1r_64x256_8 tag_sram_10 (
		.clk0(clk), .csb0(~tag_we_10), .web0(~tag_we_10),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_10)
	);
	wire [63:0] tag_dout_11;
	assign tag_way_flat[599:550] = tag_dout_11[49:0];
	wire tag_we_11 = tag_we & (way_sel == 4'd11);
	sky130_sram_1rw1r_64x256_8 tag_sram_11 (
		.clk0(clk), .csb0(~tag_we_11), .web0(~tag_we_11),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_11)
	);
	wire [63:0] tag_dout_12;
	assign tag_way_flat[649:600] = tag_dout_12[49:0];
	wire tag_we_12 = tag_we & (way_sel == 4'd12);
	sky130_sram_1rw1r_64x256_8 tag_sram_12 (
		.clk0(clk), .csb0(~tag_we_12), .web0(~tag_we_12),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_12)
	);
	wire [63:0] tag_dout_13;
	assign tag_way_flat[699:650] = tag_dout_13[49:0];
	wire tag_we_13 = tag_we & (way_sel == 4'd13);
	sky130_sram_1rw1r_64x256_8 tag_sram_13 (
		.clk0(clk), .csb0(~tag_we_13), .web0(~tag_we_13),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_13)
	);
	wire [63:0] tag_dout_14;
	assign tag_way_flat[749:700] = tag_dout_14[49:0];
	wire tag_we_14 = tag_we & (way_sel == 4'd14);
	sky130_sram_1rw1r_64x256_8 tag_sram_14 (
		.clk0(clk), .csb0(~tag_we_14), .web0(~tag_we_14),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_14)
	);
	wire [63:0] tag_dout_15;
	assign tag_way_flat[799:750] = tag_dout_15[49:0];
	wire tag_we_15 = tag_we & (way_sel == 4'd15);
	sky130_sram_1rw1r_64x256_8 tag_sram_15 (
		.clk0(clk), .csb0(~tag_we_15), .web0(~tag_we_15),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_15)
	);

	// Data Array: 16 ways * 8 words * 64 bits.
	// Using 64 instances of 128x256: 8 macros per word_sel.
	wire [127:0] data_dout_0_0;
	wire data_we_0_0 = data_we & (word_sel == 3'd0) & ((way_sel == 4'd0) | (way_sel == 4'd1));
	wire [15:0] data_wmask_0_0 = (way_sel == 4'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_0  = (way_sel == 4'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_0 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_0 (
		.clk0(clk), .csb0(~data_we_0_0), .web0(~data_we_0_0),
		.wmask0(data_wmask_0_0), .addr0(index), .din0(data_din_0_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_0), .addr1(index), .dout1(data_dout_0_0)
	);
	wire [127:0] data_dout_0_1;
	wire data_we_0_1 = data_we & (word_sel == 3'd0) & ((way_sel == 4'd2) | (way_sel == 4'd3));
	wire [15:0] data_wmask_0_1 = (way_sel == 4'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_1  = (way_sel == 4'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_1 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_1 (
		.clk0(clk), .csb0(~data_we_0_1), .web0(~data_we_0_1),
		.wmask0(data_wmask_0_1), .addr0(index), .din0(data_din_0_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_1), .addr1(index), .dout1(data_dout_0_1)
	);
	wire [127:0] data_dout_0_2;
	wire data_we_0_2 = data_we & (word_sel == 3'd0) & ((way_sel == 4'd4) | (way_sel == 4'd5));
	wire [15:0] data_wmask_0_2 = (way_sel == 4'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_2  = (way_sel == 4'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_2 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_2 (
		.clk0(clk), .csb0(~data_we_0_2), .web0(~data_we_0_2),
		.wmask0(data_wmask_0_2), .addr0(index), .din0(data_din_0_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_2), .addr1(index), .dout1(data_dout_0_2)
	);
	wire [127:0] data_dout_0_3;
	wire data_we_0_3 = data_we & (word_sel == 3'd0) & ((way_sel == 4'd6) | (way_sel == 4'd7));
	wire [15:0] data_wmask_0_3 = (way_sel == 4'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_3  = (way_sel == 4'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_3 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_3 (
		.clk0(clk), .csb0(~data_we_0_3), .web0(~data_we_0_3),
		.wmask0(data_wmask_0_3), .addr0(index), .din0(data_din_0_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_3), .addr1(index), .dout1(data_dout_0_3)
	);
	wire [127:0] data_dout_0_4;
	wire data_we_0_4 = data_we & (word_sel == 3'd0) & ((way_sel == 4'd8) | (way_sel == 4'd9));
	wire [15:0] data_wmask_0_4 = (way_sel == 4'd8) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_4  = (way_sel == 4'd8) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_4 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_4 (
		.clk0(clk), .csb0(~data_we_0_4), .web0(~data_we_0_4),
		.wmask0(data_wmask_0_4), .addr0(index), .din0(data_din_0_4), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_4), .addr1(index), .dout1(data_dout_0_4)
	);
	wire [127:0] data_dout_0_5;
	wire data_we_0_5 = data_we & (word_sel == 3'd0) & ((way_sel == 4'd10) | (way_sel == 4'd11));
	wire [15:0] data_wmask_0_5 = (way_sel == 4'd10) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_5  = (way_sel == 4'd10) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_5 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_5 (
		.clk0(clk), .csb0(~data_we_0_5), .web0(~data_we_0_5),
		.wmask0(data_wmask_0_5), .addr0(index), .din0(data_din_0_5), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_5), .addr1(index), .dout1(data_dout_0_5)
	);
	wire [127:0] data_dout_0_6;
	wire data_we_0_6 = data_we & (word_sel == 3'd0) & ((way_sel == 4'd12) | (way_sel == 4'd13));
	wire [15:0] data_wmask_0_6 = (way_sel == 4'd12) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_6  = (way_sel == 4'd12) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_6 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_6 (
		.clk0(clk), .csb0(~data_we_0_6), .web0(~data_we_0_6),
		.wmask0(data_wmask_0_6), .addr0(index), .din0(data_din_0_6), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_6), .addr1(index), .dout1(data_dout_0_6)
	);
	wire [127:0] data_dout_0_7;
	wire data_we_0_7 = data_we & (word_sel == 3'd0) & ((way_sel == 4'd14) | (way_sel == 4'd15));
	wire [15:0] data_wmask_0_7 = (way_sel == 4'd14) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_7  = (way_sel == 4'd14) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_7 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_7 (
		.clk0(clk), .csb0(~data_we_0_7), .web0(~data_we_0_7),
		.wmask0(data_wmask_0_7), .addr0(index), .din0(data_din_0_7), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_7), .addr1(index), .dout1(data_dout_0_7)
	);
	wire [127:0] data_dout_1_0;
	wire data_we_1_0 = data_we & (word_sel == 3'd1) & ((way_sel == 4'd0) | (way_sel == 4'd1));
	wire [15:0] data_wmask_1_0 = (way_sel == 4'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_0  = (way_sel == 4'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_0 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_0 (
		.clk0(clk), .csb0(~data_we_1_0), .web0(~data_we_1_0),
		.wmask0(data_wmask_1_0), .addr0(index), .din0(data_din_1_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_0), .addr1(index), .dout1(data_dout_1_0)
	);
	wire [127:0] data_dout_1_1;
	wire data_we_1_1 = data_we & (word_sel == 3'd1) & ((way_sel == 4'd2) | (way_sel == 4'd3));
	wire [15:0] data_wmask_1_1 = (way_sel == 4'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_1  = (way_sel == 4'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_1 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_1 (
		.clk0(clk), .csb0(~data_we_1_1), .web0(~data_we_1_1),
		.wmask0(data_wmask_1_1), .addr0(index), .din0(data_din_1_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_1), .addr1(index), .dout1(data_dout_1_1)
	);
	wire [127:0] data_dout_1_2;
	wire data_we_1_2 = data_we & (word_sel == 3'd1) & ((way_sel == 4'd4) | (way_sel == 4'd5));
	wire [15:0] data_wmask_1_2 = (way_sel == 4'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_2  = (way_sel == 4'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_2 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_2 (
		.clk0(clk), .csb0(~data_we_1_2), .web0(~data_we_1_2),
		.wmask0(data_wmask_1_2), .addr0(index), .din0(data_din_1_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_2), .addr1(index), .dout1(data_dout_1_2)
	);
	wire [127:0] data_dout_1_3;
	wire data_we_1_3 = data_we & (word_sel == 3'd1) & ((way_sel == 4'd6) | (way_sel == 4'd7));
	wire [15:0] data_wmask_1_3 = (way_sel == 4'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_3  = (way_sel == 4'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_3 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_3 (
		.clk0(clk), .csb0(~data_we_1_3), .web0(~data_we_1_3),
		.wmask0(data_wmask_1_3), .addr0(index), .din0(data_din_1_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_3), .addr1(index), .dout1(data_dout_1_3)
	);
	wire [127:0] data_dout_1_4;
	wire data_we_1_4 = data_we & (word_sel == 3'd1) & ((way_sel == 4'd8) | (way_sel == 4'd9));
	wire [15:0] data_wmask_1_4 = (way_sel == 4'd8) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_4  = (way_sel == 4'd8) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_4 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_4 (
		.clk0(clk), .csb0(~data_we_1_4), .web0(~data_we_1_4),
		.wmask0(data_wmask_1_4), .addr0(index), .din0(data_din_1_4), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_4), .addr1(index), .dout1(data_dout_1_4)
	);
	wire [127:0] data_dout_1_5;
	wire data_we_1_5 = data_we & (word_sel == 3'd1) & ((way_sel == 4'd10) | (way_sel == 4'd11));
	wire [15:0] data_wmask_1_5 = (way_sel == 4'd10) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_5  = (way_sel == 4'd10) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_5 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_5 (
		.clk0(clk), .csb0(~data_we_1_5), .web0(~data_we_1_5),
		.wmask0(data_wmask_1_5), .addr0(index), .din0(data_din_1_5), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_5), .addr1(index), .dout1(data_dout_1_5)
	);
	wire [127:0] data_dout_1_6;
	wire data_we_1_6 = data_we & (word_sel == 3'd1) & ((way_sel == 4'd12) | (way_sel == 4'd13));
	wire [15:0] data_wmask_1_6 = (way_sel == 4'd12) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_6  = (way_sel == 4'd12) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_6 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_6 (
		.clk0(clk), .csb0(~data_we_1_6), .web0(~data_we_1_6),
		.wmask0(data_wmask_1_6), .addr0(index), .din0(data_din_1_6), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_6), .addr1(index), .dout1(data_dout_1_6)
	);
	wire [127:0] data_dout_1_7;
	wire data_we_1_7 = data_we & (word_sel == 3'd1) & ((way_sel == 4'd14) | (way_sel == 4'd15));
	wire [15:0] data_wmask_1_7 = (way_sel == 4'd14) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_7  = (way_sel == 4'd14) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_7 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_7 (
		.clk0(clk), .csb0(~data_we_1_7), .web0(~data_we_1_7),
		.wmask0(data_wmask_1_7), .addr0(index), .din0(data_din_1_7), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_7), .addr1(index), .dout1(data_dout_1_7)
	);
	wire [127:0] data_dout_2_0;
	wire data_we_2_0 = data_we & (word_sel == 3'd2) & ((way_sel == 4'd0) | (way_sel == 4'd1));
	wire [15:0] data_wmask_2_0 = (way_sel == 4'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_0  = (way_sel == 4'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_0 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_0 (
		.clk0(clk), .csb0(~data_we_2_0), .web0(~data_we_2_0),
		.wmask0(data_wmask_2_0), .addr0(index), .din0(data_din_2_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_0), .addr1(index), .dout1(data_dout_2_0)
	);
	wire [127:0] data_dout_2_1;
	wire data_we_2_1 = data_we & (word_sel == 3'd2) & ((way_sel == 4'd2) | (way_sel == 4'd3));
	wire [15:0] data_wmask_2_1 = (way_sel == 4'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_1  = (way_sel == 4'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_1 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_1 (
		.clk0(clk), .csb0(~data_we_2_1), .web0(~data_we_2_1),
		.wmask0(data_wmask_2_1), .addr0(index), .din0(data_din_2_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_1), .addr1(index), .dout1(data_dout_2_1)
	);
	wire [127:0] data_dout_2_2;
	wire data_we_2_2 = data_we & (word_sel == 3'd2) & ((way_sel == 4'd4) | (way_sel == 4'd5));
	wire [15:0] data_wmask_2_2 = (way_sel == 4'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_2  = (way_sel == 4'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_2 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_2 (
		.clk0(clk), .csb0(~data_we_2_2), .web0(~data_we_2_2),
		.wmask0(data_wmask_2_2), .addr0(index), .din0(data_din_2_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_2), .addr1(index), .dout1(data_dout_2_2)
	);
	wire [127:0] data_dout_2_3;
	wire data_we_2_3 = data_we & (word_sel == 3'd2) & ((way_sel == 4'd6) | (way_sel == 4'd7));
	wire [15:0] data_wmask_2_3 = (way_sel == 4'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_3  = (way_sel == 4'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_3 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_3 (
		.clk0(clk), .csb0(~data_we_2_3), .web0(~data_we_2_3),
		.wmask0(data_wmask_2_3), .addr0(index), .din0(data_din_2_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_3), .addr1(index), .dout1(data_dout_2_3)
	);
	wire [127:0] data_dout_2_4;
	wire data_we_2_4 = data_we & (word_sel == 3'd2) & ((way_sel == 4'd8) | (way_sel == 4'd9));
	wire [15:0] data_wmask_2_4 = (way_sel == 4'd8) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_4  = (way_sel == 4'd8) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_4 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_4 (
		.clk0(clk), .csb0(~data_we_2_4), .web0(~data_we_2_4),
		.wmask0(data_wmask_2_4), .addr0(index), .din0(data_din_2_4), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_4), .addr1(index), .dout1(data_dout_2_4)
	);
	wire [127:0] data_dout_2_5;
	wire data_we_2_5 = data_we & (word_sel == 3'd2) & ((way_sel == 4'd10) | (way_sel == 4'd11));
	wire [15:0] data_wmask_2_5 = (way_sel == 4'd10) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_5  = (way_sel == 4'd10) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_5 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_5 (
		.clk0(clk), .csb0(~data_we_2_5), .web0(~data_we_2_5),
		.wmask0(data_wmask_2_5), .addr0(index), .din0(data_din_2_5), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_5), .addr1(index), .dout1(data_dout_2_5)
	);
	wire [127:0] data_dout_2_6;
	wire data_we_2_6 = data_we & (word_sel == 3'd2) & ((way_sel == 4'd12) | (way_sel == 4'd13));
	wire [15:0] data_wmask_2_6 = (way_sel == 4'd12) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_6  = (way_sel == 4'd12) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_6 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_6 (
		.clk0(clk), .csb0(~data_we_2_6), .web0(~data_we_2_6),
		.wmask0(data_wmask_2_6), .addr0(index), .din0(data_din_2_6), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_6), .addr1(index), .dout1(data_dout_2_6)
	);
	wire [127:0] data_dout_2_7;
	wire data_we_2_7 = data_we & (word_sel == 3'd2) & ((way_sel == 4'd14) | (way_sel == 4'd15));
	wire [15:0] data_wmask_2_7 = (way_sel == 4'd14) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_7  = (way_sel == 4'd14) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_7 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_7 (
		.clk0(clk), .csb0(~data_we_2_7), .web0(~data_we_2_7),
		.wmask0(data_wmask_2_7), .addr0(index), .din0(data_din_2_7), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_7), .addr1(index), .dout1(data_dout_2_7)
	);
	wire [127:0] data_dout_3_0;
	wire data_we_3_0 = data_we & (word_sel == 3'd3) & ((way_sel == 4'd0) | (way_sel == 4'd1));
	wire [15:0] data_wmask_3_0 = (way_sel == 4'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_0  = (way_sel == 4'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_0 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_0 (
		.clk0(clk), .csb0(~data_we_3_0), .web0(~data_we_3_0),
		.wmask0(data_wmask_3_0), .addr0(index), .din0(data_din_3_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_0), .addr1(index), .dout1(data_dout_3_0)
	);
	wire [127:0] data_dout_3_1;
	wire data_we_3_1 = data_we & (word_sel == 3'd3) & ((way_sel == 4'd2) | (way_sel == 4'd3));
	wire [15:0] data_wmask_3_1 = (way_sel == 4'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_1  = (way_sel == 4'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_1 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_1 (
		.clk0(clk), .csb0(~data_we_3_1), .web0(~data_we_3_1),
		.wmask0(data_wmask_3_1), .addr0(index), .din0(data_din_3_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_1), .addr1(index), .dout1(data_dout_3_1)
	);
	wire [127:0] data_dout_3_2;
	wire data_we_3_2 = data_we & (word_sel == 3'd3) & ((way_sel == 4'd4) | (way_sel == 4'd5));
	wire [15:0] data_wmask_3_2 = (way_sel == 4'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_2  = (way_sel == 4'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_2 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_2 (
		.clk0(clk), .csb0(~data_we_3_2), .web0(~data_we_3_2),
		.wmask0(data_wmask_3_2), .addr0(index), .din0(data_din_3_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_2), .addr1(index), .dout1(data_dout_3_2)
	);
	wire [127:0] data_dout_3_3;
	wire data_we_3_3 = data_we & (word_sel == 3'd3) & ((way_sel == 4'd6) | (way_sel == 4'd7));
	wire [15:0] data_wmask_3_3 = (way_sel == 4'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_3  = (way_sel == 4'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_3 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_3 (
		.clk0(clk), .csb0(~data_we_3_3), .web0(~data_we_3_3),
		.wmask0(data_wmask_3_3), .addr0(index), .din0(data_din_3_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_3), .addr1(index), .dout1(data_dout_3_3)
	);
	wire [127:0] data_dout_3_4;
	wire data_we_3_4 = data_we & (word_sel == 3'd3) & ((way_sel == 4'd8) | (way_sel == 4'd9));
	wire [15:0] data_wmask_3_4 = (way_sel == 4'd8) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_4  = (way_sel == 4'd8) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_4 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_4 (
		.clk0(clk), .csb0(~data_we_3_4), .web0(~data_we_3_4),
		.wmask0(data_wmask_3_4), .addr0(index), .din0(data_din_3_4), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_4), .addr1(index), .dout1(data_dout_3_4)
	);
	wire [127:0] data_dout_3_5;
	wire data_we_3_5 = data_we & (word_sel == 3'd3) & ((way_sel == 4'd10) | (way_sel == 4'd11));
	wire [15:0] data_wmask_3_5 = (way_sel == 4'd10) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_5  = (way_sel == 4'd10) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_5 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_5 (
		.clk0(clk), .csb0(~data_we_3_5), .web0(~data_we_3_5),
		.wmask0(data_wmask_3_5), .addr0(index), .din0(data_din_3_5), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_5), .addr1(index), .dout1(data_dout_3_5)
	);
	wire [127:0] data_dout_3_6;
	wire data_we_3_6 = data_we & (word_sel == 3'd3) & ((way_sel == 4'd12) | (way_sel == 4'd13));
	wire [15:0] data_wmask_3_6 = (way_sel == 4'd12) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_6  = (way_sel == 4'd12) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_6 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_6 (
		.clk0(clk), .csb0(~data_we_3_6), .web0(~data_we_3_6),
		.wmask0(data_wmask_3_6), .addr0(index), .din0(data_din_3_6), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_6), .addr1(index), .dout1(data_dout_3_6)
	);
	wire [127:0] data_dout_3_7;
	wire data_we_3_7 = data_we & (word_sel == 3'd3) & ((way_sel == 4'd14) | (way_sel == 4'd15));
	wire [15:0] data_wmask_3_7 = (way_sel == 4'd14) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_7  = (way_sel == 4'd14) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_7 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_7 (
		.clk0(clk), .csb0(~data_we_3_7), .web0(~data_we_3_7),
		.wmask0(data_wmask_3_7), .addr0(index), .din0(data_din_3_7), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_7), .addr1(index), .dout1(data_dout_3_7)
	);
	wire [127:0] data_dout_4_0;
	wire data_we_4_0 = data_we & (word_sel == 3'd4) & ((way_sel == 4'd0) | (way_sel == 4'd1));
	wire [15:0] data_wmask_4_0 = (way_sel == 4'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_0  = (way_sel == 4'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_0 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_0 (
		.clk0(clk), .csb0(~data_we_4_0), .web0(~data_we_4_0),
		.wmask0(data_wmask_4_0), .addr0(index), .din0(data_din_4_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_0), .addr1(index), .dout1(data_dout_4_0)
	);
	wire [127:0] data_dout_4_1;
	wire data_we_4_1 = data_we & (word_sel == 3'd4) & ((way_sel == 4'd2) | (way_sel == 4'd3));
	wire [15:0] data_wmask_4_1 = (way_sel == 4'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_1  = (way_sel == 4'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_1 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_1 (
		.clk0(clk), .csb0(~data_we_4_1), .web0(~data_we_4_1),
		.wmask0(data_wmask_4_1), .addr0(index), .din0(data_din_4_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_1), .addr1(index), .dout1(data_dout_4_1)
	);
	wire [127:0] data_dout_4_2;
	wire data_we_4_2 = data_we & (word_sel == 3'd4) & ((way_sel == 4'd4) | (way_sel == 4'd5));
	wire [15:0] data_wmask_4_2 = (way_sel == 4'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_2  = (way_sel == 4'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_2 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_2 (
		.clk0(clk), .csb0(~data_we_4_2), .web0(~data_we_4_2),
		.wmask0(data_wmask_4_2), .addr0(index), .din0(data_din_4_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_2), .addr1(index), .dout1(data_dout_4_2)
	);
	wire [127:0] data_dout_4_3;
	wire data_we_4_3 = data_we & (word_sel == 3'd4) & ((way_sel == 4'd6) | (way_sel == 4'd7));
	wire [15:0] data_wmask_4_3 = (way_sel == 4'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_3  = (way_sel == 4'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_3 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_3 (
		.clk0(clk), .csb0(~data_we_4_3), .web0(~data_we_4_3),
		.wmask0(data_wmask_4_3), .addr0(index), .din0(data_din_4_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_3), .addr1(index), .dout1(data_dout_4_3)
	);
	wire [127:0] data_dout_4_4;
	wire data_we_4_4 = data_we & (word_sel == 3'd4) & ((way_sel == 4'd8) | (way_sel == 4'd9));
	wire [15:0] data_wmask_4_4 = (way_sel == 4'd8) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_4  = (way_sel == 4'd8) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_4 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_4 (
		.clk0(clk), .csb0(~data_we_4_4), .web0(~data_we_4_4),
		.wmask0(data_wmask_4_4), .addr0(index), .din0(data_din_4_4), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_4), .addr1(index), .dout1(data_dout_4_4)
	);
	wire [127:0] data_dout_4_5;
	wire data_we_4_5 = data_we & (word_sel == 3'd4) & ((way_sel == 4'd10) | (way_sel == 4'd11));
	wire [15:0] data_wmask_4_5 = (way_sel == 4'd10) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_5  = (way_sel == 4'd10) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_5 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_5 (
		.clk0(clk), .csb0(~data_we_4_5), .web0(~data_we_4_5),
		.wmask0(data_wmask_4_5), .addr0(index), .din0(data_din_4_5), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_5), .addr1(index), .dout1(data_dout_4_5)
	);
	wire [127:0] data_dout_4_6;
	wire data_we_4_6 = data_we & (word_sel == 3'd4) & ((way_sel == 4'd12) | (way_sel == 4'd13));
	wire [15:0] data_wmask_4_6 = (way_sel == 4'd12) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_6  = (way_sel == 4'd12) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_6 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_6 (
		.clk0(clk), .csb0(~data_we_4_6), .web0(~data_we_4_6),
		.wmask0(data_wmask_4_6), .addr0(index), .din0(data_din_4_6), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_6), .addr1(index), .dout1(data_dout_4_6)
	);
	wire [127:0] data_dout_4_7;
	wire data_we_4_7 = data_we & (word_sel == 3'd4) & ((way_sel == 4'd14) | (way_sel == 4'd15));
	wire [15:0] data_wmask_4_7 = (way_sel == 4'd14) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_7  = (way_sel == 4'd14) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_7 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_7 (
		.clk0(clk), .csb0(~data_we_4_7), .web0(~data_we_4_7),
		.wmask0(data_wmask_4_7), .addr0(index), .din0(data_din_4_7), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_7), .addr1(index), .dout1(data_dout_4_7)
	);
	wire [127:0] data_dout_5_0;
	wire data_we_5_0 = data_we & (word_sel == 3'd5) & ((way_sel == 4'd0) | (way_sel == 4'd1));
	wire [15:0] data_wmask_5_0 = (way_sel == 4'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_0  = (way_sel == 4'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_0 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_0 (
		.clk0(clk), .csb0(~data_we_5_0), .web0(~data_we_5_0),
		.wmask0(data_wmask_5_0), .addr0(index), .din0(data_din_5_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_0), .addr1(index), .dout1(data_dout_5_0)
	);
	wire [127:0] data_dout_5_1;
	wire data_we_5_1 = data_we & (word_sel == 3'd5) & ((way_sel == 4'd2) | (way_sel == 4'd3));
	wire [15:0] data_wmask_5_1 = (way_sel == 4'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_1  = (way_sel == 4'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_1 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_1 (
		.clk0(clk), .csb0(~data_we_5_1), .web0(~data_we_5_1),
		.wmask0(data_wmask_5_1), .addr0(index), .din0(data_din_5_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_1), .addr1(index), .dout1(data_dout_5_1)
	);
	wire [127:0] data_dout_5_2;
	wire data_we_5_2 = data_we & (word_sel == 3'd5) & ((way_sel == 4'd4) | (way_sel == 4'd5));
	wire [15:0] data_wmask_5_2 = (way_sel == 4'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_2  = (way_sel == 4'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_2 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_2 (
		.clk0(clk), .csb0(~data_we_5_2), .web0(~data_we_5_2),
		.wmask0(data_wmask_5_2), .addr0(index), .din0(data_din_5_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_2), .addr1(index), .dout1(data_dout_5_2)
	);
	wire [127:0] data_dout_5_3;
	wire data_we_5_3 = data_we & (word_sel == 3'd5) & ((way_sel == 4'd6) | (way_sel == 4'd7));
	wire [15:0] data_wmask_5_3 = (way_sel == 4'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_3  = (way_sel == 4'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_3 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_3 (
		.clk0(clk), .csb0(~data_we_5_3), .web0(~data_we_5_3),
		.wmask0(data_wmask_5_3), .addr0(index), .din0(data_din_5_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_3), .addr1(index), .dout1(data_dout_5_3)
	);
	wire [127:0] data_dout_5_4;
	wire data_we_5_4 = data_we & (word_sel == 3'd5) & ((way_sel == 4'd8) | (way_sel == 4'd9));
	wire [15:0] data_wmask_5_4 = (way_sel == 4'd8) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_4  = (way_sel == 4'd8) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_4 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_4 (
		.clk0(clk), .csb0(~data_we_5_4), .web0(~data_we_5_4),
		.wmask0(data_wmask_5_4), .addr0(index), .din0(data_din_5_4), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_4), .addr1(index), .dout1(data_dout_5_4)
	);
	wire [127:0] data_dout_5_5;
	wire data_we_5_5 = data_we & (word_sel == 3'd5) & ((way_sel == 4'd10) | (way_sel == 4'd11));
	wire [15:0] data_wmask_5_5 = (way_sel == 4'd10) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_5  = (way_sel == 4'd10) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_5 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_5 (
		.clk0(clk), .csb0(~data_we_5_5), .web0(~data_we_5_5),
		.wmask0(data_wmask_5_5), .addr0(index), .din0(data_din_5_5), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_5), .addr1(index), .dout1(data_dout_5_5)
	);
	wire [127:0] data_dout_5_6;
	wire data_we_5_6 = data_we & (word_sel == 3'd5) & ((way_sel == 4'd12) | (way_sel == 4'd13));
	wire [15:0] data_wmask_5_6 = (way_sel == 4'd12) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_6  = (way_sel == 4'd12) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_6 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_6 (
		.clk0(clk), .csb0(~data_we_5_6), .web0(~data_we_5_6),
		.wmask0(data_wmask_5_6), .addr0(index), .din0(data_din_5_6), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_6), .addr1(index), .dout1(data_dout_5_6)
	);
	wire [127:0] data_dout_5_7;
	wire data_we_5_7 = data_we & (word_sel == 3'd5) & ((way_sel == 4'd14) | (way_sel == 4'd15));
	wire [15:0] data_wmask_5_7 = (way_sel == 4'd14) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_7  = (way_sel == 4'd14) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_7 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_7 (
		.clk0(clk), .csb0(~data_we_5_7), .web0(~data_we_5_7),
		.wmask0(data_wmask_5_7), .addr0(index), .din0(data_din_5_7), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_7), .addr1(index), .dout1(data_dout_5_7)
	);
	wire [127:0] data_dout_6_0;
	wire data_we_6_0 = data_we & (word_sel == 3'd6) & ((way_sel == 4'd0) | (way_sel == 4'd1));
	wire [15:0] data_wmask_6_0 = (way_sel == 4'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_0  = (way_sel == 4'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_0 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_0 (
		.clk0(clk), .csb0(~data_we_6_0), .web0(~data_we_6_0),
		.wmask0(data_wmask_6_0), .addr0(index), .din0(data_din_6_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_0), .addr1(index), .dout1(data_dout_6_0)
	);
	wire [127:0] data_dout_6_1;
	wire data_we_6_1 = data_we & (word_sel == 3'd6) & ((way_sel == 4'd2) | (way_sel == 4'd3));
	wire [15:0] data_wmask_6_1 = (way_sel == 4'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_1  = (way_sel == 4'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_1 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_1 (
		.clk0(clk), .csb0(~data_we_6_1), .web0(~data_we_6_1),
		.wmask0(data_wmask_6_1), .addr0(index), .din0(data_din_6_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_1), .addr1(index), .dout1(data_dout_6_1)
	);
	wire [127:0] data_dout_6_2;
	wire data_we_6_2 = data_we & (word_sel == 3'd6) & ((way_sel == 4'd4) | (way_sel == 4'd5));
	wire [15:0] data_wmask_6_2 = (way_sel == 4'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_2  = (way_sel == 4'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_2 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_2 (
		.clk0(clk), .csb0(~data_we_6_2), .web0(~data_we_6_2),
		.wmask0(data_wmask_6_2), .addr0(index), .din0(data_din_6_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_2), .addr1(index), .dout1(data_dout_6_2)
	);
	wire [127:0] data_dout_6_3;
	wire data_we_6_3 = data_we & (word_sel == 3'd6) & ((way_sel == 4'd6) | (way_sel == 4'd7));
	wire [15:0] data_wmask_6_3 = (way_sel == 4'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_3  = (way_sel == 4'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_3 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_3 (
		.clk0(clk), .csb0(~data_we_6_3), .web0(~data_we_6_3),
		.wmask0(data_wmask_6_3), .addr0(index), .din0(data_din_6_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_3), .addr1(index), .dout1(data_dout_6_3)
	);
	wire [127:0] data_dout_6_4;
	wire data_we_6_4 = data_we & (word_sel == 3'd6) & ((way_sel == 4'd8) | (way_sel == 4'd9));
	wire [15:0] data_wmask_6_4 = (way_sel == 4'd8) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_4  = (way_sel == 4'd8) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_4 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_4 (
		.clk0(clk), .csb0(~data_we_6_4), .web0(~data_we_6_4),
		.wmask0(data_wmask_6_4), .addr0(index), .din0(data_din_6_4), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_4), .addr1(index), .dout1(data_dout_6_4)
	);
	wire [127:0] data_dout_6_5;
	wire data_we_6_5 = data_we & (word_sel == 3'd6) & ((way_sel == 4'd10) | (way_sel == 4'd11));
	wire [15:0] data_wmask_6_5 = (way_sel == 4'd10) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_5  = (way_sel == 4'd10) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_5 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_5 (
		.clk0(clk), .csb0(~data_we_6_5), .web0(~data_we_6_5),
		.wmask0(data_wmask_6_5), .addr0(index), .din0(data_din_6_5), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_5), .addr1(index), .dout1(data_dout_6_5)
	);
	wire [127:0] data_dout_6_6;
	wire data_we_6_6 = data_we & (word_sel == 3'd6) & ((way_sel == 4'd12) | (way_sel == 4'd13));
	wire [15:0] data_wmask_6_6 = (way_sel == 4'd12) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_6  = (way_sel == 4'd12) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_6 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_6 (
		.clk0(clk), .csb0(~data_we_6_6), .web0(~data_we_6_6),
		.wmask0(data_wmask_6_6), .addr0(index), .din0(data_din_6_6), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_6), .addr1(index), .dout1(data_dout_6_6)
	);
	wire [127:0] data_dout_6_7;
	wire data_we_6_7 = data_we & (word_sel == 3'd6) & ((way_sel == 4'd14) | (way_sel == 4'd15));
	wire [15:0] data_wmask_6_7 = (way_sel == 4'd14) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_7  = (way_sel == 4'd14) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_7 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_7 (
		.clk0(clk), .csb0(~data_we_6_7), .web0(~data_we_6_7),
		.wmask0(data_wmask_6_7), .addr0(index), .din0(data_din_6_7), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_7), .addr1(index), .dout1(data_dout_6_7)
	);
	wire [127:0] data_dout_7_0;
	wire data_we_7_0 = data_we & (word_sel == 3'd7) & ((way_sel == 4'd0) | (way_sel == 4'd1));
	wire [15:0] data_wmask_7_0 = (way_sel == 4'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_0  = (way_sel == 4'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_0 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_0 (
		.clk0(clk), .csb0(~data_we_7_0), .web0(~data_we_7_0),
		.wmask0(data_wmask_7_0), .addr0(index), .din0(data_din_7_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_0), .addr1(index), .dout1(data_dout_7_0)
	);
	wire [127:0] data_dout_7_1;
	wire data_we_7_1 = data_we & (word_sel == 3'd7) & ((way_sel == 4'd2) | (way_sel == 4'd3));
	wire [15:0] data_wmask_7_1 = (way_sel == 4'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_1  = (way_sel == 4'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_1 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_1 (
		.clk0(clk), .csb0(~data_we_7_1), .web0(~data_we_7_1),
		.wmask0(data_wmask_7_1), .addr0(index), .din0(data_din_7_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_1), .addr1(index), .dout1(data_dout_7_1)
	);
	wire [127:0] data_dout_7_2;
	wire data_we_7_2 = data_we & (word_sel == 3'd7) & ((way_sel == 4'd4) | (way_sel == 4'd5));
	wire [15:0] data_wmask_7_2 = (way_sel == 4'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_2  = (way_sel == 4'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_2 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_2 (
		.clk0(clk), .csb0(~data_we_7_2), .web0(~data_we_7_2),
		.wmask0(data_wmask_7_2), .addr0(index), .din0(data_din_7_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_2), .addr1(index), .dout1(data_dout_7_2)
	);
	wire [127:0] data_dout_7_3;
	wire data_we_7_3 = data_we & (word_sel == 3'd7) & ((way_sel == 4'd6) | (way_sel == 4'd7));
	wire [15:0] data_wmask_7_3 = (way_sel == 4'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_3  = (way_sel == 4'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_3 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_3 (
		.clk0(clk), .csb0(~data_we_7_3), .web0(~data_we_7_3),
		.wmask0(data_wmask_7_3), .addr0(index), .din0(data_din_7_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_3), .addr1(index), .dout1(data_dout_7_3)
	);
	wire [127:0] data_dout_7_4;
	wire data_we_7_4 = data_we & (word_sel == 3'd7) & ((way_sel == 4'd8) | (way_sel == 4'd9));
	wire [15:0] data_wmask_7_4 = (way_sel == 4'd8) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_4  = (way_sel == 4'd8) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_4 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_4 (
		.clk0(clk), .csb0(~data_we_7_4), .web0(~data_we_7_4),
		.wmask0(data_wmask_7_4), .addr0(index), .din0(data_din_7_4), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_4), .addr1(index), .dout1(data_dout_7_4)
	);
	wire [127:0] data_dout_7_5;
	wire data_we_7_5 = data_we & (word_sel == 3'd7) & ((way_sel == 4'd10) | (way_sel == 4'd11));
	wire [15:0] data_wmask_7_5 = (way_sel == 4'd10) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_5  = (way_sel == 4'd10) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_5 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_5 (
		.clk0(clk), .csb0(~data_we_7_5), .web0(~data_we_7_5),
		.wmask0(data_wmask_7_5), .addr0(index), .din0(data_din_7_5), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_5), .addr1(index), .dout1(data_dout_7_5)
	);
	wire [127:0] data_dout_7_6;
	wire data_we_7_6 = data_we & (word_sel == 3'd7) & ((way_sel == 4'd12) | (way_sel == 4'd13));
	wire [15:0] data_wmask_7_6 = (way_sel == 4'd12) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_6  = (way_sel == 4'd12) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_6 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_6 (
		.clk0(clk), .csb0(~data_we_7_6), .web0(~data_we_7_6),
		.wmask0(data_wmask_7_6), .addr0(index), .din0(data_din_7_6), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_6), .addr1(index), .dout1(data_dout_7_6)
	);
	wire [127:0] data_dout_7_7;
	wire data_we_7_7 = data_we & (word_sel == 3'd7) & ((way_sel == 4'd14) | (way_sel == 4'd15));
	wire [15:0] data_wmask_7_7 = (way_sel == 4'd14) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_7  = (way_sel == 4'd14) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_7 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_7 (
		.clk0(clk), .csb0(~data_we_7_7), .web0(~data_we_7_7),
		.wmask0(data_wmask_7_7), .addr0(index), .din0(data_din_7_7), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_7), .addr1(index), .dout1(data_dout_7_7)
	);

	// Data Output Muxing
	wire [63:0] rdata_way_0;
	assign rdata_way_0 = 
		(word_sel == 3'd0) ? data_dout_0_0[63:0] : 
		(word_sel == 3'd1) ? data_dout_1_0[63:0] : 
		(word_sel == 3'd2) ? data_dout_2_0[63:0] : 
		(word_sel == 3'd3) ? data_dout_3_0[63:0] : 
		(word_sel == 3'd4) ? data_dout_4_0[63:0] : 
		(word_sel == 3'd5) ? data_dout_5_0[63:0] : 
		(word_sel == 3'd6) ? data_dout_6_0[63:0] : 
		(word_sel == 3'd7) ? data_dout_7_0[63:0] : 
		64'b0;
	assign rdata_way_flat[63:0] = rdata_way_0;
	wire [63:0] rdata_way_1;
	assign rdata_way_1 = 
		(word_sel == 3'd0) ? data_dout_0_0[127:64] : 
		(word_sel == 3'd1) ? data_dout_1_0[127:64] : 
		(word_sel == 3'd2) ? data_dout_2_0[127:64] : 
		(word_sel == 3'd3) ? data_dout_3_0[127:64] : 
		(word_sel == 3'd4) ? data_dout_4_0[127:64] : 
		(word_sel == 3'd5) ? data_dout_5_0[127:64] : 
		(word_sel == 3'd6) ? data_dout_6_0[127:64] : 
		(word_sel == 3'd7) ? data_dout_7_0[127:64] : 
		64'b0;
	assign rdata_way_flat[127:64] = rdata_way_1;
	wire [63:0] rdata_way_2;
	assign rdata_way_2 = 
		(word_sel == 3'd0) ? data_dout_0_1[63:0] : 
		(word_sel == 3'd1) ? data_dout_1_1[63:0] : 
		(word_sel == 3'd2) ? data_dout_2_1[63:0] : 
		(word_sel == 3'd3) ? data_dout_3_1[63:0] : 
		(word_sel == 3'd4) ? data_dout_4_1[63:0] : 
		(word_sel == 3'd5) ? data_dout_5_1[63:0] : 
		(word_sel == 3'd6) ? data_dout_6_1[63:0] : 
		(word_sel == 3'd7) ? data_dout_7_1[63:0] : 
		64'b0;
	assign rdata_way_flat[191:128] = rdata_way_2;
	wire [63:0] rdata_way_3;
	assign rdata_way_3 = 
		(word_sel == 3'd0) ? data_dout_0_1[127:64] : 
		(word_sel == 3'd1) ? data_dout_1_1[127:64] : 
		(word_sel == 3'd2) ? data_dout_2_1[127:64] : 
		(word_sel == 3'd3) ? data_dout_3_1[127:64] : 
		(word_sel == 3'd4) ? data_dout_4_1[127:64] : 
		(word_sel == 3'd5) ? data_dout_5_1[127:64] : 
		(word_sel == 3'd6) ? data_dout_6_1[127:64] : 
		(word_sel == 3'd7) ? data_dout_7_1[127:64] : 
		64'b0;
	assign rdata_way_flat[255:192] = rdata_way_3;
	wire [63:0] rdata_way_4;
	assign rdata_way_4 = 
		(word_sel == 3'd0) ? data_dout_0_2[63:0] : 
		(word_sel == 3'd1) ? data_dout_1_2[63:0] : 
		(word_sel == 3'd2) ? data_dout_2_2[63:0] : 
		(word_sel == 3'd3) ? data_dout_3_2[63:0] : 
		(word_sel == 3'd4) ? data_dout_4_2[63:0] : 
		(word_sel == 3'd5) ? data_dout_5_2[63:0] : 
		(word_sel == 3'd6) ? data_dout_6_2[63:0] : 
		(word_sel == 3'd7) ? data_dout_7_2[63:0] : 
		64'b0;
	assign rdata_way_flat[319:256] = rdata_way_4;
	wire [63:0] rdata_way_5;
	assign rdata_way_5 = 
		(word_sel == 3'd0) ? data_dout_0_2[127:64] : 
		(word_sel == 3'd1) ? data_dout_1_2[127:64] : 
		(word_sel == 3'd2) ? data_dout_2_2[127:64] : 
		(word_sel == 3'd3) ? data_dout_3_2[127:64] : 
		(word_sel == 3'd4) ? data_dout_4_2[127:64] : 
		(word_sel == 3'd5) ? data_dout_5_2[127:64] : 
		(word_sel == 3'd6) ? data_dout_6_2[127:64] : 
		(word_sel == 3'd7) ? data_dout_7_2[127:64] : 
		64'b0;
	assign rdata_way_flat[383:320] = rdata_way_5;
	wire [63:0] rdata_way_6;
	assign rdata_way_6 = 
		(word_sel == 3'd0) ? data_dout_0_3[63:0] : 
		(word_sel == 3'd1) ? data_dout_1_3[63:0] : 
		(word_sel == 3'd2) ? data_dout_2_3[63:0] : 
		(word_sel == 3'd3) ? data_dout_3_3[63:0] : 
		(word_sel == 3'd4) ? data_dout_4_3[63:0] : 
		(word_sel == 3'd5) ? data_dout_5_3[63:0] : 
		(word_sel == 3'd6) ? data_dout_6_3[63:0] : 
		(word_sel == 3'd7) ? data_dout_7_3[63:0] : 
		64'b0;
	assign rdata_way_flat[447:384] = rdata_way_6;
	wire [63:0] rdata_way_7;
	assign rdata_way_7 = 
		(word_sel == 3'd0) ? data_dout_0_3[127:64] : 
		(word_sel == 3'd1) ? data_dout_1_3[127:64] : 
		(word_sel == 3'd2) ? data_dout_2_3[127:64] : 
		(word_sel == 3'd3) ? data_dout_3_3[127:64] : 
		(word_sel == 3'd4) ? data_dout_4_3[127:64] : 
		(word_sel == 3'd5) ? data_dout_5_3[127:64] : 
		(word_sel == 3'd6) ? data_dout_6_3[127:64] : 
		(word_sel == 3'd7) ? data_dout_7_3[127:64] : 
		64'b0;
	assign rdata_way_flat[511:448] = rdata_way_7;
	wire [63:0] rdata_way_8;
	assign rdata_way_8 = 
		(word_sel == 3'd0) ? data_dout_0_4[63:0] : 
		(word_sel == 3'd1) ? data_dout_1_4[63:0] : 
		(word_sel == 3'd2) ? data_dout_2_4[63:0] : 
		(word_sel == 3'd3) ? data_dout_3_4[63:0] : 
		(word_sel == 3'd4) ? data_dout_4_4[63:0] : 
		(word_sel == 3'd5) ? data_dout_5_4[63:0] : 
		(word_sel == 3'd6) ? data_dout_6_4[63:0] : 
		(word_sel == 3'd7) ? data_dout_7_4[63:0] : 
		64'b0;
	assign rdata_way_flat[575:512] = rdata_way_8;
	wire [63:0] rdata_way_9;
	assign rdata_way_9 = 
		(word_sel == 3'd0) ? data_dout_0_4[127:64] : 
		(word_sel == 3'd1) ? data_dout_1_4[127:64] : 
		(word_sel == 3'd2) ? data_dout_2_4[127:64] : 
		(word_sel == 3'd3) ? data_dout_3_4[127:64] : 
		(word_sel == 3'd4) ? data_dout_4_4[127:64] : 
		(word_sel == 3'd5) ? data_dout_5_4[127:64] : 
		(word_sel == 3'd6) ? data_dout_6_4[127:64] : 
		(word_sel == 3'd7) ? data_dout_7_4[127:64] : 
		64'b0;
	assign rdata_way_flat[639:576] = rdata_way_9;
	wire [63:0] rdata_way_10;
	assign rdata_way_10 = 
		(word_sel == 3'd0) ? data_dout_0_5[63:0] : 
		(word_sel == 3'd1) ? data_dout_1_5[63:0] : 
		(word_sel == 3'd2) ? data_dout_2_5[63:0] : 
		(word_sel == 3'd3) ? data_dout_3_5[63:0] : 
		(word_sel == 3'd4) ? data_dout_4_5[63:0] : 
		(word_sel == 3'd5) ? data_dout_5_5[63:0] : 
		(word_sel == 3'd6) ? data_dout_6_5[63:0] : 
		(word_sel == 3'd7) ? data_dout_7_5[63:0] : 
		64'b0;
	assign rdata_way_flat[703:640] = rdata_way_10;
	wire [63:0] rdata_way_11;
	assign rdata_way_11 = 
		(word_sel == 3'd0) ? data_dout_0_5[127:64] : 
		(word_sel == 3'd1) ? data_dout_1_5[127:64] : 
		(word_sel == 3'd2) ? data_dout_2_5[127:64] : 
		(word_sel == 3'd3) ? data_dout_3_5[127:64] : 
		(word_sel == 3'd4) ? data_dout_4_5[127:64] : 
		(word_sel == 3'd5) ? data_dout_5_5[127:64] : 
		(word_sel == 3'd6) ? data_dout_6_5[127:64] : 
		(word_sel == 3'd7) ? data_dout_7_5[127:64] : 
		64'b0;
	assign rdata_way_flat[767:704] = rdata_way_11;
	wire [63:0] rdata_way_12;
	assign rdata_way_12 = 
		(word_sel == 3'd0) ? data_dout_0_6[63:0] : 
		(word_sel == 3'd1) ? data_dout_1_6[63:0] : 
		(word_sel == 3'd2) ? data_dout_2_6[63:0] : 
		(word_sel == 3'd3) ? data_dout_3_6[63:0] : 
		(word_sel == 3'd4) ? data_dout_4_6[63:0] : 
		(word_sel == 3'd5) ? data_dout_5_6[63:0] : 
		(word_sel == 3'd6) ? data_dout_6_6[63:0] : 
		(word_sel == 3'd7) ? data_dout_7_6[63:0] : 
		64'b0;
	assign rdata_way_flat[831:768] = rdata_way_12;
	wire [63:0] rdata_way_13;
	assign rdata_way_13 = 
		(word_sel == 3'd0) ? data_dout_0_6[127:64] : 
		(word_sel == 3'd1) ? data_dout_1_6[127:64] : 
		(word_sel == 3'd2) ? data_dout_2_6[127:64] : 
		(word_sel == 3'd3) ? data_dout_3_6[127:64] : 
		(word_sel == 3'd4) ? data_dout_4_6[127:64] : 
		(word_sel == 3'd5) ? data_dout_5_6[127:64] : 
		(word_sel == 3'd6) ? data_dout_6_6[127:64] : 
		(word_sel == 3'd7) ? data_dout_7_6[127:64] : 
		64'b0;
	assign rdata_way_flat[895:832] = rdata_way_13;
	wire [63:0] rdata_way_14;
	assign rdata_way_14 = 
		(word_sel == 3'd0) ? data_dout_0_7[63:0] : 
		(word_sel == 3'd1) ? data_dout_1_7[63:0] : 
		(word_sel == 3'd2) ? data_dout_2_7[63:0] : 
		(word_sel == 3'd3) ? data_dout_3_7[63:0] : 
		(word_sel == 3'd4) ? data_dout_4_7[63:0] : 
		(word_sel == 3'd5) ? data_dout_5_7[63:0] : 
		(word_sel == 3'd6) ? data_dout_6_7[63:0] : 
		(word_sel == 3'd7) ? data_dout_7_7[63:0] : 
		64'b0;
	assign rdata_way_flat[959:896] = rdata_way_14;
	wire [63:0] rdata_way_15;
	assign rdata_way_15 = 
		(word_sel == 3'd0) ? data_dout_0_7[127:64] : 
		(word_sel == 3'd1) ? data_dout_1_7[127:64] : 
		(word_sel == 3'd2) ? data_dout_2_7[127:64] : 
		(word_sel == 3'd3) ? data_dout_3_7[127:64] : 
		(word_sel == 3'd4) ? data_dout_4_7[127:64] : 
		(word_sel == 3'd5) ? data_dout_5_7[127:64] : 
		(word_sel == 3'd6) ? data_dout_6_7[127:64] : 
		(word_sel == 3'd7) ? data_dout_7_7[127:64] : 
		64'b0;
	assign rdata_way_flat[1023:960] = rdata_way_15;

	assign rdata_selected = 
		(way_sel == 4'd0) ? rdata_way_0 : 
		(way_sel == 4'd1) ? rdata_way_1 : 
		(way_sel == 4'd2) ? rdata_way_2 : 
		(way_sel == 4'd3) ? rdata_way_3 : 
		(way_sel == 4'd4) ? rdata_way_4 : 
		(way_sel == 4'd5) ? rdata_way_5 : 
		(way_sel == 4'd6) ? rdata_way_6 : 
		(way_sel == 4'd7) ? rdata_way_7 : 
		(way_sel == 4'd8) ? rdata_way_8 : 
		(way_sel == 4'd9) ? rdata_way_9 : 
		(way_sel == 4'd10) ? rdata_way_10 : 
		(way_sel == 4'd11) ? rdata_way_11 : 
		(way_sel == 4'd12) ? rdata_way_12 : 
		(way_sel == 4'd13) ? rdata_way_13 : 
		(way_sel == 4'd14) ? rdata_way_14 : 
		(way_sel == 4'd15) ? rdata_way_15 : 
		64'b0;

	assign tag_selected = 
		(way_sel == 4'd0) ? tag_way_flat[49:0] : 
		(way_sel == 4'd1) ? tag_way_flat[99:50] : 
		(way_sel == 4'd2) ? tag_way_flat[149:100] : 
		(way_sel == 4'd3) ? tag_way_flat[199:150] : 
		(way_sel == 4'd4) ? tag_way_flat[249:200] : 
		(way_sel == 4'd5) ? tag_way_flat[299:250] : 
		(way_sel == 4'd6) ? tag_way_flat[349:300] : 
		(way_sel == 4'd7) ? tag_way_flat[399:350] : 
		(way_sel == 4'd8) ? tag_way_flat[449:400] : 
		(way_sel == 4'd9) ? tag_way_flat[499:450] : 
		(way_sel == 4'd10) ? tag_way_flat[549:500] : 
		(way_sel == 4'd11) ? tag_way_flat[599:550] : 
		(way_sel == 4'd12) ? tag_way_flat[649:600] : 
		(way_sel == 4'd13) ? tag_way_flat[699:650] : 
		(way_sel == 4'd14) ? tag_way_flat[749:700] : 
		(way_sel == 4'd15) ? tag_way_flat[799:750] : 
		50'b0;
endmodule
