// rv64_l1_plru.v - 8-way PLRU (7-bit tree) with invalid-first victim
// `timescale 1ns/1ps

module rv64_l1_plru #(
    parameter integer SETS = 32,
    parameter integer INDEX_W = 5
) (
	input              clk,
	input              rst_n,

	// Set index to operate on
	input      [INDEX_W-1:0]   set,

	// Assert to update PLRU state for the given set/way
	input              access,
	input      [2:0]   used_way,   // 0..7

	// Valid mask for ways in the indexed set (1 = valid). Used for invalid-first victim
	input      [7:0]   valid,

	// Selected victim way index (prefers any invalid; else PLRU tree walk)
	output reg [2:0]   victim
);

	// Fixed configuration per TODO doc
	localparam integer NUM_SETS = SETS;
	localparam integer NUM_WAYS = 8;

	// Per-set PLRU bits: [0]=root, [1]=L-L/R select, [2]=R-L/R select, [3..6]=leaf-level
	// Bit meaning: 0 selects left subtree as LRU; 1 selects right subtree as LRU
	reg [6:0] plru_bits_q [0:NUM_SETS-1];

	integer si;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			for (si = 0; si < NUM_SETS; si = si + 1) begin
				plru_bits_q[si] <= 7'b0; // Arbitrary init; invalid-first will dominate at cold
			end
		end else if (access) begin
			// Update bits along the path to the accessed way to point to the sibling (make sibling LRU)
			// Root
			plru_bits_q[set][0] <= ~used_way[2];
			if (!used_way[2]) begin
				// Left subtree
				plru_bits_q[set][1] <= ~used_way[1];
				if (!used_way[1]) begin
					// Left-Left
					plru_bits_q[set][3] <= ~used_way[0];
				end else begin
					// Left-Right
					plru_bits_q[set][4] <= ~used_way[0];
				end
			end else begin
				// Right subtree
				plru_bits_q[set][2] <= ~used_way[1];
				if (!used_way[1]) begin
					// Right-Left
					plru_bits_q[set][5] <= ~used_way[0];
				end else begin
					// Right-Right
					plru_bits_q[set][6] <= ~used_way[0];
				end
			end
		end
	end

	// Combinational victim selection for current set
	reg [2:0] plru_leaf_victim;
	reg [2:0] invalid_choice;
	reg       has_invalid;

	integer k;
    reg d2, d1, d0;
	always @(*) begin
		// Default: PLRU tree walk
		// Root
		// d2 = 0 -> go left subtree, d2 = 1 -> right subtree
		// d1 depends on chosen subtree; d0 depends on chosen sub-subtree
		// Bits mapping: [0]=root, [1]=L node, [2]=R node, [3]=LL, [4]=LR, [5]=RL, [6]=RR
		// Walk
		// Level 2 (MSB of way index)
		// If bit is 0 choose left (0), if 1 choose right (1)
		// Compose leaf index as {d2,d1,d0}
		d2 = plru_bits_q[set][0];
		if (!d2) begin
			d1 = plru_bits_q[set][1];
			if (!d1) d0 = plru_bits_q[set][3];
			else     d0 = plru_bits_q[set][4];
		end else begin
			d1 = plru_bits_q[set][2];
			if (!d1) d0 = plru_bits_q[set][5];
			else     d0 = plru_bits_q[set][6];
		end
		plru_leaf_victim = {d2, d1, d0};

		// Invalid-first preference
		has_invalid = 1'b0;
		invalid_choice = 3'd0;
		for (k = 0; k < NUM_WAYS; k = k + 1) begin
			if (!valid[k] && !has_invalid) begin
				invalid_choice = k[2:0];
				has_invalid = 1'b1;
			end
		end

		victim = has_invalid ? invalid_choice : plru_leaf_victim;
	end

endmodule


