// rv64_l2_plru.v - 8-way PLRU (7-bit tree) with invalid-first victim
`timescale 1ns/1ps

module rv64_l2_plru (
	input              clk,
	input              rst_n,

	// Set index to operate on (256 sets → 8 bits)
	input      [7:0]   set,

	// Assert to update PLRU state for the given set/way
	input              access,
	input      [3:0]   used_way,   // 0..7 (bit [3] unused)

	// Valid mask for ways in the indexed set (1 = valid). Used for invalid-first victim
	input     [7:0]   valid,

	// Selected victim way index (prefers any invalid; else PLRU tree walk)
	output reg [3:0]   victim
);

	localparam integer NUM_SETS = 256;
	localparam integer NUM_WAYS = 8;

	// Per-set PLRU bits: 7-bit tree for 8 ways
	// [0]=root,
	// [1]=L node (d2=0), [2]=R node (d2=1),
	// [3]=LL (d2=0,d1=0), [4]=LR (d2=0,d1=1), [5]=RL (d2=1,d1=0), [6]=RR (d2=1,d1=1)
	reg [6:0] plru_bits_q [0:NUM_SETS-1];

	integer si;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			for (si = 0; si < NUM_SETS; si = si + 1) begin
				plru_bits_q[si] <= 7'b0;
			end
		end else if (access) begin
			// Update bits along the path to the accessed way to point to the sibling
			plru_bits_q[set][0] <= ~used_way[2]; // root
			if (!used_way[2]) begin
				plru_bits_q[set][1] <= ~used_way[1]; // L node
				if (!used_way[1]) plru_bits_q[set][3] <= ~used_way[0]; // LL
				else              plru_bits_q[set][4] <= ~used_way[0]; // LR
			end else begin
				plru_bits_q[set][2] <= ~used_way[1]; // R node
				if (!used_way[1]) plru_bits_q[set][5] <= ~used_way[0]; // RL
				else              plru_bits_q[set][6] <= ~used_way[0]; // RR
			end
		end
	end

	// Combinational victim selection for current set
	reg d2, d1, d0;
	reg [3:0] plru_leaf_victim;
	reg [3:0] invalid_choice;
	reg       has_invalid;

	integer k;
	always @(*) begin
		// Walk the PLRU tree
		d2 = plru_bits_q[set][0];
		if (!d2) begin
			d1 = plru_bits_q[set][1];
			if (!d1) d0 = plru_bits_q[set][3]; else d0 = plru_bits_q[set][4];
		end else begin
			d1 = plru_bits_q[set][2];
			if (!d1) d0 = plru_bits_q[set][5]; else d0 = plru_bits_q[set][6];
		end
		plru_leaf_victim = {1'b0, d2, d1, d0};

		// Invalid-first preference
		has_invalid = 1'b0;
		invalid_choice = 4'd0;
		for (k = 0; k < NUM_WAYS; k = k + 1) begin
			if (!valid[k] && !has_invalid) begin
				invalid_choice = k[3:0];
				has_invalid = 1'b1;
			end
		end

		victim = has_invalid ? invalid_choice : plru_leaf_victim;
	end

endmodule
