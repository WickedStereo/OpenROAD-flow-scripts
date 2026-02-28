///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_execute_stage                                                             //
// Description: Execute stage performs ALU operations, branch resolution, data forwarding,
//              and CSR processing. Contains I-ALU, M-ALU, bypass unit, and branch
//              resolution logic. Handles all arithmetic, logical, and control operations.
//              This stage is responsible for executing instructions, resolving branches,
//              performing data forwarding to resolve RAW hazards, and generating control
//              signals for memory operations and register writes. Branch conditions are
//              detected and resolved at this stage, and exceptions are generated.
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_execute_stage #(parameter VADDR = 39) (
    //===================== Clock and Reset =====================//
    input                   clk_i,              // System clock
    input                   rst_ni,             // Active-low reset
    
    //===================== Pipeline Control ===================//
    input                   squash_i,           // Squash current instruction
    input                   bubble_i,           // Insert bubble (NOP)
    input                   stall_i,            // Stall pipeline

    //===================== Decode Stage Inputs ================//
    input                   valid_i,            // Instruction is valid
    // Register Source 1 (rs1)
    input       [4:0]       rs1_idx_i,          // Source register 1 index
    input                   rs1_used_i,         // Source register 1 is used
    input [`XLEN-1:0]       rs1_data_i,         // Source register 1 data
    // Register Source 2 (rs2)
    input       [4:0]       rs2_idx_i,          // Source register 2 index
    input                   rs2_used_i,         // Source register 2 is used
    input [`XLEN-1:0]       rs2_data_i,         // Source register 2 data
    // Destination Register (rd)
    input       [4:0]       rd_idx_i,           // Destination register index
    input                   rd_wr_en_i,         // Destination register write enable
    input       [5:0]       rd_wr_src_1h_i,     // Writeback source (one-hot, 6-bit for AMO)
    // ALU Operation and Operands
    input       [5:0]       alu_operation_i,    // ALU operation code
    input [`XLEN-1:0]       alu_op_a_i,         // ALU operand A
    input [`XLEN-1:0]       alu_op_b_i,         // ALU operand B
    input                   alu_uses_rs1_i,     // ALU uses rs1 as operand A
    input                   alu_uses_rs2_i,     // ALU uses rs2 as operand B
    // Load/Store
    input       [3:0]       mem_width_1h_i,     // Memory access width (one-hot)
    input                   mem_rd_i,           // Memory read enable
    input                   mem_wr_i,           // Memory write enable
    input                   mem_sign_i,         // Memory sign extension
    // Flow Control
    input                   branch_i,           // Branch/jump instruction
    input [VADDR-1:0]       pc_i,               // Program counter
    input [VADDR-1:0]       next_pc_i,          // Next program counter
    input       [5:0]       br_cond_1h_i,       // Branch condition (one-hot)
    // CSR Control
    input                   csr_wr_en_i,        // CSR write enable
    input [2:0]             csr_op_1h_i,        // CSR operation (one-hot)
    input [11:0]            csr_wr_addr_i,      // CSR write address
    // Traps and Exceptions
    input                   ecall_ex_i,         // ECALL exception
    input                   ebreak_ex_i,        // EBREAK exception
    input                   illegal_inst_ex_i,  // Illegal instruction exception
    input                   mret_i,             // MRET instruction
    input                   wait_for_int_i,     // WFI instruction
    input                   fencei_i,           // FENCE.I instruction
    // Atomic Operation Inputs
    input                   is_amo_i,           // Is AMO instruction
    input                   is_lr_i,            // Is Load-Reserved instruction
    input                   is_sc_i,            // Is Store-Conditional instruction
    input       [4:0]       amo_op_i,           // AMO operation type
    input                   amo_word_i,         // AMO word operation flag

    //===================== Forwarded Register Data =============//
    input                   MEM_rd_wr_en_i,     // MEM stage register write enable
    input                   MEM_valid_i,        // MEM stage valid
    input      [4:0]        MEM_rd_idx_i,       // MEM stage destination register
    input      [`XLEN-1:0]  MEM_rd_data_i,      // MEM stage register data
    
    input                   WB_rd_wr_en_i,      // WB stage register write enable
    input                   WB_valid_i,         // WB stage valid
    input      [4:0]        WB_rd_idx_i,        // WB stage destination register
    input      [`XLEN-1:0]  WB_rd_data_i,       // WB stage register data

    //===================== CSR Interface ======================//
    input      [`XLEN-1:0]  csr_rdata_i,        // CSR read data
    output wire             csr_wr_en_ao,       // CSR write enable output
    output wire [11:0]      csr_wr_addr_ao,     // CSR write address output
    output reg [`XLEN-1:0]  csr_wdata_ao,       // CSR write data output
    input                   csr_wr_ex_i,        // CSR write exception

    //===================== Traps and Exceptions ===============//
    output wire             ecall_ex_ao,        // ECALL exception output
    output wire             ebreak_ex_ao,       // EBREAK exception output
    output wire             illegal_inst_ex_ao, // Illegal instruction exception output
    output wire             mret_ao,            // MRET instruction output
    output wire             wait_for_int_ao,    // WFI instruction output
    output                  fencei_ao,          // FENCE.I instruction output

    //===================== Flow Control Outputs ===============//
    output wire             branch_o,           // Branch taken output
    output wire [VADDR-1:0] target_addr_o,      // Branch target address
    output wire             load_use_haz_ao,    // Load-use hazard detected
    output wire             alu_stall_o,        // ALU stall required
    output wire             mem_wr_ao,          // Memory write output

    //===================== Pipeline Outputs ===================//
    output reg              valid_o,            // Valid instruction output
    output reg [VADDR-1:0]  dmem_addr_o,        // Data memory address
    output reg [`XLEN-1:0]  rs2_data_o,         // Source register 2 data output
    output reg [4:0]        rs2_idx_o,          // Source register 2 index output
    // Destination Register (rd)
    output reg [`XLEN-1:0]  rd_data_o,          // Destination register data
    output reg [4:0]        rd_idx_o,           // Destination register index
    output reg              rd_wr_en_o,         // Destination register write enable
    output reg              rd_wr_src_load_o,   // Writeback source is memory
    // Load/Store
    output reg [3:0]        mem_width_1h_o,     // Memory access width output
    output reg              mem_rd_o,           // Memory read enable output
    output reg              mem_wr_o,           // Memory write enable output
    output reg              mem_sign_o,         // Memory sign extension output
    output reg [VADDR-1:0]  pc_o,               // Program counter output
    // Atomic Operations
    output reg              is_amo_o,           // Atomic operation flag
    output reg              is_lr_o,            // Load-Reserved flag
    output reg              is_sc_o,            // Store-Conditional flag
    output reg [4:0]        amo_op_o,           // Atomic operation type
    output reg              amo_word_o          // Atomic word operation flag

