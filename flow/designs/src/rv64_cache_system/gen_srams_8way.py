import os

header = """\
`timescale 1ns/1ps
`include "params.vh"

"""

def gen_l2_arrays():
    s = header + "module rv64_l2_arrays_sram (\n"
    s += "\tinput               clk,\n"
    s += "\tinput               rst_n,\n"
    s += "\tinput       [7:0]   index,\n"
    s += "\tinput       [2:0]   word_sel,\n"
    s += "\tinput       [2:0]   way_sel,\n"
    s += "\tinput               data_we,\n"
    s += "\tinput               tag_we,\n"
    s += "\tinput       [7:0]   be,\n"
    s += "\tinput      [49:0]   tag_in,\n"
    s += "\tinput      [63:0]   wdata,\n"
    s += "\toutput     [63:0]   rdata_selected,\n"
    s += "\toutput     [49:0]   tag_selected,\n"
    s += "\toutput [8*64-1:0]  rdata_way_flat,\n"
    s += "\toutput [8*50-1:0]  tag_way_flat\n"
    s += ");\n\n"

    s += "\t// Tag Array: 16 ways * 50 bits. Macro: 64x256. 1 per way -> 16 macros.\n"
    for w in range(8):
        s += f"\twire [63:0] tag_dout_{w};\n"
        s += f"\tassign tag_way_flat[{w*50+49}:{w*50}] = tag_dout_{w}[49:0];\n"
        s += f"\twire tag_we_{w} = tag_we & (way_sel == 3'd{w});\n"
        # Always read tags
        s += f"""\
\tsky130_sram_1rw1r_64x256_8 tag_sram_{w} (
\t\t.clk0(clk), .csb0(~tag_we_{w}), .web0(~tag_we_{w}),
\t\t.wmask0(8'hFF), .addr0(index), .din0({{14'b0, tag_in}}), .dout0(),
\t\t.clk1(clk), .csb1(1'b0), .addr1(index), .dout1(tag_dout_{w})
\t);
"""
# Note: Since RTL reads are combinational, but SRAM is synchronous, the read address 'index' is presented in cycle N, data returned cycle N+1.
# Here, we use port 1 for clean continuous reading of tag and data.

    s += "\n\t// Data Array: 16 ways * 8 words * 64 bits.\n"
    s += "\t// Using 64 instances of 128x256: 8 macros per word_sel.\n"
    
    for word in range(8):
        for m in range(8):
            way0 = m * 2
            way1 = m * 2 + 1
            s += f"\twire [127:0] data_dout_{word}_{m};\n"
            s += f"\twire data_we_{word}_{m} = data_we & (word_sel == 3'd{word}) & ((way_sel == 3'd{way0}) | (way_sel == 3'd{way1}));\n"
            s += f"\twire [15:0] data_wmask_{word}_{m} = (way_sel == 3'd{way0}) ? {{8'h00, be}} : {{be, 8'h00}};\n"
            s += f"\twire [127:0] data_din_{word}_{m}  = (way_sel == 3'd{way0}) ? {{64'b0, wdata}} : {{wdata, 64'b0}};\n"
            # Read port 1
            s += f"\twire data_csen_r_{word}_{m} = ~(word_sel == 3'd{word});\n"
            s += f"""\
\tsky130_sram_1rw1r_128x256_8 data_sram_{word}_{m} (
\t\t.clk0(clk), .csb0(~data_we_{word}_{m}), .web0(~data_we_{word}_{m}),
\t\t.wmask0(data_wmask_{word}_{m}), .addr0(index), .din0(data_din_{word}_{m}), .dout0(),
\t\t.clk1(clk), .csb1(data_csen_r_{word}_{m}), .addr1(index), .dout1(data_dout_{word}_{m})
\t);
"""
    s += "\n\t// Data Output Muxing\n"
    for w in range(8):
        m = w // 2
        is_upper = (w % 2 == 1)
        s += f"\twire [63:0] rdata_way_{w};\n"
        s += "\tassign rdata_way_{w} = \n".replace("{w}", str(w))
        for word in range(8):
            v_select = f"data_dout_{word}_{m}[127:64]" if is_upper else f"data_dout_{word}_{m}[63:0]"
            s += f"\t\t(word_sel == 3'd{word}) ? {v_select} : \n"
        s += "\t\t64'b0;\n"
        s += f"\tassign rdata_way_flat[{w*64+63}:{w*64}] = rdata_way_{w};\n"
        
    s += "\n\tassign rdata_selected = \n"
    for w in range(8):
        s += f"\t\t(way_sel == 3'd{w}) ? rdata_way_{w} : \n"
    s += "\t\t64'b0;\n"

    s += "\n\tassign tag_selected = \n"
    for w in range(8):
        s += f"\t\t(way_sel == 3'd{w}) ? tag_way_flat[{w*50+49}:{w*50}] : \n"
    s += "\t\t50'b0;\n"
    s += "endmodule\n"
    return s


