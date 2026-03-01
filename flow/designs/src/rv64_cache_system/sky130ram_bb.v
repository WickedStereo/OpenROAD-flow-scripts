(* blackbox *)
module sky130_sram_1rw1r_64x256_8(clk0, csb0, web0, wmask0, addr0, din0, dout0, clk1, csb1, addr1, dout1, vdd, gnd);
  inout vdd;
  inout gnd;
  input clk0, csb0, web0, clk1, csb1;
  input [7:0] wmask0;
  input [7:0] addr0, addr1;
  input [63:0] din0;
  output [63:0] dout0, dout1;
endmodule

(* blackbox *)
module sky130_sram_1rw1r_80x64_8(clk0, csb0, web0, wmask0, addr0, din0, dout0, clk1, csb1, addr1, dout1, vdd, gnd);
  inout vdd;
  inout gnd;
  input clk0, csb0, web0, clk1, csb1;
  input [9:0] wmask0;
  input [5:0] addr0, addr1;
  input [79:0] din0;
  output [79:0] dout0, dout1;
endmodule

(* blackbox *)
module sky130_sram_1rw1r_128x256_8(clk0, csb0, web0, wmask0, addr0, din0, dout0, clk1, csb1, addr1, dout1, vdd, gnd);
  inout vdd;
  inout gnd;
  input clk0, csb0, web0, clk1, csb1;
  input [15:0] wmask0;
  input [7:0] addr0, addr1;
  input [127:0] din0;
  output [127:0] dout0, dout1;
endmodule

(* blackbox *)
module sky130_sram_1rw1r_44x64_8(clk0, csb0, web0, wmask0, addr0, din0, dout0, clk1, csb1, addr1, dout1, vdd, gnd);
  inout vdd;
  inout gnd;
  input clk0, csb0, web0, clk1, csb1;
  input [5:0] wmask0;
  input [5:0] addr0, addr1;
  input [43:0] din0;
  output [43:0] dout0, dout1;
endmodule
