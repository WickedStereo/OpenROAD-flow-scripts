///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: decode_stage                                                                     //
// Description: Decode stage decodes 32/16-bit instructions, generates control signals,
//              reads register file, and interfaces with CSR module. Handles both
//              standard and compressed instruction formats with proper operand
//              generation and hazard detection.
//                            RV64IMAC_Zicsr_Zifencei hart.                                      //
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_decode_stage #(parameter VADDR = 39) (
    //===================== Clock and Reset =====================//
    input                  clk_i,              // System clock
    input                  rst_ni,             // Active-low reset
    
    //===================== Pipeline Control Inputs ============//
    input                  squash_i,           // Squash decode stage (branch misprediction)
    input                  bubble_i,           // Insert bubble (load-use hazard)
    input                  stall_i,            // Stall decode stage (memory not ready)

    //===================== Fetch Stage Inputs =================//
    input [VADDR-1:0]      pc_i,               // Current program counter
    input [VADDR-1:0]      next_pc_i,          // Next program counter
    input                  valid_i,            // Fetch stage valid signal
    input       [31:0]     inst_i,             // 32-bit instruction from memory

    //===================== Fetch Stage Feedback ===============//
    output wire            compressed_instr_ao, // Feedback: instruction was compressed

    //===================== Register File Interface ============//
    output wire [4:0]      rs1_idx_ao,         // Source register 1 index (async read)
    output wire [4:0]      rs2_idx_ao,         // Source register 2 index (async read)
    input [`XLEN-1:0]      rs1_data_i,         // Source register 1 data
    input [`XLEN-1:0]      rs2_data_i,         // Source register 2 data

    //===================== CSR Read Interface =================//
    output wire [11:0]     csr_addr_ao,        // CSR address to read
    output wire            csr_rd_en_ao,       // CSR read enable
    input                  csr_rd_ex_i,        // CSR read exception
    // CSR Load Use Hazard Inputs
    input       [11:0]     EXE_csr_addr_i,     // EXE stage CSR address
    input                  EXE_csr_wr_en_i,    // EXE stage CSR write enable
    output wire            csr_load_use_haz_ao, // CSR load-use hazard detected

    //===================== Pipeline Outputs ===================//
    output reg             valid_o,            // Decode stage valid output
    // Register Source 1 (rs1)
    output reg  [4:0]      rs1_idx_o,          // Source register 1 index
    output reg             rs1_used_o,         // Source register 1 is used
    output reg [`XLEN-1:0] rs1_data_o,         // Source register 1 data
    // Register Source 2 (rs2)
    output reg  [4:0]      rs2_idx_o,          // Source register 2 index
    output reg             rs2_used_o,         // Source register 2 is used
    output reg [`XLEN-1:0] rs2_data_o,         // Source register 2 data
    // Destination Register (rd)
    output reg  [4:0]      rd_idx_o,           // Destination register index
    output reg             rd_wr_en_o,         // Destination register write enable
    output reg  [5:0]      rd_wr_src_1h_o,     // Writeback source (one-hot, 6-bit for AMO)
    // ALU Operation and Operands
    output reg  [5:0]      alu_operation_o,    // ALU operation code
    output reg [`XLEN-1:0] alu_op_a_o,         // ALU operand A
    output reg [`XLEN-1:0] alu_op_b_o,         // ALU operand B
    output reg             alu_uses_rs1_o,     // ALU uses rs1 as operand A
    output reg             alu_uses_rs2_o,     // ALU uses rs2 as operand B
    // Load/Store
    output reg  [3:0]      mem_width_1h_o,     // Memory access width (one-hot)
    output reg             mem_rd_o,           // Memory read enable
    output reg             mem_wr_o,           // Memory write enable
    output reg             mem_sign_o,         // Memory access signed/unsigned
    // Flow Control
    output reg             branch_o,           // Branch/jump instruction
    output reg [VADDR-1:0] pc_o,               // Program counter
    output reg [VADDR-1:0] next_pc_o,          // Next program counter
    output reg  [5:0]      br_cond_1h_o,       // Branch condition (one-hot)
    // CSR Control
    output reg             csr_wr_en_o,        // CSR write enable
    output reg [2:0]       csr_op_1h_o,        // CSR operation (one-hot)
    output reg [11:0]      csr_addr_o,         // CSR address
    // Traps and Exceptions
    output reg             ecall_ex_o,         // ECALL exception
    output reg             ebreak_ex_o,        // EBREAK exception
    output reg             illegal_inst_ex_o,  // Illegal instruction exception
    output reg             mret_o,             // MRET instruction
    output reg             wait_for_int_o,     // WFI instruction
    output reg             fencei_o,           // FENCE.I instruction
    // Atomic Operation Signals
    output reg             is_amo_o,           // Is AMO instruction
    output reg             is_lr_o,            // Is Load-Reserved instruction
    output reg             is_sc_o,            // Is Store-Conditional instruction
    output reg  [4:0]      amo_op_o,           // AMO operation type (funct5)
    output reg             amo_word_o          // AMO word operation flag

