///////////////////////////////////////////////////////////////////////////////////////////////////
// Open Bus Interface Host Driver (read-only friendly)
//  - Single-outstanding read semantics
//  - Rewinds ALL outputs (we/be/addr/wdata) only while waiting for response
//  - No request-stall feedback upstream (avoids req/gnt deadlock with FE)
///////////////////////////////////////////////////////////////////////////////////////////////////
module cpu64_obi_host_driver_icache #(
    parameter DATA_W  = 64,
    parameter ADDR_W  = 39,
    parameter BE_BITS = (DATA_W / 8)
) (
    //===================== Clock and Reset =====================//
    input                       clk_i,
    input                       rst_ni,         // Active-low reset

    //===================== Memory Interface ===================//
    input                       gnt_i,          // Bus grant
    input                       rvalid_i,       // Read data valid

    //===================== Pipeline Control ===================//
    input                       stall_i,        // Pipeline stall signal (prevents issuing new requests)

    //===================== Host Memory Controls ===============//
    input      [BE_BITS-1:0]    be_i,           // Byte enable strobe
    input      [ADDR_W-1:0]     addr_i,         // Address
    input      [DATA_W-1:0]     wdata_i,        // Write data (not used for reads)
    input                       rd_i,           // Read request
    input                       wr_i,           // Write request (ignored; host is RO)

    //===================== Memory Interface Outputs ===========//
    output wire                 stall_ao,       // Export *response* stall only
    output wire                 req_o,          // Request
    output wire                 we_ao,          // Write enable (always 0 here)
    output wire [BE_BITS-1:0]   be_ao,          // Byte enable
    output wire [ADDR_W-1:0]    addr_ao,        // Address
    output wire [DATA_W-1:0]    wdata_ao        // Write data
);

    //===================== Saved Transaction Parameters ========//
    reg [ADDR_W-1:0]    addr_saved;
    reg [DATA_W-1:0]    wdata_saved;
    reg [BE_BITS-1:0]   be_saved;
    reg                 we_saved;
    reg                 read_saved;

    //===================== Control =============================//
    reg  read_outstanding_q;        // one in-flight read
    wire response_stall_a = read_outstanding_q & ~rvalid_i;

    // Issue policy:
    //  - When no outstanding read AND not stalled: drive req_o from rd_i
    //  - When outstanding OR stalled: hold req_o low
    // BUG FIX: Respect stall_i to prevent issuing requests during pipeline stalls
    assign req_o = (read_outstanding_q || stall_i) ? 1'b0 : rd_i;

    // Accept = our req and bus gnt in same cycle
    wire req_accept = req_o & gnt_i;

    // Advance outstanding state
    always @(posedge clk_i) begin
        if (!rst_ni) begin
            read_outstanding_q <= 1'b0;
        end else begin
            // becomes outstanding when a read is accepted
            if (req_accept)         read_outstanding_q <= 1'b1;
            // clears when the response returns
            else if (rvalid_i)      read_outstanding_q <= 1'b0;
        end
    end

    // Capture parameters ON ACCEPT (current values)
    always @(posedge clk_i) begin
        if (!rst_ni) begin
            read_saved  <= 1'b0;
            we_saved    <= 1'b0;
            be_saved    <= {BE_BITS{1'b0}};
            addr_saved  <= {ADDR_W{1'b0}};
            wdata_saved <= {DATA_W{1'b0}};
        end else if (req_accept) begin
            read_saved  <= rd_i;
            we_saved    <= wr_i;
            be_saved    <= be_i;
            addr_saved  <= addr_i;
            wdata_saved <= wdata_i;
        end
    end

    //===================== Outputs =============================//

    // While waiting for response, hold the accepted parameters stable.
    wire rewinding = response_stall_a;

    assign we_ao    = 1'b0;                           // read-only host
    assign be_ao    = rewinding ? be_saved    : be_i;
    assign addr_ao  = rewinding ? addr_saved  : addr_i;
    assign wdata_ao = rewinding ? wdata_saved : wdata_i;

    // Export **response-only** stall so upstream isn’t blocked before accept
    assign stall_ao = response_stall_a;

endmodule