`ifdef CPU64_RVFI
    ,
    input [  32 - 1 : 0]         rvfi_insn_i,
    input                        rvfi_trap_i,
    input [`XLEN - 1 : 0]        rvfi_pc_rdata_i,
    input [`XLEN - 1 : 0]        rvfi_pc_wdata_i,

    output reg [  32 - 1 : 0]    rvfi_insn_o,
    output reg                   rvfi_trap_o,
    output reg [   5 - 1 : 0]    rvfi_rs1_addr_o,
    output reg [   5 - 1 : 0]    rvfi_rs2_addr_o,
    output reg [`XLEN - 1 : 0]   rvfi_rs1_rdata_o,
    output reg [`XLEN - 1 : 0]   rvfi_rs2_rdata_o,
    output reg [`XLEN - 1 : 0]   rvfi_pc_rdata_o,
    output reg [`XLEN - 1 : 0]   rvfi_pc_wdata_o
`endif
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      Validity Tracker                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Tracks instruction validity through the execute stage
    // Handles pipeline control signals (squash, bubble, stall) to determine
    // if the current instruction should be executed or invalidated

    wire valid;    // Valid instruction signal for execute stage

    //===================== Validity Tracker Instantiation ======//
    // Instantiate validity tracker to manage instruction validity
    // This module handles the complex logic of remembering squashes during stalls/bubbles
    cpu64_validity_tracker EXE_validity_tracker (
        .clk_i          (clk_i),        // System clock
        .rst_ni         (rst_ni),       // Active-low reset

        .valid_i        (valid_i),      // Input valid signal from decode stage
        
        .squash_i       (squash_i),     // Squash current instruction
        .bubble_i       (bubble_i),     // Insert bubble (NOP)
        .stall_i        (stall_i),      // Stall pipeline

        .valid_ao       (valid)         // Output valid signal for execute stage
    );

    //===================== Memory Write Output =================//
    // Generate memory write signal only when instruction is valid
    // This prevents memory writes from invalid instructions
    assign mem_wr_ao = valid && mem_wr_i;
`ifdef CPU64_DBG_TRACE
    //===================== Debug Trace ==========================//
    always @(posedge clk_i) begin
        if (rst_ni && ~stall_i && valid_o) begin
            $display("[EXE] pc=0x%0h op=%0d rs1=x%0d rs2=x%0d rd=x%0d rd_we=%0b alu_res=0x%016h mem_rd=%0b mem_wr=%0b branch=%0b target=0x%0h csr_we=%0b exception=%0b", 
                     pc_o, alu_operation_i, rs1_idx_i, rs2_idx_i, rd_idx_o, rd_wr_en_o, rd_data_o, mem_rd_o, mem_wr_o, branch_o, target_addr_o, csr_wr_en_ao, (ecall_ex_ao | ebreak_ex_ao | illegal_inst_ex_ao));
        end
    end
`endif
    
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       Bypass Units                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Data forwarding units to resolve Read-After-Write (RAW) hazards
    // Forward data from later pipeline stages to avoid stalling the pipeline
    // when an instruction needs data that is being produced by a previous instruction

    //===================== Bypass Unit Signals ==================//
    wire [`XLEN-1:0] alu_op_a,   alu_op_b,   rs1_data,  rs2_data;  // ALU operands and forwarded data
    wire             rs1_lu_haz, rs2_lu_haz;                       // Load-use hazard flags

    //===================== RS1 Bypass Unit ======================//
    // Forward data for source register 1 (rs1)
    // Handles data forwarding from EXE and MEM stages to resolve RAW hazards
    cpu64_bypass_unit rs1_bypass_unit (
        //===================== Clock and Reset =================//
        .clk_i              (clk_i),        // System clock
        .rst_ni             (rst_ni),       // Active-low reset
        .stall_i            (stall_i),      // Pipeline stall signal
        .bubble_i           (bubble_i),     // Pipeline bubble signal

        //===================== EXE Stage Forwarding ============//
        // Forward from instruction in MEM stage (not from EXE's own output)
        .EXE_mem_read_i     (mem_rd_o), // EXE stage has load instruction
        .EXE_rd_wr_en_i     (MEM_rd_wr_en_i), // MEM stage register write enable
        .EXE_valid_i        (MEM_valid_i),    // MEM stage valid
        .EXE_rd_idx_i       (MEM_rd_idx_i),   // MEM stage destination register
        .EXE_rd_data_i      (MEM_rd_data_i),  // MEM stage register data

        //===================== MEM Stage Forwarding ============//
        .MEM_rd_wr_en_i     (MEM_rd_wr_en_i), // MEM stage register write enable
        .MEM_valid_i        (MEM_valid_i),    // MEM stage valid
        .MEM_rd_idx_i       (MEM_rd_idx_i),   // MEM stage destination register
        .MEM_rd_data_i      (MEM_rd_data_i),  // MEM stage register data
        
        //===================== WB Stage Forwarding =============//
        .WB_rd_wr_en_i      (WB_rd_wr_en_i),  // WB stage register write enable
        .WB_valid_i         (WB_valid_i),     // WB stage valid
        .WB_rd_idx_i        (WB_rd_idx_i),    // WB stage destination register
        .WB_rd_data_i       (WB_rd_data_i),   // WB stage register data

        //===================== Source Register =================//
        .rs_idx_i           (rs1_idx_i),     // Source register 1 index
        .rs_data_i          (rs1_data_i),    // Source register 1 data
        .rs_used_i          (rs1_used_i),    // Source register 1 is used

        //===================== Outputs =========================//
        .rs_data_ao         (rs1_data),      // Forwarded source register 1 data
        .load_use_hazard_ao (rs1_lu_haz)     // Load-use hazard for rs1
    );

    //===================== RS2 Bypass Unit ======================//
    // Forward data for source register 2 (rs2)
    // Handles data forwarding from EXE and MEM stages to resolve RAW hazards
    cpu64_bypass_unit rs2_bypass_unit (
        //===================== Clock and Reset =================//
        .clk_i              (clk_i),        // System clock
        .rst_ni             (rst_ni),       // Active-low reset
        .stall_i            (stall_i),      // Pipeline stall signal
        .bubble_i           (bubble_i),     // Pipeline bubble signal

        //===================== EXE Stage Forwarding ============//
        // Forward from instruction in MEM stage (not from EXE's own output)
        .EXE_mem_read_i     (mem_rd_o), // EXE stage has load instruction
        .EXE_rd_wr_en_i     (MEM_rd_wr_en_i), // MEM stage register write enable
        .EXE_valid_i        (MEM_valid_i),    // MEM stage valid
        .EXE_rd_idx_i       (MEM_rd_idx_i),   // MEM stage destination register
        .EXE_rd_data_i      (MEM_rd_data_i),  // MEM stage register data

        //===================== MEM Stage Forwarding ============//
        .MEM_rd_wr_en_i     (MEM_rd_wr_en_i), // MEM stage register write enable
        .MEM_valid_i        (MEM_valid_i),    // MEM stage valid
        .MEM_rd_idx_i       (MEM_rd_idx_i),   // MEM stage destination register
        .MEM_rd_data_i      (MEM_rd_data_i),  // MEM stage register data
        
        //===================== WB Stage Forwarding =============//
        .WB_rd_wr_en_i      (WB_rd_wr_en_i),  // WB stage register write enable
        .WB_valid_i         (WB_valid_i),     // WB stage valid
        .WB_rd_idx_i        (WB_rd_idx_i),    // WB stage destination register
        .WB_rd_data_i       (WB_rd_data_i),   // WB stage register data

        //===================== Source Register =================//
        .rs_idx_i           (rs2_idx_i),     // Source register 2 index
        .rs_data_i          (rs2_data_i),    // Source register 2 data
        .rs_used_i          (rs2_used_i),    // Source register 2 is used

        //===================== Outputs =========================//
        .rs_data_ao         (rs2_data),      // Forwarded source register 2 data
        .load_use_hazard_ao (rs2_lu_haz)     // Load-use hazard for rs2
    );
    
    //===================== Load-Use Hazard Detection ===========//
    // Combine load-use hazards from both source registers
    assign load_use_haz_ao = (rs1_lu_haz || rs2_lu_haz);
    
    //===================== ALU Stall Signal =====================//
    // Gate the ALU stall signal by instruction validity
    // Only stall for valid instructions that require multi-cycle operations
    assign alu_stall_o = valid && alu_stall_raw;

    //===================== ALU Operand Selection ===============//
    // Select ALU operands based on whether registers are used
    // Use forwarded data if register is used, otherwise use immediate/PC
    assign alu_op_a = (alu_uses_rs1_i) ? rs1_data : alu_op_a_i;  // ALU operand A
    assign alu_op_b = (alu_uses_rs2_i) ? rs2_data : alu_op_b_i;  // ALU operand B


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        CSR Controls                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Handles Control and Status Register (CSR) operations
    // Implements CSR read-modify-write operations and generates CSR control signals

    //===================== CSR Write Data Generation ============//
    // Generate CSR write data based on the CSR operation type
    // Implements RISC-V CSR read-modify-write operations
    always @(*) begin : csr_alu
        case (csr_op_1h_i)
            `CSR_ALU_OP_1H_RW: csr_wdata_ao = alu_op_a;                    // Read-Write: write ALU operand A
            `CSR_ALU_OP_1H_RS: csr_wdata_ao = csr_rdata_i | alu_op_a;      // Read-Set: set bits in CSR
            `CSR_ALU_OP_1H_RC: csr_wdata_ao = csr_rdata_i & ~alu_op_a;     // Read-Clear: clear bits in CSR
            default          : csr_wdata_ao = 'b0;                         // Default: write zero
        endcase
    end

    //===================== CSR Control Signals ==================//
    // Generate CSR write enable and address signals
    assign csr_wr_en_ao   = csr_wr_en_i && valid && ~stall_i;  // CSR write enable (only when valid and not stalled)
    assign csr_wr_addr_ao = csr_wr_addr_i;                     // CSR write address

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     Execution Unit(s)                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Contains the Integer ALU (I-ALU) and Multiply/Divide ALU (M-ALU)
    // Performs all arithmetic, logical, and control operations
    // Handles writeback source selection for register file updates

    //===================== ALU Result Signals ==================//
    wire [`XLEN-1:0] I_alu_res, M_alu_res;  // ALU result signals
    reg  [`XLEN-1:0] rd_data;                // Final register data
    wire             rd_wr_src_load;         // Writeback source is memory
    wire             alu_stall_raw;          // Raw ALU stall signal from M-ALU

    //===================== Integer ALU (I-ALU) =================//
    // Single-cycle integer ALU for basic arithmetic and logical operations
    // Handles ADD, SUB, AND, OR, XOR, shifts, and comparisons
    cpu64_I_alu i_I_alu 
    (
        .a_i             (alu_op_a),         // ALU operand A
        .b_i             (alu_op_b),         // ALU operand B
        .alu_operation_i (alu_operation_i),  // ALU operation code

        .alu_result_oa   (I_alu_res)        // I-ALU result
    );

    //===================== Multiply/Divide ALU (M-ALU) =========//
    // Multi-cycle ALU for multiply and divide operations
    // Handles MUL, MULH, DIV, REM operations with stall capability
    cpu64_M_alu i_M_alu 
    (
        //===================== Clock and Reset =================//
        .clk_i           (clk_i),            // System clock
        .rst_ni          (rst_ni),           // Active-low reset

        //===================== Operands and Operation ==========//
        .a_i             (alu_op_a),         // ALU operand A
        .b_i             (alu_op_b),         // ALU operand B
        .alu_operation_i (alu_operation_i),  // ALU operation code

        //===================== Outputs =========================//
        .alu_result_oa   (M_alu_res),       // M-ALU result
        .stall_o         (alu_stall_raw)    // ALU stall required (raw)
    );

    //===================== Writeback Source Selection ==========//
    // Select the source for register writeback based on instruction type
    // This determines where the result data comes from for register file updates
    always @(*) begin
        case (rd_wr_src_1h_i)
            `WB_SRC_1H_I_ALU     : rd_data = I_alu_res;                    // I-ALU result
            `WB_SRC_1H_M_ALU     : rd_data = M_alu_res;                    // M-ALU result
            `WB_SRC_1H_PC_PLUS_4 : rd_data = {{`XLEN-VADDR{1'b0}}, next_pc_i}; // PC + 4 (for JAL/JALR)
            `WB_SRC_CSR          : rd_data = csr_rdata_i;                  // CSR read data
            default              : rd_data = 'b0;                          // Default: zero
        endcase
    end

`ifdef CPU64_DBG_TRACE
    //===================== Debug Trace for ALU Results =========//
    always @(posedge clk_i) begin
        if (rst_ni && valid && (rd_wr_src_1h_i == `WB_SRC_1H_I_ALU) && rd_wr_en_i && (rd_idx_i != 5'd0)) begin
            $display("[EXE-DBG] PC=0x%h rd=x%0d I_alu_res=0x%h rd_data=0x%h alu_op_a=0x%h alu_op_b=0x%h stall=%b bubble=%b", 
                     pc_i, rd_idx_i, I_alu_res, rd_data, alu_op_a, alu_op_b, stall_i, bubble_i);
        end
    end
`endif

    //===================== Memory Writeback Detection ==========//
    // Detect if writeback source is memory (for load instructions and AMO)
    // This is used for forwarding and hazard detection
    assign rd_wr_src_load = (rd_wr_src_1h_i == `WB_SRC_1H_MEM) || (rd_wr_src_1h_i == `WB_SRC_1H_AMO);

`ifdef VERILATOR
    always @(posedge clk_i) begin
        if (rst_ni && valid && is_amo_i && (rd_idx_i != 0)) begin
            $display("[EXE] AMO detected: rd=x%0d rd_wr_src_1h_i=0x%h rd_wr_src_load=%b WB_SRC_1H_AMO=0x%h WB_SRC_1H_MEM=0x%h",
                     rd_idx_i, rd_wr_src_1h_i, rd_wr_src_load, `WB_SRC_1H_AMO, `WB_SRC_1H_MEM);
        end
    end
`endif

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        Flow Control                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Handles branch condition evaluation and flow control
    // Resolves conditional branches, jumps, and generates branch control signals

    //===================== Branch Condition Signals ============//
    wire eq, lt, ltu;    // Comparison results
    reg  branch_taken;   // Branch taken signal

    //===================== Comparison Logic ====================//
    // Generate comparison results for branch condition evaluation
    assign eq  = (rs1_data == rs2_data);                    // Equal comparison
    assign ltu = (rs1_data  < rs2_data);                    // Unsigned less than
    assign lt  = ( $signed(rs1_data) < $signed(rs2_data) ); // Signed less than

    //===================== Branch Condition Decoder ============//
    // Decode branch conditions and determine if branch should be taken
    // Implements RISC-V branch instruction condition evaluation
    always @ (*) begin
        case (br_cond_1h_i)
            `BR_OP_1H_BEQ  : branch_taken =  eq;     // Branch if equal
            `BR_OP_1H_BNE  : branch_taken = ~eq;     // Branch if not equal
            `BR_OP_1H_BLT  : branch_taken =  lt;     // Branch if less than (signed)
            `BR_OP_1H_BGE  : branch_taken = ~lt;     // Branch if greater/equal (signed)
            `BR_OP_1H_BLTU : branch_taken =  ltu;    // Branch if less than (unsigned)
            `BR_OP_1H_BGEU : branch_taken = ~ltu;    // Branch if greater/equal (unsigned)
            default        : branch_taken = 'b0;     // Default: no branch
        endcase
    end

    //===================== Branch Control Signals ==============//
    // Generate branch taken signal and target address
    // - Unconditional control flow: JAL/JALR (branch_i true, br_cond_1h_i == 0)
    // - Conditional branches: only when branch_taken is true and branch_i is true
    wire is_unconditional_flow = branch_i && (br_cond_1h_i == 6'b0);
    assign branch_o      = valid && ( is_unconditional_flow || (branch_taken && branch_i) || fencei_ao ) && ~stall_i;
    assign target_addr_o = fencei_ao ? next_pc_i : (is_unconditional_flow || (branch_taken && branch_i)) ? I_alu_res[VADDR-1:0] : '0;  // Branch target address

`ifdef CPU64_DBG_TRACE
    // DEBUG: Print ALL branches
    always @(posedge clk_i) begin
        if (branch_o) begin
            $display("[%0t cyc=%0d] BRANCH_O: PC=%h target=%h cond=%b uncond=%b taken=%b",
                     $time, $time/2, pc_i, I_alu_res[VADDR-1:0], branch_i && (br_cond_1h_i != 6'b0), is_unconditional_flow, branch_taken);
        end
    end
`endif


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Traps and Exceptions                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Handles trap and exception generation
    // Processes system calls, breakpoints, illegal instructions, and CSR exceptions

    //===================== Exception Detection =================//
    wire exception;    // Any exception is active

    //===================== Exception Output Generation =========//
    // Generate exception outputs only when instruction is valid
    // This prevents exceptions from invalid instructions
    assign ecall_ex_ao        = valid && ecall_ex_i;        // ECALL exception
    assign ebreak_ex_ao       = valid && ebreak_ex_i;       // EBREAK exception
    assign illegal_inst_ex_ao = valid && illegal_inst_ex_i || csr_wr_ex_i;  // Illegal instruction or CSR exception
    assign mret_ao            = valid && mret_i;            // MRET instruction
    assign wait_for_int_ao    = valid && wait_for_int_i;    // WFI instruction
    assign fencei_ao          = valid && fencei_i;          // FENCE.I instruction

    //===================== Exception Detection =================//
    // Detect if any exception is active
    assign exception          = ecall_ex_i || ebreak_ex_i || illegal_inst_ex_i || csr_wr_ex_i;


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Pipeline Outputs                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate the final pipeline outputs for the execute stage
    // These outputs are registered and only update when not stalled

    //===================== Valid Output Register ================//
    // Register the valid output signal
    // Invalid if exception occurs or instruction is not valid
    always @(posedge clk_i) begin
        if (~rst_ni)
            valid_o <= 1'b0;                         // Reset: invalid instruction
        else if (~stall_i)
            valid_o <= valid && (~exception);        // Normal: valid if no exception
    end

    //===================== Execute Pipeline Registers ===========//
    // Register all pipeline outputs for the next stage
    // On stall, all outputs remain unchanged to maintain pipeline state
    always @(posedge clk_i) begin
        if (~rst_ni) begin
            dmem_addr_o      <= '0;                  // Reset: clear data memory address
            rs2_data_o       <= '0;                  // Reset: clear source register 2 data
            rs2_idx_o        <= '0;                  // Reset: clear source register 2 index
            rd_data_o        <= '0;                  // Reset: clear destination register data
            rd_idx_o         <= '0;                  // Reset: clear destination register index
            rd_wr_en_o       <= 1'b0;                // Reset: clear register write enable
            rd_wr_src_load_o <= 1'b0;                // Reset: clear writeback source load
            mem_width_1h_o   <= '0;                  // Reset: clear memory width
            mem_rd_o         <= 1'b0;                // Reset: clear memory read enable
            mem_wr_o         <= 1'b0;                // Reset: clear memory write enable
            mem_sign_o       <= 1'b0;                // Reset: clear memory sign extension
            pc_o             <= '0;                  // Reset: clear program counter
            is_amo_o         <= 1'b0;                // Reset: clear AMO flag
            is_lr_o          <= 1'b0;                // Reset: clear LR flag
            is_sc_o          <= 1'b0;                // Reset: clear SC flag
            amo_op_o         <= '0;                  // Reset: clear AMO operation
            amo_word_o       <= 1'b0;                // Reset: clear AMO word flag
        end else if (~stall_i) begin
            // On stall, all outputs do not change
            dmem_addr_o      <= I_alu_res[VADDR-1:0];  // Data memory address
            rs2_data_o       <= rs2_data;              // Source register 2 data
            rs2_idx_o        <= rs2_idx_i;             // Source register 2 index
            rd_data_o        <= rd_data;               // Destination register data
            rd_idx_o         <= rd_idx_i;              // Destination register index
            rd_wr_en_o       <= rd_wr_en_i && valid && ~bubble_i && ~squash_i;   // Register write enable (gated by validity and control signals)
            rd_wr_src_load_o <= rd_wr_src_load;        // Writeback source is memory
            mem_width_1h_o   <= mem_width_1h_i;        // Memory access width
            mem_rd_o         <= mem_rd_i && valid;     // Memory read enable
            mem_wr_o         <= mem_wr_i && valid;     // Memory write enable
            mem_sign_o       <= mem_sign_i;            // Memory sign extension
            pc_o             <= pc_i;                  // Program counter
            is_amo_o         <= is_amo_i && valid;     // Atomic operation flag
            is_lr_o          <= is_lr_i && valid;      // Load-Reserved flag
            is_sc_o          <= is_sc_i && valid;      // Store-Conditional flag
            amo_op_o         <= amo_op_i;              // Atomic operation type
            amo_word_o       <= amo_word_i;            // Atomic word operation flag

`ifdef CPU64_DBG_TRACE
            // Debug: Monitor rd_data_o updates
            if (rd_wr_en_i && valid && (rd_idx_i != 5'd0)) begin
                $display("[EXE-REG] PC=0x%h rd=x%0d rd_data=0x%h -> rd_data_o=0x%h dmem_addr=0x%h", 
                         pc_i, rd_idx_i, rd_data, rd_data, I_alu_res[VADDR-1:0]);
            end
`endif
        end
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  RISC-V Formal Interface                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Optional RISC-V Formal Interface (RVFI) for formal verification
    // Provides instruction trace information for formal verification tools

`ifdef CPU64_RVFI

    //===================== RVFI Trap Signal ====================//
    // Generate trap signal for formal verification
    // Handles various trap conditions and pipeline control signals
    always @(posedge clk_i) begin
        if (~rst_ni)
            rvfi_trap_o       <= '0;                                    // Reset: clear trap signal
        else if (squash_i || bubble_i)
            rvfi_trap_o       <= '0;                                    // Squash/bubble: clear trap signal
        else if (~stall_i)
            rvfi_trap_o       <= rvfi_trap_i | (exception && valid) | csr_wr_ex_i;  // Normal: trap if exception
        else if (csr_wr_ex_i)
            rvfi_trap_o       <= csr_wr_ex_i;                           // CSR exception during stall
            // csr_wr_ex_i is included here because an invalid csr op will invalidate this 
            // instruction by the time csr_wr_ex_i reaches execute. If it reaches execute,
            // then the trap has been taken in fetch and this instruction is the trap instruction
    end

    //===================== RVFI Trace Data =====================//
    // Generate instruction trace data for formal verification
    // Only update when not stalled to maintain proper trace timing
    always @(posedge clk_i) begin
        if (~stall_i) begin
            rvfi_insn_o       <= rvfi_insn_i;                           // Instruction word
            rvfi_rs1_addr_o   <= rs1_used_i ? rs1_idx_i : '0;          // Source register 1 address
            rvfi_rs2_addr_o   <= rs2_used_i ? rs2_idx_i : '0;          // Source register 2 address
            rvfi_rs1_rdata_o  <= rs1_used_i ? rs1_data  : '0;          // Source register 1 data
            rvfi_rs2_rdata_o  <= rs2_used_i ? rs2_data  : '0;          // Source register 2 data
            rvfi_pc_rdata_o   <= rvfi_pc_rdata_i;                      // PC read data
            rvfi_pc_wdata_o   <= branch_o      ? 64'(target_addr_o) & `IALIGN_MASK : 
                                                 64'(rvfi_pc_wdata_i);  // PC write data (branch target)
        end
    end

`endif


endmodule


