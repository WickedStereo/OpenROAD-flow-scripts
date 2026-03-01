`timescale 1ns/1ps

module tl_demux #(
    parameter N = 4,
    parameter DATA_W = 64,
    parameter SEL_W = 2
) (
    // Input (from Source)
    input                   valid_i,
    output                  ready_o,
    input  [DATA_W-1:0]     data_i,
    input  [SEL_W-1:0]      sel_i,

    // Outputs (to Sinks)
    output [N-1:0]          valid_o,
    input  [N-1:0]          ready_i,
    output [N*DATA_W-1:0]   data_o
);

    // Data is broadcast to all ports, but only the selected one gets valid
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_out
            assign data_o[i*DATA_W +: DATA_W] = data_i;
            assign valid_o[i] = valid_i && (sel_i == i[SEL_W-1:0]);
        end
    endgenerate

    // Ready is muxed back from the selected port
    // If sel_i is out of range, ready_o is 0 (or 1 if we want to sink it?)
    // Assuming sel_i is always valid for now.
    
    // We can use a simple mux for ready_o
    assign ready_o = ({{(32-SEL_W){1'b0}}, sel_i} < N) ? ready_i[sel_i] : 1'b0;

endmodule
