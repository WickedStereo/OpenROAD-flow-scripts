// cpu64_atomic_decoder.v - RV64A Atomic Instruction Decoder
// Decodes atomic memory operations (AMO) including LR/SC for word and doubleword operations
//
// Instruction Format (R-type for AMO):
// [31:27] = funct5 (AMO operation type)
// [26]    = aq (acquire - ignored for now)
// [25]    = rl (release - ignored for now)
// [24:20] = rs2 (source operand register, rs2=0 for LR)
// [19:15] = rs1 (address base register)
// [14:12] = funct3 (width: 010=W, 011=D)
// [11:7]  = rd (destination register)
// [6:0]   = opcode (0101111 for AMO)
//
// LR/SC Instructions:
//   LR.W/LR.D: Load-Reserved - loads value and sets reservation
//   SC.W/SC.D: Store-Conditional - stores if reservation valid, returns 0=success, 1=fail

`timescale 1ns/1ps

module cpu64_atomic_decoder (
    input  [31:0]   instr_i,        // Instruction to decode
    
    // Decoded outputs
    output          is_amo_o,       // Is this an AMO instruction (including LR/SC)?
    output          is_lr_o,        // Is this a Load-Reserved instruction?
    output          is_sc_o,        // Is this a Store-Conditional instruction?
    output [4:0]    amo_op_o,       // AMO operation type (funct5)
    output          amo_word_o,     // 1=word(.W), 0=doubleword(.D)
    output [4:0]    rs1_o,          // Address base register
    output [4:0]    rs2_o,          // Source operand register
    output [4:0]    rd_o            // Destination register
);

    // Instruction field extraction
    wire [6:0]  opcode  = instr_i[6:0];
    wire [4:0]  rd      = instr_i[11:7];
    wire [2:0]  funct3  = instr_i[14:12];
    wire [4:0]  rs1     = instr_i[19:15];
    wire [4:0]  rs2     = instr_i[24:20];
    wire        rl      = instr_i[25];
    wire        aq      = instr_i[26];
    wire [4:0]  funct5  = instr_i[31:27];

    // AMO opcode definition
    localparam [6:0] OPCODE_AMO = 7'b0101111;
    
    // funct3 encoding
    localparam [2:0] FUNCT3_W = 3'b010;  // Word (32-bit)
    localparam [2:0] FUNCT3_D = 3'b011;  // Doubleword (64-bit)
    
    // funct5 encodings for AMO operations
    localparam [4:0] AMO_ADD  = 5'b00000;
    localparam [4:0] AMO_SWAP = 5'b00001;
    localparam [4:0] AMO_LR   = 5'b00010;  // Load-Reserved (not implemented yet)
    localparam [4:0] AMO_SC   = 5'b00011;  // Store-Conditional (not implemented yet)
    localparam [4:0] AMO_XOR  = 5'b00100;
    localparam [4:0] AMO_OR   = 5'b01000;
    localparam [4:0] AMO_AND  = 5'b01100;
    localparam [4:0] AMO_MIN  = 5'b10000;
    localparam [4:0] AMO_MAX  = 5'b10100;
    localparam [4:0] AMO_MINU = 5'b11000;
    localparam [4:0] AMO_MAXU = 5'b11100;

    // Decode AMO instruction
    wire is_amo_opcode = (opcode == OPCODE_AMO);
    wire is_word_op    = (funct3 == FUNCT3_W);
    wire is_dword_op   = (funct3 == FUNCT3_D);
    wire valid_width   = is_word_op || is_dword_op;
    
    // LR/SC detection
    wire is_lr = (funct5 == AMO_LR);
    wire is_sc = (funct5 == AMO_SC);
    
    // Check if this is a supported AMO operation (now includes LR/SC)
    wire valid_amo_op = (funct5 == AMO_ADD)  ||
                        (funct5 == AMO_SWAP) ||
                        (funct5 == AMO_LR)   ||  // Load-Reserved
                        (funct5 == AMO_SC)   ||  // Store-Conditional
                        (funct5 == AMO_XOR)  ||
                        (funct5 == AMO_OR)   ||
                        (funct5 == AMO_AND)  ||
                        (funct5 == AMO_MIN)  ||
                        (funct5 == AMO_MAX)  ||
                        (funct5 == AMO_MINU) ||
                        (funct5 == AMO_MAXU);

    // Output assignments
    assign is_amo_o     = is_amo_opcode && valid_width && valid_amo_op;
    assign is_lr_o      = is_amo_opcode && valid_width && is_lr;
    assign is_sc_o      = is_amo_opcode && valid_width && is_sc;
    assign amo_op_o     = funct5;
    assign amo_word_o   = is_word_op;  // 1 for .W, 0 for .D
    assign rs1_o        = rs1;
    assign rs2_o        = rs2;
    assign rd_o         = rd;

endmodule
