// cpu64_atomic_alu.v - Atomic Memory Operation ALU
// Performs atomic read-modify-write operations for RV64A extension
//
// Supported Operations (Word and Doubleword):
//   Word Operations (.W, 32-bit):
//     - AMOSWAP.W:  new = operand
//     - AMOADD.W:   new = old + operand
//     - AMOXOR.W:   new = old ^ operand
//     - AMOAND.W:   new = old & operand  
//     - AMOOR.W:    new = old | operand
//     - AMOMIN.W:   new = min(old, operand) [signed]
//     - AMOMAX.W:   new = max(old, operand) [signed]
//     - AMOMINU.W:  new = min(old, operand) [unsigned]
//     - AMOMAXU.W:  new = max(old, operand) [unsigned]
//
//   Doubleword Operations (.D, 64-bit):
//     - AMOSWAP.D:  new = operand
//     - AMOADD.D:   new = old + operand
//     - AMOXOR.D:   new = old ^ operand
//     - AMOAND.D:   new = old & operand  
//     - AMOOR.D:    new = old | operand
//     - AMOMIN.D:   new = min(old, operand) [signed]
//     - AMOMAX.D:   new = max(old, operand) [signed]
//     - AMOMINU.D:  new = min(old, operand) [unsigned]
//     - AMOMAXU.D:  new = max(old, operand) [unsigned]
//
// The old value is returned to the CPU, new value is written to memory

`timescale 1ns/1ps

module cpu64_atomic_alu (
    input  [4:0]    amo_op_i,       // AMO operation type (funct5)
    input           amo_word_i,     // 1=word(.W), 0=doubleword(.D)
    input  [63:0]   old_value_i,    // Old value from memory
    input  [63:0]   operand_i,      // Operand value (from rs2)
    
    output reg [63:0] new_value_o   // New value to write to memory
);

    // AMO operation encodings (funct5)
    localparam [4:0] AMO_ADD  = 5'b00000;
    localparam [4:0] AMO_SWAP = 5'b00001;
    localparam [4:0] AMO_XOR  = 5'b00100;
    localparam [4:0] AMO_AND  = 5'b01100;
    localparam [4:0] AMO_OR   = 5'b01000;
    localparam [4:0] AMO_MIN  = 5'b10000;
    localparam [4:0] AMO_MAX  = 5'b10100;
    localparam [4:0] AMO_MINU = 5'b11000;
    localparam [4:0] AMO_MAXU = 5'b11100;

    // Extract 32-bit word values (for .W operations)
    wire [31:0] old_word  = old_value_i[31:0];
    wire [31:0] op_word   = operand_i[31:0];
    
    // Signed comparison for MIN/MAX (32-bit)
    wire signed [31:0] old_signed = old_word;
    wire signed [31:0] op_signed  = op_word;
    
    // Comparison results (32-bit)
    wire old_less_signed   = (old_signed < op_signed);
    wire old_less_unsigned = (old_word < op_word);
    
    // 32-bit result
    reg [31:0] result_word;

    // Atomic operation logic for word (.W) operations
    always @(*) begin
        // Default: pass through old value
        result_word = old_word;
        
        case (amo_op_i)
            AMO_SWAP: result_word = op_word;                                      // SWAP
            AMO_ADD:  result_word = old_word + op_word;                           // ADD
            AMO_XOR:  result_word = old_word ^ op_word;                           // XOR
            AMO_AND:  result_word = old_word & op_word;                           // AND
            AMO_OR:   result_word = old_word | op_word;                           // OR
            AMO_MIN:  result_word = old_less_signed   ? old_word : op_word;       // MIN (signed)
            AMO_MAX:  result_word = old_less_signed   ? op_word  : old_word;      // MAX (signed)
            AMO_MINU: result_word = old_less_unsigned ? old_word : op_word;       // MINU (unsigned)
            AMO_MAXU: result_word = old_less_unsigned ? op_word  : old_word;      // MAXU (unsigned)
            default:  result_word = old_word;                                     // Default: no change
        endcase
    end

    // Signed comparison for MIN/MAX (64-bit)
    wire signed [63:0] old_signed_dw = old_value_i;
    wire signed [63:0] op_signed_dw  = operand_i;
    
    // Comparison results (64-bit)
    wire old_less_signed_dw   = (old_signed_dw < op_signed_dw);
    wire old_less_unsigned_dw = (old_value_i < operand_i);
    
    // 64-bit result
    reg [63:0] result_dword;

    // Atomic operation logic for doubleword (.D) operations
    always @(*) begin
        // Default: pass through old value
        result_dword = old_value_i;
        
        case (amo_op_i)
            AMO_SWAP: result_dword = operand_i;                                         // SWAP
            AMO_ADD:  result_dword = old_value_i + operand_i;                           // ADD
            AMO_XOR:  result_dword = old_value_i ^ operand_i;                           // XOR
            AMO_AND:  result_dword = old_value_i & operand_i;                           // AND
            AMO_OR:   result_dword = old_value_i | operand_i;                           // OR
            AMO_MIN:  result_dword = old_less_signed_dw   ? old_value_i : operand_i;    // MIN (signed)
            AMO_MAX:  result_dword = old_less_signed_dw   ? operand_i   : old_value_i;  // MAX (signed)
            AMO_MINU: result_dword = old_less_unsigned_dw ? old_value_i : operand_i;    // MINU (unsigned)
            AMO_MAXU: result_dword = old_less_unsigned_dw ? operand_i   : old_value_i;  // MAXU (unsigned)
            default:  result_dword = old_value_i;                                       // Default: no change
        endcase
    end

    // Output selection: Word vs Doubleword
    always @(*) begin
        if (amo_word_i) begin
            // Word operation: sign-extend 32-bit result to 64 bits
            new_value_o = { {32{result_word[31]}}, result_word };
        end else begin
            // Doubleword operation: use full 64-bit result
            new_value_o = result_dword;
        end
    end

endmodule
