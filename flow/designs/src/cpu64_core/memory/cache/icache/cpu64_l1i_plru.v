// -------------------------------------------------------------
// PLRU: cpu64_l1i_plru — 8-way (invalid-first) for ICache
// -------------------------------------------------------------
`timescale 1ns/1ps
module cpu64_l1i_plru (
  input              clk_i,
  input              rst_ni,
  input      [5:0]   set_i,
  input              access_i,
  input      [2:0]   used_way_i,
  input      [7:0]   valid_i,
  output reg [2:0]   victim_o
);
  localparam integer NUM_SETS = 64;
  localparam integer NUM_WAYS = 8;

  reg [6:0] plru_bits_q [0:NUM_SETS-1];

  integer si;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (si = 0; si < NUM_SETS; si = si + 1) begin
        plru_bits_q[si] <= 7'b0;
      end
    end else if (access_i) begin
      // Update path for used_way_i (make sibling LRU)
      plru_bits_q[set_i][0] <= ~used_way_i[2];
      if (!used_way_i[2]) begin
        plru_bits_q[set_i][1] <= ~used_way_i[1];
        if (!used_way_i[1]) plru_bits_q[set_i][3] <= ~used_way_i[0];
        else                 plru_bits_q[set_i][4] <= ~used_way_i[0];
      end else begin
        plru_bits_q[set_i][2] <= ~used_way_i[1];
        if (!used_way_i[1]) plru_bits_q[set_i][5] <= ~used_way_i[0];
        else                 plru_bits_q[set_i][6] <= ~used_way_i[0];
      end
    end
  end

  // Combinational victim with invalid-first preference
  reg [2:0] plru_leaf_victim; reg [2:0] invalid_choice; reg has_invalid;
  integer k; reg d2, d1, d0;
  always @(*) begin
    // Tree walk
    d2 = plru_bits_q[set_i][0];
    if (!d2) begin
      d1 = plru_bits_q[set_i][1];
      d0 = (!d1) ? plru_bits_q[set_i][3] : plru_bits_q[set_i][4];
    end else begin
      d1 = plru_bits_q[set_i][2];
      d0 = (!d1) ? plru_bits_q[set_i][5] : plru_bits_q[set_i][6];
    end
    plru_leaf_victim = {d2,d1,d0};

    // Invalid-first
    has_invalid = 1'b0; invalid_choice = 3'd0;
    for (k = 0; k < NUM_WAYS; k = k + 1) begin
      if (!valid_i[k] && !has_invalid) begin
        invalid_choice = k[2:0]; has_invalid = 1'b1;
      end
    end
    victim_o = has_invalid ? invalid_choice : plru_leaf_victim;
  end
endmodule
