// cpu64_l2_plru.v - 16-way PLRU (15-bit tree) with invalid-first victim
`timescale 1ns/1ps

module cpu64_l2_plru (
	input              clk_i,
	input              rst_ni,

	// Set index to operate on (256 sets → 8 bits)
	input      [7:0]   set_i,

	// Assert to update PLRU state for the given set/way
	input              access_i,
	input      [3:0]   used_way_i,   // 0..15

	// Valid mask for ways in the indexed set (1 = valid). Used for invalid-first victim
	input     [15:0]   valid_i,

	// Selected victim way index (prefers any invalid; else PLRU tree walk)
	output reg [3:0]   victim_o
);

	localparam integer NUM_SETS = 256;
	localparam integer NUM_WAYS = 16;

	// Per-set PLRU bits: [0]=root,
	// [1]=L node (d3=0), [2]=R node (d3=1),
	// [3]=LL (d3=0,d2=0), [4]=LR (d3=0,d2=1), [5]=RL (d3=1,d2=0), [6]=RR (d3=1,d2=1),
	// [7]=LLL, [8]=LLR, [9]=LRL, [10]=LRR, [11]=RLL, [12]=RLR, [13]=RRL, [14]=RRR
	reg [14:0] plru_bits_q [0:NUM_SETS-1];

	integer si;
	always @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni) begin
			for (si = 0; si < NUM_SETS; si = si + 1) begin
				plru_bits_q[si] = 15'b0;
			end
		end else if (access_i) begin
			// Update bits along the path to the accessed way to point to the sibling (make sibling LRU)
			plru_bits_q[set_i][0] <= ~used_way_i[3]; // root
			if (!used_way_i[3]) begin
				plru_bits_q[set_i][1] <= ~used_way_i[2]; // L node
				if (!used_way_i[2]) begin
					plru_bits_q[set_i][3] <= ~used_way_i[1]; // LL
					if (!used_way_i[1]) plru_bits_q[set_i][7]  <= ~used_way_i[0];
					else               plru_bits_q[set_i][8]  <= ~used_way_i[0];
				end else begin
					plru_bits_q[set_i][4] <= ~used_way_i[1]; // LR
					if (!used_way_i[1]) plru_bits_q[set_i][9]  <= ~used_way_i[0];
					else               plru_bits_q[set_i][10] <= ~used_way_i[0];
				end
			end else begin
				plru_bits_q[set_i][2] <= ~used_way_i[2]; // R node
				if (!used_way_i[2]) begin
					plru_bits_q[set_i][5] <= ~used_way_i[1]; // RL
					if (!used_way_i[1]) plru_bits_q[set_i][11] <= ~used_way_i[0];
					else               plru_bits_q[set_i][12] <= ~used_way_i[0];
				end else begin
					plru_bits_q[set_i][6] <= ~used_way_i[1]; // RR
					if (!used_way_i[1]) plru_bits_q[set_i][13] <= ~used_way_i[0];
					else               plru_bits_q[set_i][14] <= ~used_way_i[0];
				end
			end
		end
	end

	// Combinational victim selection for current set
	reg d3, d2, d1, d0;
	reg [3:0] plru_leaf_victim;
	reg [3:0] invalid_choice;
	reg       has_invalid;

	integer k;
	always @(*) begin
		// Walk the PLRU tree
		d3 = plru_bits_q[set_i][0];
		if (!d3) begin
			d2 = plru_bits_q[set_i][1];
			if (!d2) begin
				d1 = plru_bits_q[set_i][3];
				if (!d1) d0 = plru_bits_q[set_i][7]; else d0 = plru_bits_q[set_i][8];
			end else begin
				d1 = plru_bits_q[set_i][4];
				if (!d1) d0 = plru_bits_q[set_i][9]; else d0 = plru_bits_q[set_i][10];
			end
		end else begin
			d2 = plru_bits_q[set_i][2];
			if (!d2) begin
				d1 = plru_bits_q[set_i][5];
				if (!d1) d0 = plru_bits_q[set_i][11]; else d0 = plru_bits_q[set_i][12];
			end else begin
				d1 = plru_bits_q[set_i][6];
				if (!d1) d0 = plru_bits_q[set_i][13]; else d0 = plru_bits_q[set_i][14];
			end
		end
		plru_leaf_victim = {d3, d2, d1, d0};

		// Invalid-first preference
		has_invalid = 1'b0;
		invalid_choice = 4'd0;
		for (k = 0; k < NUM_WAYS; k = k + 1) begin
			if (!valid_i[k] && !has_invalid) begin
				invalid_choice = k[3:0];
				has_invalid = 1'b1;
			end
		end

		victim_o = has_invalid ? invalid_choice : plru_leaf_victim;
	end

endmodule



