///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: compressed_decoder                                                               //
// Description: Compressed instruction decoder for 16-bit RV64C instructions.
//              Decodes compressed opcodes and generates equivalent 32-bit
//              control signals. Handles register mapping, immediate assembly,
//              and ALU operation mapping for compressed instruction set.
//              between compressed and non-compressed instrucitons is handled externally         //
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_compressed_decoder #(parameter VADDR = 39) (
    //===================== Instruction Input =====================//
    input [15:0]            inst_i,              // 16-bit compressed instruction

    //===================== Register Data Inputs ==================//
    input   [`XLEN-1:0]     rs1_data_i,          // Source register 1 data
    input   [`XLEN-1:0]     rs2_data_i,          // Source register 2 data

    //===================== Program Counter Input =================//
    input [VADDR-1:0]       pc_i,                // Current program counter

    //===================== Memory Interface Outputs ==============//
    output wire [3:0]       mem_width_1h_ao,     // Memory access width (one-hot)
    output wire             mem_sign_ao,         // Memory access signed/unsigned
    output wire             mem_rd_ao,           // Memory read enable
    output wire             mem_wr_ao,           // Memory write enable

    //===================== Register File Control Outputs =========//
    output reg  [4:0]       rs1_idx_ao,         // Source register 1 index
    output reg  [4:0]       rs2_idx_ao,         // Source register 2 index
    output reg  [4:0]       rd_idx_ao,          // Destination register index
    output reg              rs1_used_ao,        // Source register 1 is used
    output reg              rs2_used_ao,        // Source register 2 is used
    output reg              rd_wr_en_ao,        // Destination register write enable
    output reg  [5:0]       rd_wr_src_1h_ao,    // Writeback source (one-hot, 6-bit for AMO)

    //===================== ALU Control Outputs ===================//
    output reg [`XLEN-1:0]  alu_op_a_ao,        // ALU operand A
    output reg [`XLEN-1:0]  alu_op_b_ao,        // ALU operand B
    output wire             alu_uses_rs1_ao,    // ALU uses rs1 as operand A
    output wire             alu_uses_rs2_ao,    // ALU uses rs2 as operand B
    output reg  [5:0]       alu_operation_ao,   // ALU operation code

    //===================== Control Flow Outputs ==================//
    output reg  [5:0]       branch_cond_1h_ao,  // Branch condition (one-hot)
    output wire             branch_ao,          // Branch/jump instruction
    output wire             ebreak_ao,          // EBREAK instruction
    output reg              illegal_inst_ao     // Illegal instruction detected
);

    //===================== Compressed Instruction Field Extraction =============//
    // Extract compressed instruction fields according to RISC-V C extension spec
    wire [1:0] quadrant    = inst_i[1:0];        // Quadrant field (bits 1:0) - determines instruction format
    wire [2:0] c_func3     = inst_i[15:13];      // Function 3 field (bits 15:13)
    wire [4:0] c_rs1       = inst_i[11:7];       // Source register 1 field (bits 11:7)
    wire [4:0] c_rs2       = inst_i[6:2];        // Source register 2 field (bits 6:2)
    wire [4:0] c_rd        = c_rs1;              // Destination register (same as rs1 for some formats)
    
    //===================== Compressed Register Mapping ========================//
    // Compressed instructions use a subset of registers (x8-x15) for space efficiency
    // These mappings convert compressed register indices to full register indices
    wire [4:0] c_rs1_prime = { 2'b01, c_rs1[2:0] };  // Map to x8-x15 (0b01000-0b01111)
    wire [4:0] c_rs2_prime = { 2'b01, c_rs2[2:0] };  // Map to x8-x15 (0b01000-0b01111)
    wire [4:0] c_rd_prime  = c_rs2_prime;            // For formats other than CA
    wire [4:0] ca_rd_prime = c_rs1_prime;            // For CA format (arithmetic operations)

    //===================== Instruction Type Detection Signals ================//
    // These signals identify which compressed instruction type is being decoded
    reg addi4spn, addi,     slli,      lw, addiw, li,   lwsp, ld, lui_addi16sp, 
        ldsp,     misc_alu, jr_mv_add, j,  sw,    beqz, swsp, sd, bnez,   sdsp;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Instruction Decoder                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Decodes compressed instructions based on quadrant and func3 fields
    // Each compressed instruction maps to a specific 32-bit RISC-V instruction

     always @(*) begin
        //===================== Initialize All Signals =====================//
        // Clear all instruction type signals
        {addi4spn, addi,     slli,      lw, addiw, li,   lwsp, ld, lui_addi16sp, 
         ldsp,     misc_alu, jr_mv_add, j,  sw,    beqz, swsp, sd, bnez,   sdsp} = 'b0;
        illegal_inst_ao = 'b0;

        //===================== Quadrant-Based Instruction Decoding ========//
        // Decode based on {quadrant, c_func3} combination
        case ({quadrant, c_func3})
            //===================== C0 Quadrant (00) =======================//
            // Stack pointer based operations and memory operations
            {`C0, `C_FUNC3_ADDI4SPN}  : addi4spn        = 1'b1;  // C.ADDI4SPN: Add immediate to SP
            {`C0, `C_FUNC3_LW}        : lw              = 1'b1;  // C.LW: Load word from stack
            {`C0, `C_FUNC3_LD}        : ld              = 1'b1;  // C.LD: Load double from stack
            {`C0, `C_FUNC3_SW}        : sw              = 1'b1;  // C.SW: Store word to stack
            {`C0, `C_FUNC3_SD}        : sd              = 1'b1;  // C.SD: Store double to stack

            //===================== C1 Quadrant (01) =======================//
            // Immediate operations, jumps, and branches
            {`C1, `C_FUNC3_ADDI}      : addi            = 1'b1;  // C.ADDI: Add immediate
            {`C1, `C_FUNC3_ADDIW}     : addiw           = 1'b1;  // C.ADDIW: Add immediate word
            {`C1, `C_FUNC3_LI}        : li              = 1'b1;  // C.LI: Load immediate
            {`C1, `C_FUNC3_ADDI16SPN} : lui_addi16sp    = 1'b1;  // C.ADDI16SPN: Add immediate to SP
            {`C1, `C_FUNC3_MISC_ALU}  : misc_alu        = 1'b1;  // C.MISC_ALU: Miscellaneous ALU ops
            {`C1, `C_FUNC3_J}         : j               = 1'b1;  // C.J: Jump
            {`C1, `C_FUNC3_BEQZ}      : beqz            = 1'b1;  // C.BEQZ: Branch if equal to zero
            {`C1, `C_FUNC3_BNEZ}      : bnez            = 1'b1;  // C.BNEZ: Branch if not equal to zero
            
            //===================== C2 Quadrant (10) =======================//
            // Stack pointer operations and register operations
            {`C2, `C_FUNC3_SLLI}      : slli            = 1'b1;  // C.SLLI: Shift left logical immediate
            {`C2, `C_FUNC3_LWSP}      : lwsp            = 1'b1;  // C.LWSP: Load word from SP
            {`C2, `C_FUNC3_LDSP}      : ldsp            = 1'b1;  // C.LDSP: Load double from SP
            {`C2, `C_FUNC3_JR_MV_ADD} : jr_mv_add       = 1'b1;  // C.JR/MV/ADD: Jump register/Move/Add
            {`C2, `C_FUNC3_SWSP}      : swsp            = 1'b1;  // C.SWSP: Store word to SP
            {`C2, `C_FUNC3_SDSP}      : sdsp            = 1'b1;  // C.SDSP: Store double to SP

            //===================== Illegal Instruction ====================//
            default                   : illegal_inst_ao = 1'b1;  // Unsupported instruction
         endcase
     end

    //===================== Secondary Instruction Decoding ==================//
    // These signals decode specific instruction variants within the main categories
    // They use additional instruction bits to distinguish between similar operations

    //===================== C1 Quadrant Secondary Decoding ==================//
    // Distinguish between C.ADDI16SPN and C.LUI based on destination register
    wire addi16sp = lui_addi16sp && (c_rs1 == 5'd2);  // C.ADDI16SPN: if rd == x2 (SP)
    wire lui      = lui_addi16sp && (c_rs1 != 5'd2);  // C.LUI: if rd != x2

    //===================== C2 Quadrant Secondary Decoding ==================//
    // Decode C.JR/MV/ADD instructions based on bit patterns
    wire mv       = jr_mv_add && ~inst_i[12] && (c_rs2 != 'b0);  // C.MV: bit[12]=0, rs2!=0
    wire add      = jr_mv_add &&  inst_i[12] && (c_rs2 != 'b0);  // C.ADD: bit[12]=1, rs2!=0
    wire jr       = jr_mv_add && ~inst_i[12] && (c_rs2 == 'b0);  // C.JR: bit[12]=0, rs2=0
    wire jalr     = jr_mv_add &&  inst_i[12] && (c_rs2 == 'b0) && (c_rs1 != 'b0);  // C.JALR: bit[12]=1, rs2=0, rs1!=0

    //===================== C1 MISC_ALU Secondary Decoding ==================//
    // Decode miscellaneous ALU operations based on instruction bit patterns
    wire srli     = misc_alu && (inst_i[11:10] == 2'b00);  // C.SRLI: bits[11:10]=00
    wire srai     = misc_alu && (inst_i[11:10] == 2'b01);  // C.SRAI: bits[11:10]=01
    wire andi     = misc_alu && (inst_i[11:10] == 2'b10);  // C.ANDI: bits[11:10]=10

    //===================== C1 MISC_ALU Logical Operations ==================//
    // Decode logical ALU operations (C.SUB, C.XOR, C.OR, C.AND)
    wire alu_logi = misc_alu && (inst_i[12:10] == 3'b011);  // Logical operations group
    wire sub      = alu_logi && (inst_i[6:5]   == 2'b00);   // C.SUB: bits[6:5]=00
    wire alu_xor  = alu_logi && (inst_i[6:5]   == 2'b01);   // C.XOR: bits[6:5]=01
    wire alu_or   = alu_logi && (inst_i[6:5]   == 2'b10);   // C.OR: bits[6:5]=10
    wire alu_and  = alu_logi && (inst_i[6:5]   == 2'b11);   // C.AND: bits[6:5]=11

    //===================== C1 MISC_ALU Word Operations =====================//
    // Decode word operations (C.SUBW, C.ADDW)
    wire subw     = misc_alu && (inst_i[12:10] == 3'b111) && (inst_i[6:5] == 2'b00);  // C.SUBW
    wire addw     = misc_alu && (inst_i[12:10] == 3'b111) && (inst_i[6:5] == 2'b01);  // C.ADDW


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      Load/Store Signals                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate memory interface control signals for compressed load/store instructions

    //===================== Memory Access Width =============================//
    // Determine memory access width based on instruction type
    // Word operations: C.LW, C.SW, C.LWSP, C.SWSP
    // Double operations: C.LD, C.SD, C.LDSP, C.SDSP
    assign mem_width_1h_ao = (lw | sw | lwsp | swsp) ? `MEM_WIDTH_1H_WORD : `MEM_WIDTH_1H_DOUBLE;
    
    //===================== Memory Sign Extension ===========================//
    // All compressed loads are signed (no unsigned compressed loads in RV64C)
    assign mem_sign_ao     = `MEM_SIGNED;
    
    //===================== Memory Read/Write Control =======================//
    // Generate read enable for load instructions
    assign mem_rd_ao       = (lw | ld | lwsp | ldsp);
    
    // Generate write enable for store instructions  
    assign mem_wr_ao       = (sw | sd | swsp | sdsp);


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              Integer Register File Controls                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate register file control signals based on compressed instruction quadrant
    // Handles register mapping, usage detection, and write enable generation

    always @(*) begin : register_index_decoder
        case (quadrant)
            //===================== C0 Quadrant (Stack Operations) ===============//
            `C0: begin 
                // Source register 1: SP for C.ADDI4SPN, mapped register for others
                rs1_idx_ao  = (addi4spn) ? 5'd2 : c_rs1_prime;  // SP or x8-x15
                rs1_used_ao = 1'b1;                              // Always use rs1 in C0
                
                // Source register 2: Mapped register for stores
                rs2_idx_ao  = c_rs2_prime;                       // x8-x15
                rs2_used_ao = sw | sd;                           // Only for store operations
                
                // Destination register: Mapped register
                rd_idx_ao   = c_rd_prime;                        // x8-x15
                rd_wr_en_ao = (~inst_i[15]) && (rd_idx_ao != 'b0);  // Enable if not illegal and rd!=0
            end

            //===================== C1 Quadrant (Immediate/Branch) ==============//
            `C1: begin
                // Source register 1: Mapped for misc_alu/branches, direct for others
                rs1_idx_ao  = (misc_alu | beqz | bnez) ? c_rs1_prime : c_rs1;
                rs1_used_ao = (misc_alu | beqz | bnez | addi | addiw | addi16sp); 
                
                // Source register 2: Not used for branches
                rs2_idx_ao  = (beqz | bnez) ? 'b0 : c_rs2_prime;
                rs2_used_ao = misc_alu && (inst_i[11:10] == 'b11);  // Only for logical ops
                
                // Destination register: Special handling for misc_alu
                rd_idx_ao   = misc_alu ? ca_rd_prime : c_rd;
                rd_wr_en_ao = (misc_alu | ~inst_i[15]) && (rd_idx_ao != 'b0);
            end

            //===================== C2 Quadrant (SP/Register Ops) ===============//
            `C2: begin
                // Source register 1: SP for stack operations, direct for others
                rs1_idx_ao  = (lwsp | ldsp | swsp | sdsp) ? 5'd2 : c_rs1;
                rs1_used_ao = slli | jr | jalr | lwsp | ldsp | swsp | sdsp | add;
                
                // Source register 2: Direct register index
                rs2_idx_ao  = c_rs2;
                rs2_used_ao = swsp | sdsp | add | mv;  // Used for stores and register ops
                
                // Destination register: x1 for C.JALR, direct for others
                rd_idx_ao   = jalr ? 'b1 : c_rd;  // x1 for JALR, otherwise direct
                rd_wr_en_ao = (~inst_i[15] | jalr | add | mv) && (rd_idx_ao != 'b0);
            end

            //===================== Default (Illegal) ===========================//
            default: begin
                // Clear all register signals for illegal instructions
                rs1_idx_ao  = 'b0;
                rs1_used_ao = 'b0;
                rs2_idx_ao  = 'b0;
                rs2_used_ao = 'b0;
                rd_idx_ao   = 'b0;
                rd_wr_en_ao = 'b0;
            end 
        endcase
    end

    //===================== Writeback Source Selection =====================//
    // Determine the source of data to be written back to the destination register
    always @(*) begin : rd_wr_src_decoder
        if      (jalr)                   rd_wr_src_1h_ao = `WB_SRC_1H_PC_PLUS_4;  // C.JALR: return address
        else if (lw | ld | lwsp | ldsp)  rd_wr_src_1h_ao = `WB_SRC_1H_MEM;         // Load instructions: memory data
        else                             rd_wr_src_1h_ao = `WB_SRC_1H_I_ALU;        // All others: ALU result 
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ALU Operation                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate ALU operands and operation codes for compressed instructions

    //===================== Compressed Immediate Generation =================//
    // Generate various immediate values from compressed instruction fields
    // Each immediate type has a specific bit layout according to RISC-V C extension spec

    // Load/Store Stack Immediates (C0 quadrant)
    wire [`XLEN-1:0] lsw_uimm  = { 57'b0,         inst_i[5],   inst_i[12:10], inst_i[6], 2'b0 };  // C.LW/C.SW: 5-bit unsigned
    wire [`XLEN-1:0] lsd_uimm  = { 56'b0,         inst_i[6:5], inst_i[12:10], 3'b0 };              // C.LD/C.SD: 6-bit unsigned

    // Arithmetic Immediates (C1 quadrant)
    wire [`XLEN-1:0] a_imm  = { {58{inst_i[12]}}, inst_i[12],  inst_i[6:2]};                       // C.ADDI/ANDI: 6-bit signed
    wire [`XLEN-1:0] ui_imm = { {46{inst_i[12]}}, inst_i[12],  inst_i[6:2],   12'b0 };             // C.LUI: 6-bit signed, shifted left 12
    wire [`XLEN-1:0] s_imm     = { 58'b0,         inst_i[12],  inst_i[6:2]};                       // C.SLLI/SRLI/SRAI: 6-bit unsigned

    // Stack Pointer Immediates (C2 quadrant)
    wire [`XLEN-1:0] uimm_lwsp = { 56'b0,         inst_i[3:2], inst_i[12],    inst_i[6:4],  2'b0 };  // C.LWSP: 6-bit unsigned
    wire [`XLEN-1:0] uimm_ldsp = { 55'b0,         inst_i[4:2], inst_i[12],    inst_i[6:5],  3'b0 };  // C.LDSP: 7-bit unsigned
    wire [`XLEN-1:0] uimm_swsp = { 56'b0,         inst_i[8:7], inst_i[12:9],  2'b0 };                // C.SWSP: 6-bit unsigned
    wire [`XLEN-1:0] uimm_sdsp = { 55'b0,         inst_i[9:7], inst_i[12:10], 3'b0 };                // C.SDSP: 7-bit unsigned

    // Program Counter
    wire [`XLEN-1:0] pc  = { {`XLEN-VADDR{1'b0}}, pc_i};  // Extended PC for branch targets

    // Special Immediates
    wire [`XLEN-1:0] a4_imm  = { 54'b0,               inst_i[10:7],  inst_i[12:11], inst_i[5],      // C.ADDI4SPN: 10-bit unsigned
                                  inst_i[6], 2'b0 };

    wire [`XLEN-1:0] a16_imm = { {54{inst_i[12]}},    inst_i[12],    inst_i[4:3],   inst_i[5],      // C.ADDI16SPN: 6-bit signed, shifted left 4
                                  inst_i[2],          inst_i[6], 4'b0 };

    // Jump and Branch Immediates
    wire [`XLEN-1:0] j_imm     = { {52{inst_i[12]}},  inst_i[12],    inst_i[8],     inst_i[10:9],   // C.J: 11-bit signed, shifted left 1
                                  inst_i[6],          inst_i[7],     inst_i[2],     inst_i[11], 
                                  inst_i[5:3],        1'b0 };

    wire [`XLEN-1:0] b_imm     = { {55{inst_i[12]}},  inst_i[12],    inst_i[6:5],   inst_i[2],      // C.BEQZ/C.BNEZ: 9-bit signed, shifted left 1
                                  inst_i[11:10],      inst_i[4:3],   1'b0 };



    //===================== ALU Operand A Selection ========================//
    // Select the first ALU operand based on instruction type
    always @(*) begin
        if  (alu_uses_rs1_ao)        alu_op_a_ao = rs1_data_i;  // Use rs1 data when rs1 is used
        else if         (lui)        alu_op_a_ao = ui_imm;      // C.LUI: upper immediate
        else if           (j)        alu_op_a_ao = j_imm;       // C.J: jump immediate
        else if (beqz | bnez)        alu_op_a_ao = b_imm;       // C.BEQZ/C.BNEZ: branch immediate
        else if     (mv | li)        alu_op_a_ao = 'b0;         // C.MV/C.LI: zero (no rs1)
        else                         alu_op_a_ao = rs1_data_i;  // Default: rs1 data
    end

    //===================== ALU Operand B Selection ========================//
    // Select the second ALU operand based on instruction type
    always @(*) begin
        if (alu_uses_rs2_ao)         alu_op_b_ao = rs2_data_i;  // Use rs2 data when rs2 is used
        else if    (addi4spn)        alu_op_b_ao = a4_imm;      // C.ADDI4SPN: 4-byte immediate
        else if (j | beqz | bnez)    alu_op_b_ao = pc;          // C.J/C.BEQZ/C.BNEZ: PC
        else if (lw | sw)            alu_op_b_ao = lsw_uimm;    // C.LW/C.SW: stack immediate
        else if (ld | sd)            alu_op_b_ao = lsd_uimm;    // C.LD/C.SD: stack immediate
        else if (srli | srai | slli) alu_op_b_ao = s_imm;       // C.SRLI/C.SRAI/C.SLLI: shift immediate
        else if (addi16sp)           alu_op_b_ao = a16_imm;     // C.ADDI16SPN: 16-byte immediate
        else if (andi | addi | 
                 li | addiw)         alu_op_b_ao = a_imm;       // C.ANDI/C.ADDI/C.LI/C.ADDIW: arithmetic immediate
        else if (lwsp)               alu_op_b_ao = uimm_lwsp;   // C.LWSP: SP immediate
        else if (ldsp)               alu_op_b_ao = uimm_ldsp;   // C.LDSP: SP immediate
        else if (swsp)               alu_op_b_ao = uimm_swsp;   // C.SWSP: SP immediate
        else if (sdsp)               alu_op_b_ao = uimm_sdsp;   // C.SDSP: SP immediate
        else                         alu_op_b_ao = rs2_data_i;  // Default: rs2 data
    end

    //===================== ALU Operation Code Generation ==================//
    // Generate 6-bit ALU operation code based on instruction type
    always @(*) begin
        if      (srli)               alu_operation_ao = `ALU_OP_SRL;    // C.SRLI: Shift right logical
        else if (srai)               alu_operation_ao = `ALU_OP_SRA;    // C.SRAI: Shift right arithmetic
        else if (slli)               alu_operation_ao = `ALU_OP_SLL;    // C.SLLI: Shift left logical
        else if (andi | alu_and)     alu_operation_ao = `ALU_OP_AND;    // C.ANDI/C.AND: And operation
        else if (alu_xor)            alu_operation_ao = `ALU_OP_XOR;    // C.XOR: Exclusive or
        else if (alu_or)             alu_operation_ao = `ALU_OP_OR;     // C.OR: Or operation
        else if (sub)                alu_operation_ao = `ALU_OP_SUB;    // C.SUB: Subtract
        else if (subw)               alu_operation_ao = `ALU_OP_SUBW;   // C.SUBW: Subtract word
        else if (addw | addiw)       alu_operation_ao = `ALU_OP_ADDW;   // C.ADDW/C.ADDIW: Add word
        else if (lui)                alu_operation_ao = `ALU_OP_PASS;   // C.LUI: Pass through
        else                         alu_operation_ao = `ALU_OP_ADD;    // Default: Add operation
    end

    //===================== ALU Register Usage Detection ===================//
    // Determine which source registers are actually used by the ALU
    assign alu_uses_rs1_ao = rs1_used_ao && !(beqz | bnez);  // rs1 used except for branches
    assign alu_uses_rs2_ao = rs2_used_ao && !(sw | sd | swsp | sdsp);  // rs2 used except for stores


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   Flow Control and Exceptions                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate control flow and exception signals for compressed instructions

    //===================== Branch Condition Decoder =======================//
    // Generate one-hot branch condition codes for conditional branches
    always @(*) begin : conditional_branch_decoder
        if      (beqz) branch_cond_1h_ao = `BR_OP_1H_BEQ;  // C.BEQZ: Branch if equal to zero
        else if (bnez) branch_cond_1h_ao = `BR_OP_1H_BNE;  // C.BNEZ: Branch if not equal to zero
        else           branch_cond_1h_ao = 'b0;             // No branch condition
    end
    
    //===================== Branch and Jump Detection ======================//
    // Detect branch and jump instructions
    assign branch_ao = j | jr | jalr;  // C.J, C.JR, C.JALR are branch/jump instructions
    
    //===================== Exception Detection ============================//
    // Detect EBREAK instruction (C.EBREAK)
    // C.EBREAK is encoded as C.JALR with rs1=0, rs2=0, and bit[12]=1
    assign ebreak_ao = jr_mv_add && inst_i[12] && (c_rs2 == 'b0) && (c_rs1 == 'b0);
    

endmodule
