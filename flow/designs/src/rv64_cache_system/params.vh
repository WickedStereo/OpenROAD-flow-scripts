`ifndef PARAMS_VH
`define PARAMS_VH

localparam integer NUM_CORES = 4;
localparam integer LINE_BYTES = 64;

// L1 Cache
localparam integer L1_SIZE_BYTES = 16 * 1024;
localparam integer L1_WAYS = 8;
localparam integer L1_SETS = L1_SIZE_BYTES / (L1_WAYS * LINE_BYTES); // 32

// L2 Cache
localparam integer L2_SIZE_BYTES = 256 * 1024;
localparam integer L2_WAYS = 16;
localparam integer L2_SETS = L2_SIZE_BYTES / (L2_WAYS * LINE_BYTES); // 256

// Coherence States (NBTT)
localparam [1:0] MESI_N  = 2'b00; // Invalid
localparam [1:0] MESI_B  = 2'b01; // Branch (Shared)
localparam [1:0] MESI_T  = 2'b10; // Trunk (Exclusive Clean / Exclusive)
localparam [1:0] MESI_TT = 2'b11; // Trunk (Exclusive Dirty / Modified)

// TileLink Opcodes
// Channel A
localparam [2:0] A_PUT_FULL_DATA    = 3'd0;
localparam [2:0] A_PUT_PARTIAL_DATA = 3'd1;
localparam [2:0] A_ARITHMETIC_DATA  = 3'd2;
localparam [2:0] A_LOGICAL_DATA     = 3'd3;
localparam [2:0] A_GET              = 3'd4;
localparam [2:0] A_INTENT           = 3'd5;
localparam [2:0] A_ACQUIRE_BLOCK    = 3'd6;
localparam [2:0] A_ACQUIRE_PERM     = 3'd7;

// Channel B
localparam [2:0] B_PUT_FULL_DATA    = 3'd0;
localparam [2:0] B_PUT_PARTIAL_DATA = 3'd1;
localparam [2:0] B_ARITHMETIC_DATA  = 3'd2;
localparam [2:0] B_LOGICAL_DATA     = 3'd3;
localparam [2:0] B_GET              = 3'd4;
localparam [2:0] B_INTENT           = 3'd5;
localparam [2:0] B_PROBE            = 3'd6;
localparam [2:0] B_PROBE_PERM       = 3'd7; // Not standard, usually just ProbeBlock/Perm mapped to 6/7

// Channel C
localparam [2:0] C_ACCESS_ACK       = 3'd0;
localparam [2:0] C_ACCESS_ACK_DATA  = 3'd1;
localparam [2:0] C_HINT_ACK         = 3'd2;
localparam [2:0] C_PROBE_ACK        = 3'd4;
localparam [2:0] C_PROBE_ACK_DATA   = 3'd5;
localparam [2:0] C_RELEASE          = 3'd6;
localparam [2:0] C_RELEASE_DATA     = 3'd7;

// Channel D
localparam [2:0] D_ACCESS_ACK       = 3'd0;
localparam [2:0] D_ACCESS_ACK_DATA  = 3'd1;
localparam [2:0] D_HINT_ACK         = 3'd2;
localparam [2:0] D_GRANT            = 3'd4;
localparam [2:0] D_GRANT_DATA       = 3'd5;
localparam [2:0] D_RELEASE_ACK      = 3'd6;

// TileLink Params
// Cap types (Grow)
localparam [2:0] NtoB = 3'd0;
localparam [2:0] NtoT = 3'd1;
localparam [2:0] BtoT = 3'd2;

// Cap types (Shrink/Report)
localparam [2:0] TtoB = 3'd0;
localparam [2:0] TtoN = 3'd1;
localparam [2:0] BtoN = 3'd2;
localparam [2:0] TtoT = 3'd3;
localparam [2:0] BtoB = 3'd4;
localparam [2:0] NtoN = 3'd5;

`endif
