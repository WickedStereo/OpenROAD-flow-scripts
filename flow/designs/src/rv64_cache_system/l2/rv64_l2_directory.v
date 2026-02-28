`timescale 1ns/1ps


module rv64_l2_directory #(
    parameter SETS = 256,
    parameter WAYS = 16,
    parameter CORES = 4
) (
    input  wire clk,
    input  wire rst_n,

    // Read Port (Read whole set)
    input  wire [$clog2(SETS)-1:0]  rd_set,
    output wire [WAYS-1:0]          rd_valid,
    output wire [WAYS*CORES-1:0]    rd_sharers,
    output wire [WAYS-1:0]          rd_owner_valid,
    output wire [WAYS*$clog2(CORES)-1:0] rd_owner_id,
    output wire [WAYS-1:0]          rd_dirty,

    // Write Port (Write specific way)
    input  wire                     we,
    input  wire [$clog2(SETS)-1:0]  wr_set,
    input  wire [$clog2(WAYS)-1:0]  wr_way,
    
    // Write Data
    input  wire                     wr_valid,
    input  wire [CORES-1:0]         wr_sharers,
    input  wire                     wr_owner_valid,
    input  wire [$clog2(CORES)-1:0] wr_owner_id,
    input  wire                     wr_dirty
);

    localparam OWNER_ID_W = $clog2(CORES);

    // Storage per way
    // We can store them as separate arrays or one big array.
    // Since we read all ways at once, separate arrays for each way might be easier to express 
    // or a single array of width (WAYS * BITS).
    
    // Let's use a single array of width WAYS * (Structure)
    // Structure: {dirty, owner_id, owner_valid, sharers, valid}
    localparam ENTRY_W = 1 + OWNER_ID_W + 1 + CORES + 1;
    
    reg [WAYS*ENTRY_W-1:0] ram [0:SETS-1];

    // Read Logic
    wire [WAYS*ENTRY_W-1:0] rd_data_raw;
    assign rd_data_raw = ram[rd_set];

    // Unpack Read Data
    genvar w;
    generate
        for (w = 0; w < WAYS; w = w + 1) begin : unpack_read
            wire [ENTRY_W-1:0] entry = rd_data_raw[w*ENTRY_W +: ENTRY_W];
            
            assign rd_valid[w] = entry[0];
            assign rd_sharers[w*CORES +: CORES] = entry[1 +: CORES];
            assign rd_owner_valid[w] = entry[1+CORES];
            assign rd_owner_id[w*OWNER_ID_W +: OWNER_ID_W] = entry[1+CORES+1 +: OWNER_ID_W];
            assign rd_dirty[w] = entry[1+CORES+1+OWNER_ID_W];
        end
    endgenerate

    // Write Logic
    // Enforce Invariants:
    // 1. dirty -> owner_valid
    // 2. owner_valid -> sharers == 0
    
    wire                     safe_valid;
    wire [CORES-1:0]         safe_sharers;
    wire                     safe_owner_valid;
    wire [OWNER_ID_W-1:0]    safe_owner_id;
    wire                     safe_dirty;

    assign safe_valid = wr_valid;
    assign safe_dirty = wr_dirty;
    
    // Rule: dirty -> owner_valid
    assign safe_owner_valid = wr_dirty ? 1'b1 : wr_owner_valid;
    
    // Rule: owner_valid -> sharers == 0
    assign safe_sharers = safe_owner_valid ? {CORES{1'b0}} : wr_sharers;
    
    assign safe_owner_id = wr_owner_id;

    wire [ENTRY_W-1:0] wr_entry_packed;
    assign wr_entry_packed = {safe_dirty, safe_owner_id, safe_owner_valid, safe_sharers, safe_valid};

    always @(posedge clk) begin
        if (we) begin
            ram[wr_set][wr_way*ENTRY_W +: ENTRY_W] <= wr_entry_packed;
        end
    end
    
    // Reset logic? 
    // Large arrays usually aren't reset. We rely on initialization or valid bits.
    // But for simulation/FPGA, we might want to zero it.
    // For ASIC, we'd loop through and invalidate.
    // Let's add a simulation-only initialization or a reset loop if strictly needed.
    // For now, let's assume the controller invalidates on startup or we use a loop.
    // To keep it simple and synthesizable as RAM, no async reset on the array.
    // We can add a "reset_all" state machine in the controller later.
    
    // However, for the testbench to work without X, let's initialize in `initial`.
    initial begin
        integer i;
        for (i = 0; i < SETS; i = i + 1) begin
            ram[i] = 0;
        end
    end

endmodule