`ifdef CPU64_RVFI
    ,
    output reg [  32 - 1 : 0]    rvfi_insn_o,
    output reg                   rvfi_trap_o,
    output reg [`XLEN - 1 : 0]   rvfi_pc_rdata_o,
    output reg [`XLEN - 1 : 0]   rvfi_pc_wdata_o
`endif

    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      Validity Tracker                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Manages the validity of the decode stage considering pipeline control signals
    // Handles stall, bubble, and squash conditions for proper pipeline state management

    wire valid;

    cpu64_validity_tracker DCD_validity_tracker (
        .clk_i          (clk_i),              // System clock
        .rst_ni         (rst_ni),             // Active-low reset

        .valid_i        (valid_i),            // Input validity from fetch stage
        
        .squash_i       (squash_i),           // Squash signal (branch misprediction)
        .bubble_i       (bubble_i),           // Bubble signal (load-use hazard)
        .stall_i        (stall_i),            // Stall signal (memory not ready)

        .valid_ao       (valid)               // Output validity considering all control signals
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                Standard Instruction Decoder                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Decodes 32-bit RISC-V instructions and generates control signals
    // Handles all standard instruction types including ALU, memory, and system operations

    //===================== Decoder Output Signal Declarations =============//
    // Load/Store Controls
    wire [3:0]       mem_width_1h_uncompr;    // Memory access width (one-hot)
    wire             mem_sign_uncompr;        // Memory sign extension control
    wire             mem_rd_uncompr;          // Memory read enable
    wire             mem_wr_uncompr;          // Memory write enable
    
    // Register File Controls
    wire [4:0]       rs1_idx_uncompr;         // Source register 1 index
    wire [4:0]       rs2_idx_uncompr;         // Source register 2 index
    wire [4:0]       rd_idx_uncompr;          // Destination register index
    wire             rs1_used_uncompr;        // Source register 1 is used
    wire             rs2_used_uncompr;        // Source register 2 is used
    wire             rd_wr_en_uncompr;        // Destination register write enable
    wire [5:0]       rd_wr_src_1h_uncompr;    // Writeback source (one-hot, 6-bit)
    
    // ALU Operation
    wire [`XLEN-1:0] alu_op_a_uncompr;        // ALU operand A
    wire [`XLEN-1:0] alu_op_b_uncompr;        // ALU operand B
    wire             alu_uses_rs1_uncompr;    // ALU uses rs1 as operand A
    wire             alu_uses_rs2_uncompr;    // ALU uses rs2 as operand B
    wire [5:0]       alu_operation_uncompr;   // ALU operation code
    
    // Flow Control and Exceptions
    wire [5:0]       branch_cond_1h_uncompr;  // Branch condition (one-hot)
    wire             branch_uncompr;          // Branch/jump instruction
    wire             ebreak_uncompr;          // EBREAK instruction
    wire             ecall_ex;                // ECALL exception
    wire             mret;                    // MRET instruction
    wire             wait_for_int;            // WFI instruction
    wire             fencei;                  // FENCE.I instruction
    wire             illegal_inst_uncompr;    // Illegal instruction detected
    
    // CSR Signals
    wire             csr_rd_en;               // CSR read enable
    wire             sys_csr;                 // System CSR instruction
    wire [`XLEN-1:0] csr_immed;               // CSR immediate value
    
    //===================== Standard Decoder Instantiation =================//
    // Instantiate the standard 32-bit instruction decoder
    cpu64_decoder #(.VADDR(VADDR)) i_standard_decoder(
        //===================== Inputs =====================================//
        .inst_i            (inst_i),               // 32-bit instruction
        .pc_i              (pc_i),                 // Program counter
        .rs1_data_i        (rs1_data_i),           // Source register 1 data
        .rs2_data_i        (rs2_data_i),           // Source register 2 data
        
        //===================== CSR Controls ==============================//
        .csr_rd_en_i       (csr_rd_en),            // CSR read enable
        .sys_csr_i         (sys_csr),              // System CSR instruction
        .csr_imm_ao        (csr_immed),            // CSR immediate value
        
        //===================== Load/Store Controls =======================//
        .mem_width_1h_ao   (mem_width_1h_uncompr), // Memory access width (one-hot)
        .mem_sign_ao       (mem_sign_uncompr),     // Memory sign extension
        .mem_rd_ao         (mem_rd_uncompr),       // Memory read enable
        .mem_wr_ao         (mem_wr_uncompr),       // Memory write enable
        
        //===================== Register File Controls ====================//
        .rs1_idx_ao        (rs1_idx_uncompr),      // Source register 1 index
        .rs2_idx_ao        (rs2_idx_uncompr),      // Source register 2 index
        .rd_idx_ao         (rd_idx_uncompr),       // Destination register index
        .rs1_used_ao       (rs1_used_uncompr),     // Source register 1 is used
        .rs2_used_ao       (rs2_used_uncompr),     // Source register 2 is used
        .rd_wr_en_ao       (rd_wr_en_uncompr),     // Destination register write enable
        .rd_wr_src_1h_ao   (rd_wr_src_1h_uncompr), // Writeback source (one-hot)
        
        //===================== ALU Operation =============================//
        .alu_op_a_ao       (alu_op_a_uncompr),     // ALU operand A
        .alu_op_b_ao       (alu_op_b_uncompr),     // ALU operand B
        .alu_uses_rs1_ao   (alu_uses_rs1_uncompr), // ALU uses rs1 as operand A
        .alu_uses_rs2_ao   (alu_uses_rs2_uncompr), // ALU uses rs2 as operand B
        .alu_operation_ao  (alu_operation_uncompr), // ALU operation code
        
        //===================== Flow Control and Exceptions ===============//
        .branch_cond_1h_ao (branch_cond_1h_uncompr), // Branch condition (one-hot)
        .branch_ao         (branch_uncompr),        // Branch/jump instruction
        .ebreak_ao         (ebreak_uncompr),        // EBREAK instruction
        .fencei_ao         (fencei),                // FENCE.I instruction
        .ecall_ex_ao       (ecall_ex),              // ECALL exception
        .mret_ao           (mret),                  // MRET instruction
        .wait_for_int_ao   (wait_for_int),          // WFI instruction
        .illegal_inst_ao   (illegal_inst_uncompr)   // Illegal instruction detected
    );

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                               Compressed Instruction Decoder                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Decodes 16-bit RISC-V compressed instructions and generates equivalent control signals
    // Handles all compressed instruction types including ALU, memory, and control flow operations

    //===================== Compressed Instruction Detection ===============//
    wire [1:0]       quadrant     = inst_i[1:0];  // 2-bit quadrant field
    wire             compressed   = (quadrant != 2'b11);  // Compressed if not quadrant 3 (32-bit)

    //===================== Compressed Decoder Output Signal Declarations =//
    // Load/Store Controls
    wire [3:0]       mem_width_1h_compr;    // Memory access width (one-hot)
    wire             mem_sign_compr;        // Memory sign extension control
    wire             mem_rd_compr;          // Memory read enable
    wire             mem_wr_compr;          // Memory write enable
    
    // Register File Controls
    wire [4:0]       rs1_idx_compr;         // Source register 1 index
    wire [4:0]       rs2_idx_compr;         // Source register 2 index
    wire [4:0]       rd_idx_compr;          // Destination register index
    wire             rs1_used_compr;        // Source register 1 is used
    wire             rs2_used_compr;        // Source register 2 is used
    wire             rd_wr_en_compr;        // Destination register write enable
    wire [5:0]       rd_wr_src_1h_compr;    // Writeback source (one-hot, 6-bit)
    
    // ALU Operation
    wire [`XLEN-1:0] alu_op_a_compr;        // ALU operand A
    wire [`XLEN-1:0] alu_op_b_compr;        // ALU operand B
    wire             alu_uses_rs1_compr;    // ALU uses rs1 as operand A
    wire             alu_uses_rs2_compr;    // ALU uses rs2 as operand B
    wire [5:0]       alu_operation_compr;   // ALU operation code
    
    // Flow Control and Exceptions
    wire [5:0]       branch_cond_1h_compr;  // Branch condition (one-hot)
    wire             branch_compr;          // Branch/jump instruction
    wire             ebreak_compr;          // EBREAK instruction
    wire             illegal_inst_compr;    // Illegal instruction detected
    
    
    //===================== Compressed Decoder Instantiation ===============//
    // Instantiate the compressed 16-bit instruction decoder
    cpu64_compressed_decoder #(.VADDR(VADDR)) i_compressed_decoder(
        //===================== Inputs =====================================//
        .inst_i            (inst_i[15:0]),        // 16-bit compressed instruction
        .pc_i              (pc_i),                 // Program counter
        .rs1_data_i        (rs1_data_i),           // Source register 1 data
        .rs2_data_i        (rs2_data_i),           // Source register 2 data
        
        //===================== Load/Store Controls =======================//
        .mem_width_1h_ao   (mem_width_1h_compr),  // Memory access width (one-hot)
        .mem_sign_ao       (mem_sign_compr),      // Memory sign extension
        .mem_rd_ao         (mem_rd_compr),        // Memory read enable
        .mem_wr_ao         (mem_wr_compr),        // Memory write enable
        
        //===================== Register File Controls ====================//
        .rs1_idx_ao        (rs1_idx_compr),       // Source register 1 index
        .rs2_idx_ao        (rs2_idx_compr),       // Source register 2 index
        .rd_idx_ao         (rd_idx_compr),        // Destination register index
        .rs1_used_ao       (rs1_used_compr),      // Source register 1 is used
        .rs2_used_ao       (rs2_used_compr),      // Source register 2 is used
        .rd_wr_en_ao       (rd_wr_en_compr),      // Destination register write enable
        .rd_wr_src_1h_ao   (rd_wr_src_1h_compr),  // Writeback source (one-hot)
        
        //===================== ALU Operation =============================//
        .alu_op_a_ao       (alu_op_a_compr),      // ALU operand A
        .alu_op_b_ao       (alu_op_b_compr),      // ALU operand B
        .alu_uses_rs1_ao   (alu_uses_rs1_compr),  // ALU uses rs1 as operand A
        .alu_uses_rs2_ao   (alu_uses_rs2_compr),  // ALU uses rs2 as operand B
        .alu_operation_ao  (alu_operation_compr), // ALU operation code
        
        //===================== Flow Control and Exceptions ===============//
        .branch_cond_1h_ao (branch_cond_1h_compr), // Branch condition (one-hot)
        .branch_ao         (branch_compr),         // Branch/jump instruction
        .ebreak_ao         (ebreak_compr),         // EBREAK instruction
        .illegal_inst_ao   (illegal_inst_compr)    // Illegal instruction detected
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  Atomic Instruction Decoder                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Decodes RV64A atomic memory operations (AMO) including LR/SC
    // Identifies AMO instructions and extracts operation type and operands

    //===================== Atomic Decoder Output Signals =================//
    wire         is_amo;           // Is this an AMO instruction?
    wire         is_lr;            // Is this a Load-Reserved instruction?
    wire         is_sc;            // Is this a Store-Conditional instruction?
    wire [4:0]   amo_op;           // AMO operation type (funct5)
    wire         amo_word;         // AMO word operation (1=.W, 0=.D)
    wire [4:0]   amo_rs1;          // AMO address base register
    wire [4:0]   amo_rs2;          // AMO source operand register
    wire [4:0]   amo_rd;           // AMO destination register

    //===================== Atomic Decoder Instantiation ==================//
    // Instantiate the atomic instruction decoder
    // Only processes 32-bit instructions (not compressed)
    cpu64_atomic_decoder i_atomic_decoder (
        //===================== Inputs =====================================//
        .instr_i            (inst_i),              // 32-bit instruction
        
        //===================== Decoded Outputs ============================//
        .is_amo_o           (is_amo),              // Is AMO instruction
        .is_lr_o            (is_lr),               // Is Load-Reserved
        .is_sc_o            (is_sc),               // Is Store-Conditional
        .amo_op_o           (amo_op),              // AMO operation type
        .amo_word_o         (amo_word),            // Word/doubleword selector
        .rs1_o              (amo_rs1),             // Address base register
        .rs2_o              (amo_rs2),             // Source operand register
        .rd_o               (amo_rd)               // Destination register
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                       Compressed vs Uncompressed Decoder Multiplexer                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Selects between compressed and uncompressed decoder outputs based on instruction type
    // Provides unified control signals to the rest of the pipeline

    //===================== Load/Store Control Multiplexing ===============//
    // Select memory control signals based on instruction compression
    wire       mem_wr          = compressed ? mem_wr_compr         : mem_wr_uncompr;      // Memory write enable
    wire       mem_rd          = compressed ? mem_rd_compr         : mem_rd_uncompr;      // Memory read enable
    wire       mem_sign        = compressed ? mem_sign_compr       : mem_sign_uncompr;    // Memory sign extension
    wire [3:0] mem_width_1h    = compressed ? mem_width_1h_compr   : mem_width_1h_uncompr; // Memory access width

    //===================== Register File Control Multiplexing ============//
    // Select register control signals based on instruction compression
    wire [4:0] rs1_idx         = compressed ? rs1_idx_compr        : rs1_idx_uncompr;     // Source register 1 index
    wire [4:0] rs2_idx         = compressed ? rs2_idx_compr        : rs2_idx_uncompr;     // Source register 2 index
    wire [4:0] rd_idx          = compressed ? rd_idx_compr         : rd_idx_uncompr;      // Destination register index
    wire       rs1_used        = compressed ? rs1_used_compr       : rs1_used_uncompr;    // Source register 1 is used
    wire       rs2_used        = compressed ? rs2_used_compr       : rs2_used_uncompr;    // Source register 2 is used
    wire       rd_wr_en        = compressed ? rd_wr_en_compr       : rd_wr_en_uncompr;    // Destination register write enable
    wire [5:0] rd_wr_src_1h    = compressed ? rd_wr_src_1h_compr   : rd_wr_src_1h_uncompr; // Writeback source (6-bit)

    //===================== ALU Operation Multiplexing ====================//
    // Select ALU control signals based on instruction compression
    wire [`XLEN-1:0] alu_op_a  = compressed ? alu_op_a_compr       : alu_op_a_uncompr;    // ALU operand A
    wire [`XLEN-1:0] alu_op_b  = compressed ? alu_op_b_compr       : alu_op_b_uncompr;    // ALU operand B
    wire        alu_uses_rs1   = compressed ? alu_uses_rs1_compr   : alu_uses_rs1_uncompr; // ALU uses rs1
    wire        alu_uses_rs2   = compressed ? alu_uses_rs2_compr   : alu_uses_rs2_uncompr; // ALU uses rs2
    wire [5:0]  alu_operation  = compressed ? alu_operation_compr  : alu_operation_uncompr; // ALU operation code

    //===================== Flow Control Multiplexing =====================//
    // Select flow control signals based on instruction compression
    wire [5:0] branch_cond_1h  = compressed ? branch_cond_1h_compr : branch_cond_1h_uncompr; // Branch condition
    wire       branch          = compressed ? branch_compr         : branch_uncompr;          // Branch/jump instruction
    wire       ebreak_ex       = compressed ? ebreak_compr         : ebreak_uncompr;          // EBREAK instruction

    //===================== Program Counter Control =======================//
    // Adjust next PC for compressed instructions (16-bit vs 32-bit)
    wire [VADDR-1:0] next_pc   = compressed ? (next_pc_i - 2) : next_pc_i;  // Compressed: -2, Standard: +0
    assign compressed_instr_ao = compressed && valid;  // Feedback to fetch stage

    //===================== Register Index Outputs ========================//
    // Output register indices for register file access
    assign rs1_idx_ao = rs1_idx;  // Source register 1 index
    assign rs2_idx_ao = rs2_idx;  // Source register 2 index


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            Control Status Register Operations                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Handles CSR read/write operations and load-use hazard detection
    // Generates CSR control signals for system instructions

    //===================== Instruction Field Extraction ==================//
    wire [6:0] opcode    = inst_i[6:0];      // 7-bit opcode field
    wire [2:0] func3     = inst_i[14:12];    // 3-bit function field
    wire [11:0] csr_addr = inst_i[31:20];    // 12-bit CSR address
    reg  [2:0]  csr_op_1h;                   // CSR operation (one-hot)

    //===================== CSR Instruction Detection =====================//
    // Detect system CSR instructions (exclude privileged instructions like ECALL, EBREAK)
    assign sys_csr   = (opcode == `OPCODE_SYSTEM) && (func3 != `SYSTEM_OP_PRIV);
    
    // Detect CSR read/write operations (vs read-and-modify operations)
    wire   csr_op_rw = (func3 == `SYSTEM_OP_CSRRW) || (func3 == `SYSTEM_OP_CSRRWI);

    //===================== CSR Read/Write Control ========================//
    // Generate CSR control signals based on instruction type and validity
    wire   csr_wr_en           = sys_csr && (csr_op_rw || csr_immed != 'b0) && valid;  // CSR write enable
    assign csr_rd_en           = sys_csr && (!csr_op_rw || rd_idx != 'b0);             // CSR read enable
    assign csr_rd_en_ao        = csr_rd_en && valid && ~stall_i;                       // CSR read enable output
    assign csr_addr_ao         = csr_addr;                                             // CSR address output
    
    //===================== CSR Load-Use Hazard Detection =================//
    // Detect CSR load-use hazard: DCD reads CSR that EXE stage is writing
    assign csr_load_use_haz_ao = (csr_addr == EXE_csr_addr_i) && EXE_csr_wr_en_i && csr_rd_en;
    
    //===================== CSR ALU Operation Decoder ====================//
    // Generate one-hot CSR operation codes for ALU
    always @(*) begin
        if (sys_csr) begin
            case (func3)
                `SYSTEM_OP_CSRRW : csr_op_1h = `CSR_ALU_OP_1H_RW;  // Read/Write
                `SYSTEM_OP_CSRRWI: csr_op_1h = `CSR_ALU_OP_1H_RW;  // Read/Write Immediate
                `SYSTEM_OP_CSRRS : csr_op_1h = `CSR_ALU_OP_1H_RS;  // Read and Set
                `SYSTEM_OP_CSRRSI: csr_op_1h = `CSR_ALU_OP_1H_RS;  // Read and Set Immediate
                `SYSTEM_OP_CSRRC : csr_op_1h = `CSR_ALU_OP_1H_RC;  // Read and Clear
                `SYSTEM_OP_CSRRCI: csr_op_1h = `CSR_ALU_OP_1H_RC;  // Read and Clear Immediate
                default          : csr_op_1h = 'b0;                 // No CSR operation
            endcase
        end else 
            csr_op_1h = 'b0;  // No CSR operation for non-system instructions
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                Illegal Instruction Detector                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Detects illegal instructions from various sources and generates exception signal

    //===================== Illegal Instruction Detection =================//
    // Combine illegal instruction signals from multiple sources
    wire illegal_inst_ex = (compressed  && illegal_inst_compr)   ||  // Compressed instruction is illegal
                           (~compressed && illegal_inst_uncompr) ||  // Standard instruction is illegal
                            csr_rd_ex_i                          ||  // CSR read exception
                            !(|inst_i[15:0]);                        // All-zero instruction (illegal)


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      Pipeline Registers                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Pipeline register updates for decode stage outputs
    // Handles stall conditions and validity propagation

    //===================== Validity Register =============================//
    // Update decode stage validity based on input validity and stall conditions
    always @(posedge clk_i) begin
        if (~rst_ni)
            valid_o <= 1'b0;        // Reset: invalid
        else if (~stall_i)
            valid_o <= valid;       // Update: use validity tracker output
    end

    //===================== Decode Pipeline Registers ====================//
    // Update all decode stage outputs with stall handling
    // On stall: preserve current values; On normal operation: update with new values
    always @(posedge clk_i) begin : decode_pipeline_registers
        //===================== Register Source 1 (rs1) ===================//
        rs1_idx_o           <= (stall_i) ? rs1_idx_o         : (rs1_used ? rs1_idx : 'b0);
        rs1_used_o          <= (stall_i) ? rs1_used_o        : rs1_used;
        rs1_data_o          <= (stall_i) ? rs1_data_o        : rs1_data_i;
        
        //===================== Register Source 2 (rs2) ===================//
        rs2_idx_o           <= (stall_i) ? rs2_idx_o         : (rs2_used ? rs2_idx : 'b0);
        rs2_used_o          <= (stall_i) ? rs2_used_o        : rs2_used;
        rs2_data_o          <= (stall_i) ? rs2_data_o        : rs2_data_i;
        
        //===================== Destination Register (rd) =================//
        rd_idx_o            <= (stall_i) ? rd_idx_o          : rd_idx;
        rd_wr_en_o          <= (stall_i) ? rd_wr_en_o        : rd_wr_en;
        rd_wr_src_1h_o      <= (stall_i) ? rd_wr_src_1h_o    : rd_wr_src_1h;
        
        //===================== ALU Operation and Operands ================//
        alu_operation_o     <= (stall_i) ? alu_operation_o   : alu_operation;
        alu_op_a_o          <= (stall_i) ? alu_op_a_o        : alu_op_a;
        alu_op_b_o          <= (stall_i) ? alu_op_b_o        : alu_op_b;
        alu_uses_rs1_o      <= (stall_i) ? alu_uses_rs1_o    : alu_uses_rs1;
        alu_uses_rs2_o      <= (stall_i) ? alu_uses_rs2_o    : alu_uses_rs2;
        
        //===================== Load/Store Control ========================//
        mem_width_1h_o      <= (stall_i) ? mem_width_1h_o    : mem_width_1h;
        mem_rd_o            <= (stall_i) ? mem_rd_o          : mem_rd;
        mem_wr_o            <= (stall_i) ? mem_wr_o          : mem_wr;
        mem_sign_o          <= (stall_i) ? mem_sign_o        : mem_sign;
        
        //===================== Flow Control ==============================//
        branch_o            <= (stall_i) ? branch_o          : branch;
        pc_o                <= (stall_i) ? pc_o              : pc_i;
        next_pc_o           <= (stall_i) ? next_pc_o         : next_pc;
        br_cond_1h_o        <= (stall_i) ? br_cond_1h_o      : branch_cond_1h;
        
        //===================== CSR Control ===============================//
        csr_wr_en_o         <= (stall_i) ? csr_wr_en_o       : csr_wr_en;
        csr_op_1h_o         <= (stall_i) ? csr_op_1h_o       : csr_op_1h;
        csr_addr_o          <= (stall_i) ? csr_addr_o        : csr_addr;
        
        //===================== Traps and Exceptions ======================//
        ecall_ex_o          <= (stall_i) ? ecall_ex_o        : ecall_ex;
        ebreak_ex_o         <= (stall_i) ? ebreak_ex_o       : ebreak_ex;
        illegal_inst_ex_o   <= (stall_i) ? illegal_inst_ex_o : illegal_inst_ex;
        mret_o              <= (stall_i) ? mret_o            : mret;
        wait_for_int_o      <= (stall_i) ? wait_for_int_o    : wait_for_int;
        fencei_o            <= (stall_i) ? fencei_o          : fencei;
        
        //===================== Atomic Operations =========================//
        is_amo_o            <= (stall_i) ? is_amo_o          : is_amo;
        is_lr_o             <= (stall_i) ? is_lr_o           : is_lr;
        is_sc_o             <= (stall_i) ? is_sc_o           : is_sc;
        amo_op_o            <= (stall_i) ? amo_op_o          : amo_op;
        amo_word_o          <= (stall_i) ? amo_word_o        : amo_word;
    end


`ifdef CPU64_DBG_TRACE
    //===================== Debug Trace ==========================//
    always @(posedge clk_i) begin
        if (rst_ni && ~stall_i && valid_o) begin
            $display("[DCD] pc=0x%0h inst=0x%08h rs1=x%0d(%0b) rs2=x%0d(%0b) rd=x%0d we=%0b alu_op=%0d mem_rd=%0b mem_wr=%0b branch=%0b csr=%0b trap=%0b", 
                     pc_o, inst_i, rs1_idx_o, rs1_used_o, rs2_idx_o, rs2_used_o, rd_idx_o, rd_wr_en_o, alu_operation_o, mem_rd_o, mem_wr_o, branch_o, csr_wr_en_o, (ecall_ex_o | illegal_inst_ex_o | ebreak_ex_o));
        end
    end
`endif


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  RISC-V Formal Interface                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Optional RISC-V Formal Interface for formal verification
    // Provides instruction trace information for verification tools

`ifdef CPU64_RVFI

    //===================== RISC-V Formal Interface Trap Signal ===========//
    // Generate trap signal for formal verification
    always @(posedge clk_i) begin
        if (~rst_ni)
            rvfi_trap_o       <= '0;                           // Reset: no trap
        else if (squash_i || bubble_i)
            rvfi_trap_o       <= '0;                           // Squash/bubble: no trap
        else if (~stall_i)
            rvfi_trap_o       <= illegal_inst_ex && valid;     // Trap on illegal instruction
    end

    //===================== RISC-V Formal Interface Trace Data ============//
    // Generate instruction trace data for formal verification
    always @(posedge clk_i) begin
        if (~stall_i) begin
            // Instruction: 32-bit for standard, 16-bit padded for compressed
            rvfi_insn_o       <= inst_i[1:0] == 2'b11 ? inst_i : {16'b0, inst_i[15:0]};
            // Program counter: current PC
            rvfi_pc_rdata_o   <= 64'(pc_i);
            // Next program counter: calculated next PC
            rvfi_pc_wdata_o   <= 64'(next_pc);
        end
    end

`endif


endmodule
