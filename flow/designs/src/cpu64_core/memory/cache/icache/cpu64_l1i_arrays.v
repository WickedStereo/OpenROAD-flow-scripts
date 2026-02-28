// -------------------------------------------------------------
// Arrays: cpu64_l1i_arrays — data/tag/valid only
// -------------------------------------------------------------
`timescale 1ns/1ps
module cpu64_l1i_arrays (
  input               clk_i,
  input               rst_ni,
  input               invalidate_all_i,

  // Access controls
  input       [5:0]   index_i,      // set index (64 sets)
  input       [2:0]   word_sel_i,   // word within line (8 words)
  input       [2:0]   way_sel_i,    // selected way for write
  input               write_en_i,   // write enable for selected way/word
  input               set_valid_i,
  input      [51:0]   tag_in_i,
  input      [63:0]   wdata_i,

  // Outputs for current index/word
  output     [63:0]   rdata_selected_o,
  output     [51:0]   tag_selected_o,
  output              valid_selected_o,

  output [8*64-1:0]   rdata_way_flat_o,
  output [8*52-1:0]   tag_way_flat_o,
  output      [7:0]   valid_way_o
);
  localparam integer DATA_W          = 64;
  localparam integer TAG_W           = 52;
  localparam integer WORDS_PER_LINE  = 8;  // 64B / 8B
  localparam integer WAYS            = 8;
  localparam integer SETS            = 64;
  localparam integer LINE_ADDR_W     = 9;  // 6 (index) + 3 (word)

  // data_q[way][{index,word}]
  reg [DATA_W-1:0] data_q [0:WAYS-1][0:SETS*WORDS_PER_LINE-1];
  reg [TAG_W-1:0]  tag_q  [0:WAYS-1][0:SETS-1];
  reg              valid_q[0:WAYS-1][0:SETS-1];

  wire [LINE_ADDR_W-1:0] line_idx = {index_i, word_sel_i};

  assign rdata_selected_o = data_q[way_sel_i][line_idx];
  assign tag_selected_o   = tag_q[way_sel_i][index_i];
  assign valid_selected_o = valid_q[way_sel_i][index_i];

  genvar w; generate
    for (w = 0; w < WAYS; w = w + 1) begin : g_flat
      assign rdata_way_flat_o[(w+1)*DATA_W-1 : w*DATA_W] = data_q[w][line_idx];
      assign tag_way_flat_o[(w+1)*TAG_W-1    : w*TAG_W]  = tag_q[w][index_i];
      assign valid_way_o[w] = valid_q[w][index_i];
    end
  endgenerate

  integer i, j, k;
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (i = 0; i < WAYS; i = i + 1) begin
        for (j = 0; j < SETS; j = j + 1) begin
          valid_q[i][j] <= 1'b0;
        end
        // Initialize data arrays to prevent X propagation
        for (k = 0; k < SETS*WORDS_PER_LINE; k = k + 1) begin
          data_q[i][k] <= 64'd0;
        end
      end
    end else if (invalidate_all_i) begin
      for (i = 0; i < WAYS; i = i + 1) begin
        for (j = 0; j < SETS; j = j + 1) begin
          valid_q[i][j] <= 1'b0;
        end
      end
    end else if (write_en_i) begin
      // Full-beat writes during refill
      data_q[way_sel_i][line_idx] <= wdata_i;
      tag_q[way_sel_i][index_i]   <= tag_in_i;
      valid_q[way_sel_i][index_i] <= set_valid_i;
    end
  end
endmodule


