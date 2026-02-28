// cpu64_l3_arrays.v - Data/tag/valid/dirty arrays for 2MiB, 16-way, 64B lines
`timescale 1ns/1ps

module cpu64_l3_arrays (
	input               clk_i,
	input               rst_ni,
	input               invalidate_all_i,

	// Access controls
	input      [10:0]   index_i,       // set index (2048 sets)
	input       [2:0]   word_sel_i,    // word within line (8 words)
	input       [3:0]   way_sel_i,     // selected way for write (0..15)
	input               write_en_i,    // write enable for selected way/word
	input               set_valid_i,
	input               set_dirty_i,
	input       [7:0]   be_i,          // byte enables for 64-bit word
	input      [46:0]   tag_in_i,
	input      [63:0]   wdata_i,

	// Parallel per-way outputs for current index/word
	output     [63:0]   rdata_selected_o,
	output     [46:0]   tag_selected_o,
	output              valid_selected_o,
	output              dirty_selected_o,

	output [16*64-1:0]  rdata_way_flat_o,
	output [16*47-1:0]  tag_way_flat_o,
	output     [15:0]   valid_way_o,
	output     [15:0]   dirty_way_o
);

	localparam integer DATA_W          = 64;
	localparam integer TAG_W           = 47;
	localparam integer LINE_BYTES      = 64;
	localparam integer WORDS_PER_LINE  = 8;   // 64B / 8B
	localparam integer WAYS            = 16;
	localparam integer SETS            = 2048; // 2MiB / (64B * 16 ways) = 2048 sets
	localparam integer LINE_ADDR_W     = 14;   // 11 (index) + 3 (word)

	// Storage arrays (flattened to 2D for Verilog-2001)
	reg [DATA_W-1:0] data_q [0:WAYS-1][0:SETS*WORDS_PER_LINE-1];
	reg [TAG_W-1:0]  tag_q  [0:WAYS-1][0:SETS-1];
	reg              valid_q[0:WAYS-1][0:SETS-1];
	reg              dirty_q[0:WAYS-1][0:SETS-1];

	// Computed linear word index within a set group
	wire [LINE_ADDR_W-1:0] line_idx;
	assign line_idx = {index_i, word_sel_i};

	// Selected outputs
	assign rdata_selected_o = data_q[way_sel_i][line_idx];
	assign tag_selected_o   = tag_q[way_sel_i][index_i];
	assign valid_selected_o = valid_q[way_sel_i][index_i];
	assign dirty_selected_o = dirty_q[way_sel_i][index_i];

	// Flattened per-way outputs for current index/word
	genvar w;
	generate
		for (w = 0; w < WAYS; w = w + 1) begin : g_flat
			assign rdata_way_flat_o[(w+1)*DATA_W-1 : w*DATA_W] = data_q[w][line_idx];
			assign tag_way_flat_o[(w+1)*TAG_W-1    : w*TAG_W]  = tag_q[w][index_i];
			assign valid_way_o[w] = valid_q[w][index_i];
			assign dirty_way_o[w] = dirty_q[w][index_i];
		end
	endgenerate

	integer i, j;
	always @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni) begin
			for (i = 0; i < WAYS; i = i + 1) begin
				for (j = 0; j < SETS; j = j + 1) begin
					valid_q[i][j] = 1'b0;
					dirty_q[i][j] = 1'b0;
				end
			end
		end else if (invalidate_all_i) begin
			for (i = 0; i < WAYS; i = i + 1) begin
				for (j = 0; j < SETS; j = j + 1) begin
					valid_q[i][j] = 1'b0;
					dirty_q[i][j] = 1'b0;
				end
			end
		end else if (write_en_i) begin
			reg [63:0] be_mask;
			integer b;
			be_mask = 64'b0;
			for (b = 0; b < 8; b = b + 1) begin
				if (be_i[b]) be_mask[(b*8) +: 8] = 8'hFF;
			end
			data_q[way_sel_i][line_idx] <= (wdata_i & be_mask) |
				(data_q[way_sel_i][line_idx] & ~be_mask);
			tag_q[way_sel_i][index_i]   <= tag_in_i;
			valid_q[way_sel_i][index_i] <= set_valid_i;
			dirty_q[way_sel_i][index_i] <= set_dirty_i;
		end
	end

endmodule



