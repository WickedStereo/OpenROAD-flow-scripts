// cpu64_obi_receiver.v - Small OBI receiver shim for L1 cache integration
`timescale 1ns/1ps

module cpu64_obi_receiver #(
    parameter CORE_ADDR_W = 39,
    parameter DATA_W      = 64
) (
    // Clocks/Reset
    input                  clk_i,
    input                  rst_ni,

    // Core-side OBI (host driver facing)
    input                  req_i,
    input                  we_i,
    input        [7:0]     be_i,
    input  [CORE_ADDR_W-1:0] addr_i,
    input  [DATA_W-1:0]    wdata_i,
    output reg             gnt_o,
    output reg             rvalid_o,
    output reg [DATA_W-1:0] rdata_o,
    // Atomic operation inputs
    input                  amo_i,          // Atomic operation flag (excludes LR/SC)
    input                  lr_i,           // Load-Reserved flag
    input                  sc_i,           // Store-Conditional flag
    input        [4:0]     amo_op_i,       // Atomic operation type
    input                  amo_word_i,     // Atomic word operation flag

    // L1 CPU-side interface
    output reg             l1_req_o,
    output reg             l1_we_o,
    output reg     [7:0]   l1_be_o,
    output reg    [63:0]   l1_addr_o,
    output reg    [63:0]   l1_wdata_o,
    input                  l1_gnt_i,
    input                  l1_rvalid_i,
    input        [63:0]    l1_rdata_i,
    // Atomic operation outputs to L1
    output reg             l1_amo_o,       // Atomic operation flag
    output reg             l1_lr_o,        // Load-Reserved flag
    output reg             l1_sc_o,        // Store-Conditional flag
    output reg     [4:0]   l1_amo_op_o,    // Atomic operation type
    output reg             l1_amo_word_o   // Atomic word operation flag
);

    // Any atomic operation (AMO, LR, or SC)
    wire is_any_atomic = amo_i || lr_i || sc_i;

    // Simple one-outstanding request tracker
    reg outstanding_q, outstanding_n;
    reg we_q, we_n;

    // Default combinational
    always @(*) begin
        // Drive-through to L1 each cycle
        l1_req_o   = req_i && (~outstanding_q);
        l1_we_o    = we_i;
        l1_be_o    = be_i;
        l1_addr_o  = { { (64-CORE_ADDR_W){1'b0} }, addr_i };
        l1_wdata_o = wdata_i;
        // Atomic operation pass-through
        l1_amo_o      = amo_i;
        l1_lr_o       = lr_i;
        l1_sc_o       = sc_i;
        l1_amo_op_o   = amo_op_i;
        l1_amo_word_o = amo_word_i;

        // Grant semantics: only grant to core when L1 grants (proper OBI protocol)
        gnt_o      = l1_gnt_i;

        // Response from L1 is forwarded as-is
        rvalid_o   = l1_rvalid_i;
        rdata_o    = l1_rdata_i;

`ifdef VERILATOR
        if (l1_rvalid_i) begin
            $display("[OBI_RX] L1 rvalid=1, l1_rdata=0x%016h → rdata_o", l1_rdata_i);
        end
`endif

        // Track outstanding only for reads and atomic operations (stores complete on accept)
        we_n           = we_i;
        outstanding_n  = outstanding_q;

        // On a new accepted read request or atomic operation (when L1 grants), mark outstanding
        // LR and SC both need response tracking (LR returns value, SC returns 0/1)
        if (l1_gnt_i && l1_req_o && ((~we_i) || is_any_atomic)) begin
            outstanding_n = 1'b1;
        end
        // When read data or atomic response arrives, clear outstanding
        if (l1_rvalid_i) begin
            outstanding_n = 1'b0;
        end
    end

    // Sequential
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            outstanding_q <= 1'b0;
            we_q          <= 1'b0;
        end else begin
            outstanding_q <= outstanding_n;
            we_q          <= we_n;
        end
    end

`ifdef CPU64_DBG_TRACE
    //===================== Debug Trace ==========================//
    always @(posedge clk_i) begin
        if (rst_ni) begin
            if (req_i && gnt_o) begin
                $display("[OBI_RX] core_req we=%0b addr=0x%0h be=0x%02h wdata=0x%016h l1_gnt=%0b rvalid=%0b outstanding=%0b", 
                         we_i, addr_i, be_i, wdata_i, l1_gnt_i, l1_rvalid_i, outstanding_q);
            end
        end
    end
`endif

endmodule


