`timescale 1ns/1ps
`include "params.vh"

module rv64_l2_arrays_sram (
	input               clk,
	input               rst_n,
	input       [7:0]   index,
	input       [2:0]   word_sel,
	input       [2:0]   way_sel,
	input               data_we,
	input               tag_we,
	input       [7:0]   be,
	input      [49:0]   tag_in,
	input      [63:0]   wdata,
	output     [63:0]   rdata_selected,
	output     [49:0]   tag_selected,
	output [8*64-1:0]  rdata_way_flat,
	output [8*50-1:0]  tag_way_flat
);

	// Tag Array: 8 ways * 50 bits. Macro: 64x256. 1 per way -> 8 macros.
	wire [63:0] tag_dout_0;
	assign tag_way_flat[49:0] = tag_dout_0[49:0];
	wire tag_we_0 = tag_we & (way_sel == 3'd0);
	sky130_sram_1rw1r_64x256_8 tag_sram_0 (
		.clk0(clk), .csb0(~tag_we_0), .web0(~tag_we_0),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_0)
	);
	wire [63:0] tag_dout_1;
	assign tag_way_flat[99:50] = tag_dout_1[49:0];
	wire tag_we_1 = tag_we & (way_sel == 3'd1);
	sky130_sram_1rw1r_64x256_8 tag_sram_1 (
		.clk0(clk), .csb0(~tag_we_1), .web0(~tag_we_1),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_1)
	);
	wire [63:0] tag_dout_2;
	assign tag_way_flat[149:100] = tag_dout_2[49:0];
	wire tag_we_2 = tag_we & (way_sel == 3'd2);
	sky130_sram_1rw1r_64x256_8 tag_sram_2 (
		.clk0(clk), .csb0(~tag_we_2), .web0(~tag_we_2),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_2)
	);
	wire [63:0] tag_dout_3;
	assign tag_way_flat[199:150] = tag_dout_3[49:0];
	wire tag_we_3 = tag_we & (way_sel == 3'd3);
	sky130_sram_1rw1r_64x256_8 tag_sram_3 (
		.clk0(clk), .csb0(~tag_we_3), .web0(~tag_we_3),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_3)
	);
	wire [63:0] tag_dout_4;
	assign tag_way_flat[249:200] = tag_dout_4[49:0];
	wire tag_we_4 = tag_we & (way_sel == 3'd4);
	sky130_sram_1rw1r_64x256_8 tag_sram_4 (
		.clk0(clk), .csb0(~tag_we_4), .web0(~tag_we_4),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_4)
	);
	wire [63:0] tag_dout_5;
	assign tag_way_flat[299:250] = tag_dout_5[49:0];
	wire tag_we_5 = tag_we & (way_sel == 3'd5);
	sky130_sram_1rw1r_64x256_8 tag_sram_5 (
		.clk0(clk), .csb0(~tag_we_5), .web0(~tag_we_5),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_5)
	);
	wire [63:0] tag_dout_6;
	assign tag_way_flat[349:300] = tag_dout_6[49:0];
	wire tag_we_6 = tag_we & (way_sel == 3'd6);
	sky130_sram_1rw1r_64x256_8 tag_sram_6 (
		.clk0(clk), .csb0(~tag_we_6), .web0(~tag_we_6),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_6)
	);
	wire [63:0] tag_dout_7;
	assign tag_way_flat[399:350] = tag_dout_7[49:0];
	wire tag_we_7 = tag_we & (way_sel == 3'd7);
	sky130_sram_1rw1r_64x256_8 tag_sram_7 (
		.clk0(clk), .csb0(~tag_we_7), .web0(~tag_we_7),
		.wmask0(8'hFF), .addr0(index), .din0({14'b0, tag_in}), .dout0(),
		.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_7)
	);

	// Data Array: 8 ways * 8 words * 64 bits.
	// Using 32 instances of 128x256: 4 macros per word_sel.
	wire [127:0] data_dout_0_0;
	wire data_we_0_0 = data_we & (word_sel == 3'd0) & ((way_sel == 3'd0) | (way_sel == 3'd1));
	wire [15:0] data_wmask_0_0 = (way_sel == 3'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_0  = (way_sel == 3'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_0 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_0 (
		.clk0(clk), .csb0(~data_we_0_0), .web0(~data_we_0_0),
		.wmask0(data_wmask_0_0), .addr0(index), .din0(data_din_0_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_0), .addr1(index), .dout1(data_dout_0_0)
	);
	wire [127:0] data_dout_0_1;
	wire data_we_0_1 = data_we & (word_sel == 3'd0) & ((way_sel == 3'd2) | (way_sel == 3'd3));
	wire [15:0] data_wmask_0_1 = (way_sel == 3'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_1  = (way_sel == 3'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_1 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_1 (
		.clk0(clk), .csb0(~data_we_0_1), .web0(~data_we_0_1),
		.wmask0(data_wmask_0_1), .addr0(index), .din0(data_din_0_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_1), .addr1(index), .dout1(data_dout_0_1)
	);
	wire [127:0] data_dout_0_2;
	wire data_we_0_2 = data_we & (word_sel == 3'd0) & ((way_sel == 3'd4) | (way_sel == 3'd5));
	wire [15:0] data_wmask_0_2 = (way_sel == 3'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_2  = (way_sel == 3'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_2 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_2 (
		.clk0(clk), .csb0(~data_we_0_2), .web0(~data_we_0_2),
		.wmask0(data_wmask_0_2), .addr0(index), .din0(data_din_0_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_2), .addr1(index), .dout1(data_dout_0_2)
	);
	wire [127:0] data_dout_0_3;
	wire data_we_0_3 = data_we & (word_sel == 3'd0) & ((way_sel == 3'd6) | (way_sel == 3'd7));
	wire [15:0] data_wmask_0_3 = (way_sel == 3'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_0_3  = (way_sel == 3'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_0_3 = ~(word_sel == 3'd0);
	sky130_sram_1rw1r_128x256_8 data_sram_0_3 (
		.clk0(clk), .csb0(~data_we_0_3), .web0(~data_we_0_3),
		.wmask0(data_wmask_0_3), .addr0(index), .din0(data_din_0_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_0_3), .addr1(index), .dout1(data_dout_0_3)
	);
	wire [127:0] data_dout_1_0;
	wire data_we_1_0 = data_we & (word_sel == 3'd1) & ((way_sel == 3'd0) | (way_sel == 3'd1));
	wire [15:0] data_wmask_1_0 = (way_sel == 3'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_0  = (way_sel == 3'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_0 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_0 (
		.clk0(clk), .csb0(~data_we_1_0), .web0(~data_we_1_0),
		.wmask0(data_wmask_1_0), .addr0(index), .din0(data_din_1_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_0), .addr1(index), .dout1(data_dout_1_0)
	);
	wire [127:0] data_dout_1_1;
	wire data_we_1_1 = data_we & (word_sel == 3'd1) & ((way_sel == 3'd2) | (way_sel == 3'd3));
	wire [15:0] data_wmask_1_1 = (way_sel == 3'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_1  = (way_sel == 3'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_1 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_1 (
		.clk0(clk), .csb0(~data_we_1_1), .web0(~data_we_1_1),
		.wmask0(data_wmask_1_1), .addr0(index), .din0(data_din_1_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_1), .addr1(index), .dout1(data_dout_1_1)
	);
	wire [127:0] data_dout_1_2;
	wire data_we_1_2 = data_we & (word_sel == 3'd1) & ((way_sel == 3'd4) | (way_sel == 3'd5));
	wire [15:0] data_wmask_1_2 = (way_sel == 3'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_2  = (way_sel == 3'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_2 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_2 (
		.clk0(clk), .csb0(~data_we_1_2), .web0(~data_we_1_2),
		.wmask0(data_wmask_1_2), .addr0(index), .din0(data_din_1_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_2), .addr1(index), .dout1(data_dout_1_2)
	);
	wire [127:0] data_dout_1_3;
	wire data_we_1_3 = data_we & (word_sel == 3'd1) & ((way_sel == 3'd6) | (way_sel == 3'd7));
	wire [15:0] data_wmask_1_3 = (way_sel == 3'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_1_3  = (way_sel == 3'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_1_3 = ~(word_sel == 3'd1);
	sky130_sram_1rw1r_128x256_8 data_sram_1_3 (
		.clk0(clk), .csb0(~data_we_1_3), .web0(~data_we_1_3),
		.wmask0(data_wmask_1_3), .addr0(index), .din0(data_din_1_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_1_3), .addr1(index), .dout1(data_dout_1_3)
	);
	wire [127:0] data_dout_2_0;
	wire data_we_2_0 = data_we & (word_sel == 3'd2) & ((way_sel == 3'd0) | (way_sel == 3'd1));
	wire [15:0] data_wmask_2_0 = (way_sel == 3'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_0  = (way_sel == 3'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_0 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_0 (
		.clk0(clk), .csb0(~data_we_2_0), .web0(~data_we_2_0),
		.wmask0(data_wmask_2_0), .addr0(index), .din0(data_din_2_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_0), .addr1(index), .dout1(data_dout_2_0)
	);
	wire [127:0] data_dout_2_1;
	wire data_we_2_1 = data_we & (word_sel == 3'd2) & ((way_sel == 3'd2) | (way_sel == 3'd3));
	wire [15:0] data_wmask_2_1 = (way_sel == 3'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_1  = (way_sel == 3'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_1 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_1 (
		.clk0(clk), .csb0(~data_we_2_1), .web0(~data_we_2_1),
		.wmask0(data_wmask_2_1), .addr0(index), .din0(data_din_2_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_1), .addr1(index), .dout1(data_dout_2_1)
	);
	wire [127:0] data_dout_2_2;
	wire data_we_2_2 = data_we & (word_sel == 3'd2) & ((way_sel == 3'd4) | (way_sel == 3'd5));
	wire [15:0] data_wmask_2_2 = (way_sel == 3'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_2  = (way_sel == 3'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_2 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_2 (
		.clk0(clk), .csb0(~data_we_2_2), .web0(~data_we_2_2),
		.wmask0(data_wmask_2_2), .addr0(index), .din0(data_din_2_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_2), .addr1(index), .dout1(data_dout_2_2)
	);
	wire [127:0] data_dout_2_3;
	wire data_we_2_3 = data_we & (word_sel == 3'd2) & ((way_sel == 3'd6) | (way_sel == 3'd7));
	wire [15:0] data_wmask_2_3 = (way_sel == 3'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_2_3  = (way_sel == 3'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_2_3 = ~(word_sel == 3'd2);
	sky130_sram_1rw1r_128x256_8 data_sram_2_3 (
		.clk0(clk), .csb0(~data_we_2_3), .web0(~data_we_2_3),
		.wmask0(data_wmask_2_3), .addr0(index), .din0(data_din_2_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_2_3), .addr1(index), .dout1(data_dout_2_3)
	);
	wire [127:0] data_dout_3_0;
	wire data_we_3_0 = data_we & (word_sel == 3'd3) & ((way_sel == 3'd0) | (way_sel == 3'd1));
	wire [15:0] data_wmask_3_0 = (way_sel == 3'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_0  = (way_sel == 3'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_0 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_0 (
		.clk0(clk), .csb0(~data_we_3_0), .web0(~data_we_3_0),
		.wmask0(data_wmask_3_0), .addr0(index), .din0(data_din_3_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_0), .addr1(index), .dout1(data_dout_3_0)
	);
	wire [127:0] data_dout_3_1;
	wire data_we_3_1 = data_we & (word_sel == 3'd3) & ((way_sel == 3'd2) | (way_sel == 3'd3));
	wire [15:0] data_wmask_3_1 = (way_sel == 3'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_1  = (way_sel == 3'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_1 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_1 (
		.clk0(clk), .csb0(~data_we_3_1), .web0(~data_we_3_1),
		.wmask0(data_wmask_3_1), .addr0(index), .din0(data_din_3_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_1), .addr1(index), .dout1(data_dout_3_1)
	);
	wire [127:0] data_dout_3_2;
	wire data_we_3_2 = data_we & (word_sel == 3'd3) & ((way_sel == 3'd4) | (way_sel == 3'd5));
	wire [15:0] data_wmask_3_2 = (way_sel == 3'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_2  = (way_sel == 3'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_2 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_2 (
		.clk0(clk), .csb0(~data_we_3_2), .web0(~data_we_3_2),
		.wmask0(data_wmask_3_2), .addr0(index), .din0(data_din_3_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_2), .addr1(index), .dout1(data_dout_3_2)
	);
	wire [127:0] data_dout_3_3;
	wire data_we_3_3 = data_we & (word_sel == 3'd3) & ((way_sel == 3'd6) | (way_sel == 3'd7));
	wire [15:0] data_wmask_3_3 = (way_sel == 3'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_3_3  = (way_sel == 3'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_3_3 = ~(word_sel == 3'd3);
	sky130_sram_1rw1r_128x256_8 data_sram_3_3 (
		.clk0(clk), .csb0(~data_we_3_3), .web0(~data_we_3_3),
		.wmask0(data_wmask_3_3), .addr0(index), .din0(data_din_3_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_3_3), .addr1(index), .dout1(data_dout_3_3)
	);
	wire [127:0] data_dout_4_0;
	wire data_we_4_0 = data_we & (word_sel == 3'd4) & ((way_sel == 3'd0) | (way_sel == 3'd1));
	wire [15:0] data_wmask_4_0 = (way_sel == 3'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_0  = (way_sel == 3'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_0 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_0 (
		.clk0(clk), .csb0(~data_we_4_0), .web0(~data_we_4_0),
		.wmask0(data_wmask_4_0), .addr0(index), .din0(data_din_4_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_0), .addr1(index), .dout1(data_dout_4_0)
	);
	wire [127:0] data_dout_4_1;
	wire data_we_4_1 = data_we & (word_sel == 3'd4) & ((way_sel == 3'd2) | (way_sel == 3'd3));
	wire [15:0] data_wmask_4_1 = (way_sel == 3'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_1  = (way_sel == 3'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_1 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_1 (
		.clk0(clk), .csb0(~data_we_4_1), .web0(~data_we_4_1),
		.wmask0(data_wmask_4_1), .addr0(index), .din0(data_din_4_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_1), .addr1(index), .dout1(data_dout_4_1)
	);
	wire [127:0] data_dout_4_2;
	wire data_we_4_2 = data_we & (word_sel == 3'd4) & ((way_sel == 3'd4) | (way_sel == 3'd5));
	wire [15:0] data_wmask_4_2 = (way_sel == 3'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_2  = (way_sel == 3'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_2 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_2 (
		.clk0(clk), .csb0(~data_we_4_2), .web0(~data_we_4_2),
		.wmask0(data_wmask_4_2), .addr0(index), .din0(data_din_4_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_2), .addr1(index), .dout1(data_dout_4_2)
	);
	wire [127:0] data_dout_4_3;
	wire data_we_4_3 = data_we & (word_sel == 3'd4) & ((way_sel == 3'd6) | (way_sel == 3'd7));
	wire [15:0] data_wmask_4_3 = (way_sel == 3'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_4_3  = (way_sel == 3'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_4_3 = ~(word_sel == 3'd4);
	sky130_sram_1rw1r_128x256_8 data_sram_4_3 (
		.clk0(clk), .csb0(~data_we_4_3), .web0(~data_we_4_3),
		.wmask0(data_wmask_4_3), .addr0(index), .din0(data_din_4_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_4_3), .addr1(index), .dout1(data_dout_4_3)
	);
	wire [127:0] data_dout_5_0;
	wire data_we_5_0 = data_we & (word_sel == 3'd5) & ((way_sel == 3'd0) | (way_sel == 3'd1));
	wire [15:0] data_wmask_5_0 = (way_sel == 3'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_0  = (way_sel == 3'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_0 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_0 (
		.clk0(clk), .csb0(~data_we_5_0), .web0(~data_we_5_0),
		.wmask0(data_wmask_5_0), .addr0(index), .din0(data_din_5_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_0), .addr1(index), .dout1(data_dout_5_0)
	);
	wire [127:0] data_dout_5_1;
	wire data_we_5_1 = data_we & (word_sel == 3'd5) & ((way_sel == 3'd2) | (way_sel == 3'd3));
	wire [15:0] data_wmask_5_1 = (way_sel == 3'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_1  = (way_sel == 3'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_1 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_1 (
		.clk0(clk), .csb0(~data_we_5_1), .web0(~data_we_5_1),
		.wmask0(data_wmask_5_1), .addr0(index), .din0(data_din_5_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_1), .addr1(index), .dout1(data_dout_5_1)
	);
	wire [127:0] data_dout_5_2;
	wire data_we_5_2 = data_we & (word_sel == 3'd5) & ((way_sel == 3'd4) | (way_sel == 3'd5));
	wire [15:0] data_wmask_5_2 = (way_sel == 3'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_2  = (way_sel == 3'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_2 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_2 (
		.clk0(clk), .csb0(~data_we_5_2), .web0(~data_we_5_2),
		.wmask0(data_wmask_5_2), .addr0(index), .din0(data_din_5_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_2), .addr1(index), .dout1(data_dout_5_2)
	);
	wire [127:0] data_dout_5_3;
	wire data_we_5_3 = data_we & (word_sel == 3'd5) & ((way_sel == 3'd6) | (way_sel == 3'd7));
	wire [15:0] data_wmask_5_3 = (way_sel == 3'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_5_3  = (way_sel == 3'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_5_3 = ~(word_sel == 3'd5);
	sky130_sram_1rw1r_128x256_8 data_sram_5_3 (
		.clk0(clk), .csb0(~data_we_5_3), .web0(~data_we_5_3),
		.wmask0(data_wmask_5_3), .addr0(index), .din0(data_din_5_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_5_3), .addr1(index), .dout1(data_dout_5_3)
	);
	wire [127:0] data_dout_6_0;
	wire data_we_6_0 = data_we & (word_sel == 3'd6) & ((way_sel == 3'd0) | (way_sel == 3'd1));
	wire [15:0] data_wmask_6_0 = (way_sel == 3'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_0  = (way_sel == 3'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_0 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_0 (
		.clk0(clk), .csb0(~data_we_6_0), .web0(~data_we_6_0),
		.wmask0(data_wmask_6_0), .addr0(index), .din0(data_din_6_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_0), .addr1(index), .dout1(data_dout_6_0)
	);
	wire [127:0] data_dout_6_1;
	wire data_we_6_1 = data_we & (word_sel == 3'd6) & ((way_sel == 3'd2) | (way_sel == 3'd3));
	wire [15:0] data_wmask_6_1 = (way_sel == 3'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_1  = (way_sel == 3'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_1 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_1 (
		.clk0(clk), .csb0(~data_we_6_1), .web0(~data_we_6_1),
		.wmask0(data_wmask_6_1), .addr0(index), .din0(data_din_6_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_1), .addr1(index), .dout1(data_dout_6_1)
	);
	wire [127:0] data_dout_6_2;
	wire data_we_6_2 = data_we & (word_sel == 3'd6) & ((way_sel == 3'd4) | (way_sel == 3'd5));
	wire [15:0] data_wmask_6_2 = (way_sel == 3'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_2  = (way_sel == 3'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_2 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_2 (
		.clk0(clk), .csb0(~data_we_6_2), .web0(~data_we_6_2),
		.wmask0(data_wmask_6_2), .addr0(index), .din0(data_din_6_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_2), .addr1(index), .dout1(data_dout_6_2)
	);
	wire [127:0] data_dout_6_3;
	wire data_we_6_3 = data_we & (word_sel == 3'd6) & ((way_sel == 3'd6) | (way_sel == 3'd7));
	wire [15:0] data_wmask_6_3 = (way_sel == 3'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_6_3  = (way_sel == 3'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_6_3 = ~(word_sel == 3'd6);
	sky130_sram_1rw1r_128x256_8 data_sram_6_3 (
		.clk0(clk), .csb0(~data_we_6_3), .web0(~data_we_6_3),
		.wmask0(data_wmask_6_3), .addr0(index), .din0(data_din_6_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_6_3), .addr1(index), .dout1(data_dout_6_3)
	);
	wire [127:0] data_dout_7_0;
	wire data_we_7_0 = data_we & (word_sel == 3'd7) & ((way_sel == 3'd0) | (way_sel == 3'd1));
	wire [15:0] data_wmask_7_0 = (way_sel == 3'd0) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_0  = (way_sel == 3'd0) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_0 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_0 (
		.clk0(clk), .csb0(~data_we_7_0), .web0(~data_we_7_0),
		.wmask0(data_wmask_7_0), .addr0(index), .din0(data_din_7_0), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_0), .addr1(index), .dout1(data_dout_7_0)
	);
	wire [127:0] data_dout_7_1;
	wire data_we_7_1 = data_we & (word_sel == 3'd7) & ((way_sel == 3'd2) | (way_sel == 3'd3));
	wire [15:0] data_wmask_7_1 = (way_sel == 3'd2) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_1  = (way_sel == 3'd2) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_1 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_1 (
		.clk0(clk), .csb0(~data_we_7_1), .web0(~data_we_7_1),
		.wmask0(data_wmask_7_1), .addr0(index), .din0(data_din_7_1), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_1), .addr1(index), .dout1(data_dout_7_1)
	);
	wire [127:0] data_dout_7_2;
	wire data_we_7_2 = data_we & (word_sel == 3'd7) & ((way_sel == 3'd4) | (way_sel == 3'd5));
	wire [15:0] data_wmask_7_2 = (way_sel == 3'd4) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_2  = (way_sel == 3'd4) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_2 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_2 (
		.clk0(clk), .csb0(~data_we_7_2), .web0(~data_we_7_2),
		.wmask0(data_wmask_7_2), .addr0(index), .din0(data_din_7_2), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_2), .addr1(index), .dout1(data_dout_7_2)
	);
	wire [127:0] data_dout_7_3;
	wire data_we_7_3 = data_we & (word_sel == 3'd7) & ((way_sel == 3'd6) | (way_sel == 3'd7));
	wire [15:0] data_wmask_7_3 = (way_sel == 3'd6) ? {8'h00, be} : {be, 8'h00};
	wire [127:0] data_din_7_3  = (way_sel == 3'd6) ? {64'b0, wdata} : {wdata, 64'b0};
	wire data_csen_r_7_3 = ~(word_sel == 3'd7);
	sky130_sram_1rw1r_128x256_8 data_sram_7_3 (
		.clk0(clk), .csb0(~data_we_7_3), .web0(~data_we_7_3),
		.wmask0(data_wmask_7_3), .addr0(index), .din0(data_din_7_3), .dout0(),
		.clk1(clk), .csb1(data_csen_r_7_3), .addr1(index), .dout1(data_dout_7_3)
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

	assign rdata_selected = 
		(way_sel == 3'd0) ? rdata_way_0 : 
		(way_sel == 3'd1) ? rdata_way_1 : 
		(way_sel == 3'd2) ? rdata_way_2 : 
		(way_sel == 3'd3) ? rdata_way_3 : 
		(way_sel == 3'd4) ? rdata_way_4 : 
		(way_sel == 3'd5) ? rdata_way_5 : 
		(way_sel == 3'd6) ? rdata_way_6 : 
		(way_sel == 3'd7) ? rdata_way_7 : 
		64'b0;

	assign tag_selected = 
		(way_sel == 3'd0) ? tag_way_flat[49:0] : 
		(way_sel == 3'd1) ? tag_way_flat[99:50] : 
		(way_sel == 3'd2) ? tag_way_flat[149:100] : 
		(way_sel == 3'd3) ? tag_way_flat[199:150] : 
		(way_sel == 3'd4) ? tag_way_flat[249:200] : 
		(way_sel == 3'd5) ? tag_way_flat[299:250] : 
		(way_sel == 3'd6) ? tag_way_flat[349:300] : 
		(way_sel == 3'd7) ? tag_way_flat[399:350] : 
		50'b0;
endmodule
