///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_decoder                                                                    //
// Description: Main instruction decoder for 32-bit RV64IMAC instructions.
//              Decodes opcodes, function codes, and generates control signals
//              for all instruction types. Handles immediate generation, register
//              usage, and instruction legality checking. This is the core decoder
//              for standard 32-bit RISC-V instructions used in the CPU64 pipeline.
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_decoder #(parameter VADDR = 39) (
    //===================== Instruction Input =====================//
    input [31:0]            inst_i,             // 32-bit instruction to decode

    //===================== Register Data Inputs ==================//
    input [`XLEN-1:0]       rs1_data_i,         // Source register 1 data
    input [`XLEN-1:0]       rs2_data_i,         // Source register 2 data
    input [VADDR-1:0]       pc_i,               // Program counter

    //===================== CSR Control Inputs ====================//
    input                   csr_rd_en_i,        // CSR read enable
    input                   sys_csr_i,          // System CSR instruction

    //===================== CSR Outputs ===========================//
    output wire [`XLEN-1:0] csr_imm_ao,         // CSR immediate value

    //===================== Memory Control Outputs ================//
    output reg  [3:0]       mem_width_1h_ao,    // Memory access width (one-hot)
    output wire             mem_sign_ao,        // Memory sign extension
    output wire             mem_rd_ao,          // Memory read enable
    output wire             mem_wr_ao,          // Memory write enable

    //===================== Register File Control Outputs =========//
    output wire [4:0]       rs1_idx_ao,         // Source register 1 index
    output wire [4:0]       rs2_idx_ao,         // Source register 2 index
    output wire [4:0]       rd_idx_ao,          // Destination register index
    output wire             rs1_used_ao,        // Source register 1 is used
    output wire             rs2_used_ao,        // Source register 2 is used
    output wire             rd_wr_en_ao,        // Destination register write enable
    output reg  [5:0]       rd_wr_src_1h_ao,    // Writeback source (one-hot, 6-bit for AMO)

    //===================== ALU Control Outputs ===================//
    output wire [`XLEN-1:0] alu_op_a_ao,        // ALU operand A
    output wire [`XLEN-1:0] alu_op_b_ao,        // ALU operand B
    output wire             alu_uses_rs1_ao,    // ALU uses rs1 as operand A
    output wire             alu_uses_rs2_ao,    // ALU uses rs2 as operand B
    output wire [5:0]       alu_operation_ao,   // ALU operation code

    //===================== Flow Control Outputs ==================//
    output reg  [5:0]       branch_cond_1h_ao,  // Branch condition (one-hot)
    output wire             branch_ao,          // Branch/jump instruction
    output wire             ebreak_ao,          // EBREAK instruction
    output wire             fencei_ao,          // FENCE.I instruction
    output wire             ecall_ex_ao,        // ECALL exception
    output wire             mret_ao,            // MRET instruction
    output wire             wait_for_int_ao,    // WFI instruction

    //===================== Exception Outputs =====================//
    output wire             illegal_inst_ao     // Illegal instruction detected
);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Instruction Field Extraction                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Extract key instruction fields for decoding
    // These fields are used throughout the decoder to determine instruction type and behavior

    wire [6:0]  opcode = inst_i[6:0];     // 7-bit opcode field (bits 6:0)
    wire [2:0]  func3  = inst_i[14:12];   // 3-bit function field (bits 14:12)
    wire [11:0] func12 = inst_i[31:20];   // 12-bit function field (bits 31:20)


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      Load/Store Signals                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Decode memory access instructions (LOAD and STORE)
    // Generates memory control signals and validates instruction legality

    wire legal_load_store;    // Load/store instruction is legal

    //===================== Memory Width Decoder ==================//
    // Decode memory access width based on func3[1:0] field
    // Supports byte, halfword, word, and doubleword accesses
    always @(*) begin : mem_width_decoder
        case (func3[1:0])
            `MEM_WIDTH_BYTE     : mem_width_1h_ao = `MEM_WIDTH_1H_BYTE;     // 8-bit access
            `MEM_WIDTH_HALF     : mem_width_1h_ao = `MEM_WIDTH_1H_HALF;     // 16-bit access
            `MEM_WIDTH_WORD     : mem_width_1h_ao = `MEM_WIDTH_1H_WORD;     // 32-bit access
            `MEM_WIDTH_DOUBLE   : mem_width_1h_ao = `MEM_WIDTH_1H_DOUBLE;   // 64-bit access
            default             : mem_width_1h_ao = 'b0;                     // Invalid width
        endcase
    end

    //===================== Memory Control Signals ================//
    // Generate memory read/write and sign extension control signals
    assign mem_wr_ao   = (opcode == `OPCODE_STORE);    // Store instruction
    assign mem_rd_ao   = (opcode == `OPCODE_LOAD) || (opcode == `OPCODE_AMO);     // Load instruction or AMO (AMO needs to read old value)
    assign mem_sign_ao = func3[2];                     // Sign extension (0=unsigned, 1=signed)
    
    //===================== Load/Store Legality Check =============//
    // Validate that load/store instructions use supported memory widths
    assign legal_load_store = (mem_wr_ao || mem_rd_ao) && 
                              ( (func3[1:0] == `MEM_WIDTH_BYTE  ) ||  // 8-bit access
                                (func3[1:0] == `MEM_WIDTH_HALF  ) ||  // 16-bit access
                                (func3[1:0] == `MEM_WIDTH_WORD  ) ||  // 32-bit access
                                (func3[1:0] == `MEM_WIDTH_DOUBLE) );  // 64-bit access


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              Integer Register File Controls                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Decode register file usage and writeback source selection
    // Determines which registers are used and where results should be written back

    wire m_extension_inst;          // Instruction belongs to RV64M extension
    wire M_alu_sel = m_extension_inst; // Select M-ALU only for true RV64M ops

    //===================== Register Usage Detection ==============//
    // Determine which source registers are used by the instruction
    assign rs1_used_ao = (opcode != `OPCODE_LUI)   &&    // LUI doesn't use rs1
                         (opcode != `OPCODE_AUIPC) &&    // AUIPC doesn't use rs1
                         (opcode != `OPCODE_JAL);        // JAL doesn't use rs1

    assign rs2_used_ao = (opcode == `OPCODE_BRANCH) ||    // Branch instructions use rs2
                         (opcode == `OPCODE_STORE)  ||    // Store instructions use rs2
                         (opcode == `OPCODE_OP_W)   ||    // OP-W instructions use rs2
                         (opcode == `OPCODE_OP)     ||    // OP instructions use rs2
                         (opcode == `OPCODE_AMO);         // AMO instructions use rs2

    //===================== Register Write Enable =================//
    // Enable register write for instructions that produce results
    assign rd_wr_en_ao = (csr_rd_en_i) ||                 // CSR read instructions
                         ( (opcode    != `OPCODE_BRANCH) &&    // Not branch instructions
                           (opcode    != `OPCODE_STORE)  &&    // Not store instructions
                           (rd_idx_ao != 'b0) );              // Not writing to x0

    //===================== Writeback Source Decoder ==============//
    // Select the source for register writeback based on instruction type
    always @(*) begin : rd_wr_src_decoder
        case (opcode)
            `OPCODE_JAL    : rd_wr_src_1h_ao = `WB_SRC_1H_PC_PLUS_4;  // Jump: PC+4
            `OPCODE_JALR   : rd_wr_src_1h_ao = `WB_SRC_1H_PC_PLUS_4;  // Jump: PC+4
            `OPCODE_LOAD   : rd_wr_src_1h_ao = `WB_SRC_1H_MEM;        // Load: memory data
            `OPCODE_OP     : rd_wr_src_1h_ao = M_alu_sel ? `WB_SRC_1H_M_ALU : `WB_SRC_1H_I_ALU;  // OP: I-ALU or M-ALU
            `OPCODE_OP_W   : rd_wr_src_1h_ao = M_alu_sel ? `WB_SRC_1H_M_ALU : `WB_SRC_1H_I_ALU;  // OP-W: I-ALU or M-ALU
            `OPCODE_SYSTEM : rd_wr_src_1h_ao = sys_csr_i ? `WB_SRC_CSR      : `WB_SRC_1H_I_ALU;  // System: CSR or I-ALU
            `OPCODE_AMO    : rd_wr_src_1h_ao = `WB_SRC_1H_AMO;        // AMO: old value from memory
            default        : rd_wr_src_1h_ao = `WB_SRC_1H_I_ALU;       // Default: I-ALU
        endcase
    end

`ifdef VERILATOR
    always @(*) begin
        if (opcode == `OPCODE_AMO && rd_idx_ao != 0) begin
            $display("[DECODER] AMO instruction: opcode=0x%02h rd=x%0d rd_wr_src_1h_ao=0x%02h (should be 0x20)",
                     opcode, rd_idx_ao, rd_wr_src_1h_ao);
        end
    end
`endif

    //===================== Register Index Extraction =============//
    // Extract register indices from instruction fields
    assign rs1_idx_ao = inst_i[19:15];    // Source register 1 index (bits 19:15)
    assign rs2_idx_ao = inst_i[24:20];    // Source register 2 index (bits 24:20)
    assign rd_idx_ao  = inst_i[11:7];     // Destination register index (bits 11:7)



    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ALU Operation                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Delegate ALU operation decoding to specialized ALU decoder module
    // Handles immediate generation, operand selection, and operation legality

    wire legal_alu_op;    // ALU operation is legal

    //===================== ALU Decoder Instantiation =============//
    // Instantiate the ALU decoder for standard 32-bit instructions
    // This module handles immediate generation, operand selection, and ALU operation decoding
    cpu64_alu_decoder #(.VADDR(VADDR)) uncompressed_alu_decoder (
        //===================== Inputs =============================//
        .inst_i             (inst_i),           // 32-bit instruction
        .rs1_data_i         (rs1_data_i),       // Source register 1 data
        .rs2_data_i         (rs2_data_i),       // Source register 2 data
        .pc_i               (pc_i),             // Program counter

        //===================== Outputs ============================//
        .csr_imm_ao         (csr_imm_ao),       // CSR immediate value
        .alu_op_a_ao        (alu_op_a_ao),      // ALU operand A
        .alu_op_b_ao        (alu_op_b_ao),      // ALU operand B
        .alu_uses_rs1_ao    (alu_uses_rs1_ao),  // ALU uses rs1 as operand A
        .alu_uses_rs2_ao    (alu_uses_rs2_ao),  // ALU uses rs2 as operand B
        .alu_operation_ao   (alu_operation_ao), // ALU operation code
        .legal_alu_op_ao    (legal_alu_op),     // ALU operation is legal
        .is_m_extension_ao  (m_extension_inst)  // RV64M instruction flag
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   Flow Control and Exceptions                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Decode flow control instructions (branches, jumps) and system instructions
    // Handles branch conditions, system calls, and exception generation

    wire legal_flow_control;    // Flow control instruction is legal

    //===================== Branch Condition Decoder ==============//
    // Decode branch conditions for BRANCH instructions
    // Generates one-hot encoded branch condition signals
    always @(*) begin
        branch_cond_1h_ao = 'b0;    // Default: no branch condition
        if (opcode == `OPCODE_BRANCH) begin
            case (func3)
                `BR_OP_BEQ    : branch_cond_1h_ao = `BR_OP_1H_BEQ;     // Branch if equal
                `BR_OP_BNE    : branch_cond_1h_ao = `BR_OP_1H_BNE;     // Branch if not equal
                `BR_OP_BLT    : branch_cond_1h_ao = `BR_OP_1H_BLT;     // Branch if less than (signed)
                `BR_OP_BGE    : branch_cond_1h_ao = `BR_OP_1H_BGE;     // Branch if greater/equal (signed)
                `BR_OP_BLTU   : branch_cond_1h_ao = `BR_OP_1H_BLTU;    // Branch if less than (unsigned)
                `BR_OP_BGEU   : branch_cond_1h_ao = `BR_OP_1H_BGEU;    // Branch if greater/equal (unsigned)
                default       : branch_cond_1h_ao = 'b0;               // Invalid branch condition
            endcase
        end
    end
    
    //===================== Branch/Jump Detection =================//
    // Detect branch and jump instructions
    assign branch_ao = (opcode == `OPCODE_JAL) || (opcode == `OPCODE_JALR) || (opcode == `OPCODE_BRANCH);  // Jump, jump-register, or branch

    //===================== Flow Control Legality Check ===========//
    // Validate that flow control instructions are legal
    assign legal_flow_control = ( ( (opcode == `OPCODE_JALR)   && func3 == 3'b0         ) ||  // JALR with func3=0
                                  ( (opcode == `OPCODE_BRANCH) && branch_cond_1h_ao != 0) ||  // Valid branch condition
                                  ( (opcode == `OPCODE_JAL)                             ) );   // JAL instruction

    //===================== System Instruction Detection ==========//
    // Detect system and privileged instructions
    // sys_priv is only true for uncompressed instructions (Quadrant 2'b11)
    wire   sys_priv        = (opcode == `OPCODE_SYSTEM)   && (func3 == `SYSTEM_OP_PRIV);  // System privileged instruction

    //===================== System Instruction Decoder ============//
    // Decode specific system instructions based on func12 field
    assign fencei_ao       = (opcode == `OPCODE_MISC_MEM) && (func3 == `MISC_MEM_FENCE_I);  // FENCE.I instruction
    assign ecall_ex_ao     = sys_priv && func12 == `FUNC12_ECALL;         // ECALL exception
    assign mret_ao         = sys_priv && func12 == `FUNC12_MRET;          // MRET instruction
    assign wait_for_int_ao = sys_priv && func12 == `FUNC12_WFI;           // WFI instruction
    assign ebreak_ao       = sys_priv && func12 == `FUNC12_EBREAK;        // EBREAK instruction

    //===================== Instruction Legality Check ============//
    // Determine if the instruction is legal based on all decoder modules
    assign illegal_inst_ao = ~(legal_load_store || legal_flow_control || legal_alu_op);

endmodule