def gen_l1_arrays():
    s = header + "module rv64_l1_arrays_sram (\n"
    s += "\tinput               clk,\n"
    s += "\tinput               rst_n,\n"
    s += "\tinput               invalidate_all,\n"
    s += "\tinput       [4:0]   index,\n"
    s += "\tinput       [2:0]   word_sel,\n"
    s += "\tinput       [2:0]   way_sel,\n"
    s += "\tinput               write_en,\n"
    s += "\tinput       [1:0]   state,\n"
    s += "\tinput       [7:0]   be,\n"
    s += "\tinput      [52:0]   tag_in,\n"
    s += "\tinput      [63:0]   wdata,\n"
    s += "\toutput     [63:0]   rdata_selected,\n"
    s += "\toutput     [52:0]   tag_selected,\n"
    s += "\toutput     [1:0]    state_selected,\n"
    s += "\toutput [8*64-1:0]   rdata_way_flat,\n"
    s += "\toutput [8*53-1:0]   tag_way_flat,\n"
    s += "\toutput [8*2-1:0]    state_way_flat\n"
    s += ");\n\n"

    s += "\treg [1:0] state_q[0:7][0:31];\n"
    s += "\tassign state_selected = state_q[way_sel][index];\n"
    for w in range(8):
        s += f"\tassign state_way_flat[{w*2+1}:{w*2}] = state_q[{w}][index];\n"
        
    s += """\
\tinteger i, j;
\talways @(posedge clk or negedge rst_n) begin
\t\tif (!rst_n) begin
\t\t\tfor (i = 0; i < 8; i = i + 1) begin
\t\t\t\tfor (j = 0; j < 32; j = j + 1) begin
\t\t\t\t\tstate_q[i][j] <= 2'b0; // MESI_N = 0
\t\t\t\tend
\t\t\tend
\t\tend else if (invalidate_all) begin
\t\t\tfor (i = 0; i < 8; i = i + 1) begin
\t\t\t\tfor (j = 0; j < 32; j = j + 1) begin
\t\t\t\t\tstate_q[i][j] <= 2'b0;
\t\t\t\tend
\t\t\tend
\t\tend else if (write_en) begin
\t\t\tstate_q[way_sel][index] <= state;
\t\tend
\tend
"""
    s += "\t// Tag Array: 8 ways * 53 bits (Macro: 80x64)\n"
    for w in range(8):
        s += f"\twire [79:0] tag_dout_{w};\n"
        s += f"\tassign tag_way_flat[{w*53+52}:{w*53}] = tag_dout_{w}[52:0];\n"
        s += f"\twire tag_we_{w} = write_en & (way_sel == 3'd{w});\n"
        s += f"""\
\tsky130_sram_1rw1r_80x64_8 tag_sram_{w} (
\t\t.clk0(clk), .csb0(~tag_we_{w}), .web0(~tag_we_{w}),
\t\t.wmask0(10'h3FF), .addr0({{1'b0, index}}), .din0({{27'b0, tag_in}}), .dout0(),
\t\t.clk1(clk), .csb1(1'b0), .addr1({{1'b0, index}}), .dout1(tag_dout_{w})
\t);
"""

    s += "\n\t// Data Array: 8 ways * 64 bits (Macro: 64x256) indexed by {index, word_sel}\n"
    for w in range(8):
        s += f"\twire [63:0] data_dout_{w};\n"
        s += f"\tassign rdata_way_flat[{w*64+63}:{w*64}] = data_dout_{w};\n"
        s += f"\twire data_we_{w} = write_en & (way_sel == 3'd{w});\n"
        s += f"""\
\tsky130_sram_1rw1r_64x256_8 data_sram_{w} (
\t\t.clk0(clk), .csb0(~data_we_{w}), .web0(~data_we_{w}),
\t\t.wmask0(be), .addr0({{index, word_sel}}), .din0(wdata), .dout0(),
\t\t.clk1(clk), .csb1(1'b0), .addr1({{index, word_sel}}), .dout1(data_dout_{w})
\t);
"""
    s += "\n\tassign rdata_selected = \n"
    for w in range(8):
        s += f"\t\t(way_sel == 3'd{w}) ? data_dout_{w} : \n"
    s += "\t\t64'b0;\n"

    s += "\n\tassign tag_selected = \n"
    for w in range(8):
        s += f"\t\t(way_sel == 3'd{w}) ? tag_dout_{w}[52:0] : \n"
    s += "\t\t53'b0;\n"
    s += "endmodule\n"
    return s


