`timescale 1ns/1ps

module tl_arbiter #(
    parameter N = 4,
    parameter DATA_W = 100
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Inputs (N clients)
    input  wire [N-1:0]          valid_i,
    output reg  [N-1:0]          ready_o,
    input  wire [N*DATA_W-1:0]   data_i,

    // Output (1 sink)
    output reg                   valid_o,
    input  wire                  ready_i,
    output reg  [DATA_W-1:0]     data_o
);

    reg [N-1:0] mask;
    wire [N-1:0] masked_req = valid_i & mask;
    wire [N-1:0] raw_grant;
    wire [N-1:0] masked_grant;
    reg [N-1:0] grant;

    // Priority arbiters (fixed priority)
    // Find first set bit
    assign raw_grant[0] = valid_i[0];
    genvar i;
    generate
        for (i = 1; i < N; i = i + 1) begin : gen_raw_grant
            assign raw_grant[i] = valid_i[i] & ~|valid_i[i-1:0];
        end
    endgenerate

    assign masked_grant[0] = masked_req[0];
    generate
        for (i = 1; i < N; i = i + 1) begin : gen_masked_grant
            assign masked_grant[i] = masked_req[i] & ~|masked_req[i-1:0];
        end
    endgenerate

    // Final grant selection
    always @(*) begin
        if (|masked_req) begin
            grant = masked_grant;
        end else begin
            grant = raw_grant;
        end
    end

    // Output Muxing
    integer j;
    always @(*) begin
        data_o = {DATA_W{1'b0}};
        valid_o = 1'b0;
        ready_o = {N{1'b0}};
        
        for (j = 0; j < N; j = j + 1) begin
            if (grant[j]) begin
                data_o = data_i[j*DATA_W +: DATA_W];
                valid_o = valid_i[j];
                ready_o[j] = ready_i;
            end
        end
    end

    // Rotate priority
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= {N{1'b1}};
        end else if (valid_o && ready_i) begin
            // Rotate mask to start after the current grant
            // If grant[k] is set, mask bits 0..k become 0, bits k+1..N-1 become 1.
            // If grant[N-1] is set, mask becomes 0 (which wraps to raw_grant next cycle)
            mask <= ~(grant | (grant - 1'b1));
        end
    end

endmodule