def gen_l2_directory():
    s = header + "module rv64_l2_directory_sram #(\n"
    s += "\tparameter SETS = 256,\n"
    s += "\tparameter WAYS = 8,\n"
    s += "\tparameter CORES = 4\n"
    s += ") (\n"
    s += "\tinput  wire clk,\n"
    s += "\tinput  wire rst_n,\n"
    s += "\tinput  wire [7:0]               rd_set,\n"
    s += "\toutput wire [7:0]              rd_valid,\n"
    s += "\toutput wire [31:0]              rd_sharers,\n"
    s += "\toutput wire [7:0]              rd_owner_valid,\n"
    s += "\toutput wire [15:0]              rd_owner_id,\n"
    s += "\toutput wire [7:0]              rd_dirty,\n"
    s += "\tinput  wire                     we,\n"
    s += "\tinput  wire [7:0]               wr_set,\n"
    s += "\tinput  wire [2:0]               wr_way,\n"
    s += "\tinput  wire                     wr_valid,\n"
    s += "\tinput  wire [3:0]               wr_sharers,\n"
    s += "\tinput  wire                     wr_owner_valid,\n"
    s += "\tinput  wire [1:0]               wr_owner_id,\n"
    s += "\tinput  wire                     wr_dirty\n"
    s += ");\n\n"
    s += "\twire safe_valid = wr_valid;\n"
    s += "\twire safe_owner_valid = wr_dirty ? 1'b1 : wr_owner_valid;\n"
    s += "\twire [3:0] safe_sharers = safe_owner_valid ? 4'b0 : wr_sharers;\n"
    s += "\twire [1:0] safe_owner_id = wr_owner_id;\n"
    s += "\twire safe_dirty = wr_dirty;\n"
    s += "\n\twire [8:0] wr_entry_packed = {safe_dirty, safe_owner_id, safe_owner_valid, safe_sharers, safe_valid};\n"
    s += "\n\t// Each entry is 16 bits. Ways 0..7 go to macro 0, Ways 8..15 go to macro 1.\n"
    
    # Write routing
    s += "\twire [15:0] wr_wmask_0 = (we && ~wr_way[3]) ? (16'h0003 << (wr_way[2:0] * 2)) : 16'h0000;\n"
    s += "\twire [15:0] wr_wmask_1 = (we &&  wr_way[3]) ? (16'h0003 << (wr_way[2:0] * 2)) : 16'h0000;\n"
    s += "\twire [127:0] wr_din_0;\n\twire [127:0] wr_din_1;\n"
    for w in range(8):
        s += f"\tassign wr_din_0[{w*16+15}:{w*16}] = {{7'b0, wr_entry_packed}};\n"
        s += f"\tassign wr_din_1[{w*16+15}:{w*16}] = {{7'b0, wr_entry_packed}};\n"
        
    s += "\n\twire [127:0] dout_0;\n\twire [127:0] dout_1;\n"
    s += "\n\twire csb_write_0 = ~(we & ~wr_way[3]);\n"
    s += "\twire csb_write_1 = ~(we &  wr_way[3]);\n"
    s += """\
\tsky130_sram_1rw1r_128x256_8 dir_sram_0 (
\t\t.clk0(clk), .csb0(csb_write_0), .web0(csb_write_0),
\t\t.wmask0(wr_wmask_0), .addr0(wr_set), .din0(wr_din_0), .dout0(),
\t\t.clk1(clk), .csb1(1'b0), .addr1(rd_set), .dout1(dout_0)
\t);

\tsky130_sram_1rw1r_128x256_8 dir_sram_1 (
\t\t.clk0(clk), .csb0(csb_write_1), .web0(csb_write_1),
\t\t.wmask0(wr_wmask_1), .addr0(wr_set), .din0(wr_din_1), .dout0(),
\t\t.clk1(clk), .csb1(1'b0), .addr1(rd_set), .dout1(dout_1)
\t);
"""

    # Read output unpacking
    for w in range(8):
        is_upper = w >= 8
        m_w = w % 8
        src = f"dout_1[{m_w*16+8}:{m_w*16}]" if is_upper else f"dout_0[{m_w*16+8}:{m_w*16}]"
        s += f"\twire [8:0] rd_entry_{w} = {src};\n"
        s += f"\tassign rd_valid[{w}] = rd_entry_{w}[0];\n"
        s += f"\tassign rd_sharers[{w*4+3}:{w*4}] = rd_entry_{w}[4:1];\n"
        s += f"\tassign rd_owner_valid[{w}] = rd_entry_{w}[5];\n"
        s += f"\tassign rd_owner_id[{w*2+1}:{w*2}] = rd_entry_{w}[7:6];\n"
        s += f"\tassign rd_dirty[{w}] = rd_entry_{w}[8];\n"

    s += "endmodule\n"
    return s

with open("rv64_l2_arrays_sram.v", "w") as f:
    f.write(gen_l2_arrays())
    
with open("rv64_l1_arrays_sram.v", "w") as f:
    f.write(gen_l1_arrays())
    
with open("rv64_l2_directory_sram.v", "w") as f:
    f.write(gen_l2_directory())

