///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_memory_stage                                                              //
// Description: Memory stage handles data memory access for load/store operations.
//              Manages address generation, byte enables, alignment checking,
//              and OBI protocol compliance. Processes load data and generates
//              memory exception signals. This stage is responsible for all
//              data memory transactions including load/store operations with
//              proper alignment checking and exception handling.
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_memory_stage #(parameter VADDR = 39) (
    //===================== Clock and Reset =====================//
    input                   clk_i,              // System clock
    input                   rst_ni,             // Active-low reset
    
    //===================== Pipeline Control ===================//
    input                   squash_i,           // Squash current instruction
    input                   bubble_i,           // Insert bubble (NOP)
    input                   stall_i,            // Stall pipeline

    //===================== Execute Stage Inputs ===============//
    input                   valid_i,            // Instruction is valid
    input [VADDR-1:0]       pc_i,               // Program counter
    input [VADDR-1:0]       dmem_full_addr_i,   // Full memory address (39-bit virtual address)
    input [`XLEN-1:0]       rs2_data_i,         // Source register 2 data (for stores)
    input [4:0]             rs2_idx_i,          // Source register 2 index (for forwarding)
    
    //===================== Destination Register ===============//
    input  [`XLEN-1:0]      rd_data_i,          // Register data to write back
    input  [4:0]            rd_idx_i,           // Destination register index
    input                   rd_wr_en_i,         // Register write enable
    input                   rd_wr_src_load_i,   // Register write source is load result
    
    //===================== Writeback Stage Forwarding =========//
    input                   WB_rd_wr_en_i,      // WB stage register write enable
    input                   WB_valid_i,         // WB stage instruction valid
    input  [4:0]            WB_rd_idx_i,        // WB stage destination register
    input  [`XLEN-1:0]      WB_rd_data_i,       // WB stage register data
    
    //===================== Load/Store Control =================//
    input  [3:0]            mem_width_1h_i,     // Memory access width (one-hot encoded)
    input                   mem_rd_i,           // Memory read enable
    input                   mem_wr_i,           // Memory write enable
    input                   mem_sign_i,         // Sign extend load data
    
    //===================== Atomic Operation Inputs ============//
    input                   is_amo_i,           // Is AMO instruction
    input                   is_lr_i,            // Is Load-Reserved instruction
    input                   is_sc_i,            // Is Store-Conditional instruction
    input  [4:0]            amo_op_i,           // AMO operation type
    input                   amo_word_i,         // AMO word operation flag

    //===================== Data Memory Interface ==============//
    output wire             dmem_req_o,         // Memory request signal
    input                   dmem_gnt_i,         // Memory grant signal
    output wire [VADDR-1:0] dmem_addr_ao,       // Memory address (word-aligned)
    output wire             dmem_we_ao,         // Memory write enable
    output wire  [7:0]      dmem_be_ao,         // Memory byte enable
    output wire [`XLEN-1:0] dmem_wdata_ao,      // Memory write data
    input                   dmem_rvalid_i,      // Memory read valid
    // Atomic operation signals
    output wire             dmem_amo_ao,        // Atomic memory operation
    output wire             dmem_lr_ao,         // Load-Reserved operation
    output wire             dmem_sc_ao,         // Store-Conditional operation
    output wire  [4:0]      dmem_amo_op_ao,     // AMO operation type
    output wire             dmem_amo_word_ao,   // AMO word operation flag

    //===================== Memory Control Outputs =============//
    output wire             dmem_stall_ao,      // Memory stall required
    output wire             unalign_store_ex_ao, // Unaligned store exception
    output wire             unalign_load_ex_ao,  // Unaligned load exception

    //===================== Pipeline Outputs ===================//
    output reg              valid_o,            // Output instruction valid
    output reg [VADDR-1:0]  pc_o,               // Program counter output
    //===================== Destination Register ===============//
    output reg [`XLEN-1:0]  rd_data_o,          // Register data to write back
    output reg [4:0]        rd_idx_o,           // Destination register index
    output reg              rd_wr_en_o,         // Register write enable
    output reg              rd_wr_src_load_o,   // Register write source is load result
    //===================== Load/Store Control =================//
    output reg [3:0]        mem_width_1h_o,     // Memory access width
    output reg              mem_sign_o,         // Sign extend load data
    output reg [2:0]        byte_addr_o         // Byte address within word

`ifdef CPU64_RVFI
    //===================== RISC-V Formal Interface =============//
    // RVFI signals for formal verification and instruction tracing
    ,
    input [  32 - 1 : 0]         rvfi_insn_i,        // Instruction word
    input                        rvfi_trap_i,        // Trap indicator
    input [   5 - 1 : 0]         rvfi_rs1_addr_i,    // Source register 1 address
    input [   5 - 1 : 0]         rvfi_rs2_addr_i,    // Source register 2 address
    input [`XLEN - 1 : 0]        rvfi_rs1_rdata_i,   // Source register 1 data
    input [`XLEN - 1 : 0]        rvfi_rs2_rdata_i,   // Source register 2 data
    input [`XLEN - 1 : 0]        rvfi_pc_rdata_i,    // Program counter (read)
    input [`XLEN - 1 : 0]        rvfi_pc_wdata_i,    // Program counter (write)

    output reg [  32 - 1 : 0]    rvfi_insn_o,        // Instruction word output
    output reg                   rvfi_trap_o,        // Trap indicator output
    output reg [   5 - 1 : 0]    rvfi_rs1_addr_o,    // Source register 1 address output
    output reg [   5 - 1 : 0]    rvfi_rs2_addr_o,    // Source register 2 address output
    output reg [`XLEN - 1 : 0]   rvfi_rs1_rdata_o,   // Source register 1 data output
    output reg [`XLEN - 1 : 0]   rvfi_rs2_rdata_o,   // Source register 2 data output
    output reg [`XLEN - 1 : 0]   rvfi_pc_rdata_o,    // Program counter (read) output
    output reg [`XLEN - 1 : 0]   rvfi_pc_wdata_o,    // Program counter (write) output
    output reg [`XLEN   - 1 : 0] rvfi_mem_addr_o,    // Memory address output
    output reg [`XLEN/8 - 1 : 0] rvfi_mem_rmask_o,   // Memory read mask output
    output reg [`XLEN/8 - 1 : 0] rvfi_mem_wmask_o,   // Memory write mask output
    output reg [`XLEN   - 1 : 0] rvfi_mem_wdata_o    // Memory write data output
`endif
);
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Validity Tracking                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Track instruction validity through the memory stage
    // Handles squash, bubble, and stall conditions with sticky flags

    wire valid;    // Valid instruction signal after validity tracking

    cpu64_validity_tracker MEM_validity_tracker (
        .clk_i          (clk_i),        // System clock
        .rst_ni         (rst_ni),       // Active-low reset

        .valid_i        (valid_i),      // Input instruction valid
        
        .squash_i       (squash_i),     // Squash current instruction
        .bubble_i       (bubble_i),     // Insert bubble (NOP)
        .stall_i        (stall_i),      // Stall pipeline

        .valid_ao       (valid)         // Output instruction valid
    );

    // Atomic Request Tracker - prevent sending multiple requests for same AMO/LR/SC
    // Set when atomic first appears, clear when different instruction arrives (instruction actually leaves)
    wire is_atomic_op = is_amo_i || is_lr_i || is_sc_i;  // Any atomic operation
    reg atomic_active;
    reg [VADDR-1:0] atomic_active_pc;
    wire same_atomic = (pc_i == atomic_active_pc);  // Same instruction
    
    always @(posedge clk_i) begin
        if (~rst_ni) begin
            atomic_active <= 1'b0;
            atomic_active_pc <= '0;
        end else if (is_atomic_op && valid_i && ~atomic_active) begin
            // Mark atomic as active on first cycle it appears
            atomic_active <= 1'b1;
            atomic_active_pc <= pc_i;
        end else if (atomic_active && valid_i && ~same_atomic) begin
            // Clear when a DIFFERENT instruction appears (previous atomic has left)
            atomic_active <= 1'b0;
            atomic_active_pc <= '0;
        end
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                          Store Request Tracker (In-Order Enforcement)                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Track when a store has been accepted to prevent repeated writes for the same instruction.
    // Also enforce in-order semantics: memory ops should only proceed when WB stage is clear,
    // ensuring all previous instructions have written back to the register file first.
    
    reg store_accepted_q;           // Store has been accepted for current instruction
    reg [VADDR-1:0] store_pc_q;     // PC of the accepted store
    wire same_store = (pc_i == store_pc_q);  // Same store instruction
    
    // In-order check: WB stage must be clear (no pending writeback) before ANY memory op can proceed
    // This ensures the previous instruction's register writeback happens before the memory operation
    wire wb_pending = WB_valid_i && WB_rd_wr_en_i;  // WB has a pending register write
    wire mem_can_proceed = ~wb_pending;             // Memory ops can proceed when WB is clear
    
    // Store is blocked if: already accepted for this PC, OR WB has pending writeback
    wire store_blocked = (store_accepted_q && same_store) || ~mem_can_proceed;
    
    always @(posedge clk_i) begin
        if (~rst_ni) begin
            store_accepted_q <= 1'b0;
            store_pc_q <= '0;
        end else if (mem_wr_i && valid_i && dmem_gnt_i && ~store_blocked && ~illegal_addr) begin
            // Mark store as accepted when it gets granted
            store_accepted_q <= 1'b1;
            store_pc_q <= pc_i;
        end else if (store_accepted_q && valid_i && ~same_store) begin
            // Clear when a DIFFERENT instruction appears (previous store has left MEM stage)
            store_accepted_q <= 1'b0;
            store_pc_q <= '0;
        end
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                          Load Request Tracker (In-Order Enforcement)                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Track when a load has been accepted to prevent repeated reads for the same instruction.
    // Loads must also wait for WB to complete to maintain in-order semantics.
    
    reg load_accepted_q;            // Load has been accepted for current instruction
    reg [VADDR-1:0] load_pc_q;      // PC of the accepted load
    wire same_load = (pc_i == load_pc_q);  // Same load instruction
    
    // Load is blocked if: already accepted for this PC, OR WB has pending writeback
    wire load_blocked = (load_accepted_q && same_load) || ~mem_can_proceed;
    
    always @(posedge clk_i) begin
        if (~rst_ni) begin
            load_accepted_q <= 1'b0;
            load_pc_q <= '0;
        end else if (mem_rd_i && ~is_atomic_op && valid_i && dmem_gnt_i && ~load_blocked && ~illegal_addr) begin
            // Mark load as accepted when it gets granted (exclude atomics - they have own tracker)
            load_accepted_q <= 1'b1;
            load_pc_q <= pc_i;
        end else if (load_accepted_q && valid_i && ~same_load) begin
            // Clear when a DIFFERENT instruction appears (previous load has left MEM stage)
            load_accepted_q <= 1'b0;
            load_pc_q <= '0;
        end
    end

    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              RS2 Data Forwarding Logic                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Forward writeback stage data to rs2 for AMO and store operations
    // This handles the case where an instruction writes to a register and the next
    // instruction (now in MEM stage) uses that register as rs2 operand

    //===================== Forwarding Detection ================//
    wire wb_rs2_conflict = (rs2_idx_i == WB_rd_idx_i);      // Register indices match
    wire wb_rs2_forward  = wb_rs2_conflict && WB_rd_wr_en_i && WB_valid_i;  // Valid forwarding condition
    
    //===================== Forwarded RS2 Data ==================//
    wire [`XLEN-1:0] rs2_data_forwarded = wb_rs2_forward ? WB_rd_data_i : rs2_data_i;


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Byte Addressing Logic                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate byte enables, write data, and alignment checking for different memory access widths
    // Supports byte (8-bit), halfword (16-bit), word (32-bit), and doubleword (64-bit) accesses

    //===================== Address and Data Signals ============//
    wire [VADDR-1:0] dmem_word_addr;    // Word-aligned memory address
    reg  [`XLEN-1:0] dmem_wdata_a;      // Write data (replicated for different widths)
    reg              illegal_addr;      // Address alignment violation
    reg  [7:0]       byte_strobe;       // Byte enable strobe (8 bits for 8 bytes)
    wire [2:0]       byte_addr = dmem_full_addr_i[2:0];  // Byte address within word (0-7)
    wire             exception;         // Memory exception signal

    //===================== Memory Access Width Decoder =========//
    // Generate byte enables, write data, and alignment checking based on access width
    always @ (*) begin : dmem_strobe_gen
        case (mem_width_1h_i)
            //===================== Byte Access (8-bit) =========//
            `MEM_WIDTH_1H_BYTE: begin
                illegal_addr      = 1'b0;                              // Byte access is always aligned
                dmem_wdata_a      = { 8{rs2_data_forwarded[7:0]} };    // Replicate byte 8 times
                byte_strobe       = (8'b0000_0001 << byte_addr);       // Single byte enable
            end
            
            //===================== Halfword Access (16-bit) ====//
            `MEM_WIDTH_1H_HALF: begin 
                illegal_addr      = (byte_addr[0] == 1'b1);            // Must be 2-byte aligned
                dmem_wdata_a      = { 4{rs2_data_forwarded[15:0]} };   // Replicate halfword 4 times
                byte_strobe       = (illegal_addr) ? 8'b0 : (8'b0000_0011 << byte_addr);  // 2-byte enable
            end
            
            //===================== Word Access (32-bit) ========//
            `MEM_WIDTH_1H_WORD: begin 
                illegal_addr      = !((byte_addr == 3'b100) || (byte_addr == 3'b000));  // Must be 4-byte aligned
                dmem_wdata_a      = { 2{rs2_data_forwarded[31:0]} };   // Replicate word 2 times
                byte_strobe       = (illegal_addr) ? 8'b0 : (8'b0000_1111 << byte_addr);  // 4-byte enable
            end
            
            //===================== Doubleword Access (64-bit) ==//
            `MEM_WIDTH_1H_DOUBLE: begin 
                illegal_addr      = (byte_addr != 3'b0);               // Must be 8-byte aligned
                dmem_wdata_a      = rs2_data_forwarded;                // Use data as-is
                byte_strobe       = (illegal_addr) ? 8'b0 : 8'b1111_1111;  // All 8 bytes
            end
            
            //===================== Default/Invalid =============//
            default: begin
                illegal_addr      = 1'b1;                              // Invalid width
                dmem_wdata_a      = rs2_data_forwarded;                // Use data as-is
                byte_strobe       = 8'b0;                              // No bytes enabled
            end
        endcase
    end
    
    //===================== Word Address Generation =============//
    // Convert byte address to word address by clearing lower 3 bits
    assign dmem_word_addr = {dmem_full_addr_i[VADDR-1:3], 3'b0};


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 Host Memory Request Driver                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Interface with data memory using Open Bus Interface (OBI) protocol
    // Handles memory requests, grants, and data transfer with proper timing

    //===================== Memory Access Control ===============//
    // Atomic instructions (AMO/LR/SC) need special handling:
    // - AMO: Read-Modify-Write, returns old value
    // - LR: Load with reservation set, returns loaded value
    // - SC: Conditional store, returns 0 (success) or 1 (failure)
    // Only send atomic request if: 1) atomic is not yet active, OR 2) this is a different atomic (different PC)
    // AND WB must be clear (in-order enforcement)
    wire atomic_can_request = (~atomic_active | ~same_atomic) & mem_can_proceed;
    
    // Load request: only allow if not blocked (not already accepted AND WB is clear)
    // Atomics use their own tracker, regular loads use load_blocked
    wire mem_read  = is_atomic_op ? (atomic_can_request & valid_i) : (mem_rd_i & valid_i & ~load_blocked);
    
    // Store request: only allow if not blocked (not already accepted AND WB is clear)
    wire mem_write = mem_wr_i & valid_i & ~store_blocked;    // Valid memory write request with in-order enforcement

    //===================== OBI Host Driver Instantiation =======//
    // Open Bus Interface host driver for data memory transactions
    wire obi_stall;  // Internal stall from OBI driver
    
    cpu64_obi_host_driver #(.DATA_W(`XLEN), .ADDR_W(VADDR)) dmem_obi_host_driver 
    (
        .clk_i    (clk_i),                  // System clock
        .rst_ni   (rst_ni),                 // Active-low reset

        .gnt_i    (dmem_gnt_i),             // Memory grant signal
        .rvalid_i (dmem_rvalid_i),          // Memory read valid signal

        .stall_i  (stall_i),                // Pipeline stall signal

        .be_i     (byte_strobe),            // Byte enable strobe
        .addr_i   (dmem_word_addr),         // Word-aligned memory address
        .wdata_i  (dmem_wdata_a),           // Write data
        .rd_i     (mem_read  && ~illegal_addr),  // Read request (only if aligned)
        .wr_i     (mem_write && ~illegal_addr),  // Write request (only if aligned)

        .stall_ao (obi_stall),              // OBI stall output

        .req_o    (dmem_req_o),             // Memory request signal
        .we_ao    (dmem_we_ao),             // Memory write enable
        .be_ao    (dmem_be_ao),             // Memory byte enable
        .addr_ao  (dmem_addr_ao),           // Memory address
        .wdata_ao (dmem_wdata_ao)           // Memory write data
    );
    
    // Combined stall: OBI stall OR any memory operation waiting for WB to complete
    // Memory ops waiting for WB should stall the pipeline until WB is clear
    // Only stall if: 1) there's a pending memory op, 2) WB is busy, 3) the op hasn't been accepted yet
    wire store_wait_stall = mem_wr_i && valid_i && ~mem_can_proceed && ~(store_accepted_q && same_store);
    wire load_wait_stall  = mem_rd_i && ~is_atomic_op && valid_i && ~mem_can_proceed && ~(load_accepted_q && same_load);
    wire atomic_wait_stall = is_atomic_op && valid_i && ~mem_can_proceed && ~atomic_active;
    assign dmem_stall_ao = obi_stall || store_wait_stall || load_wait_stall || atomic_wait_stall;

`ifdef CPU64_DBG_TRACE
    //===================== Debug Trace ==========================//
    always @(posedge clk_i) begin
        if (rst_ni && ~stall_i && valid_o) begin
            $display("[MEM] addr=0x%0h mem_rd=%0b mem_wr=%0b be=0x%02h wdata=0x%016h rvalid=%0b stall=%0b exc=%0b", 
                     dmem_full_addr_i, mem_rd_i, mem_wr_i, dmem_be_ao, dmem_wdata_ao, dmem_rvalid_i, dmem_stall_ao, (unalign_store_ex_ao | unalign_load_ex_ao));
        end
        // AMO Debug
        if (rst_ni && is_amo_i && valid_i) begin
            $display("[MEM-AMO] PC=0x%h is_amo=%b valid=%b mem_rd=%b mem_width=%b(hex=%h) illegal_addr=%b mem_read=%b req=%b byte_addr=%b full_addr=0x%h amo_active=%b same_amo=%b amo_can_req=%b rvalid=%b", 
                     pc_i, is_amo_i, valid_i, mem_rd_i, mem_width_1h_i, mem_width_1h_i, illegal_addr, mem_read, dmem_req_o, byte_addr, dmem_full_addr_i, amo_active, same_amo, amo_can_request, dmem_rvalid_i);
        end
    end
`endif

    //===================== Exception Signal Generation =========//
    // Generate memory exception signals for unaligned accesses
    assign unalign_store_ex_ao = illegal_addr && mem_write;  // Unaligned store exception
    assign unalign_load_ex_ao  = illegal_addr && mem_read;   // Unaligned load exception
    assign exception           = illegal_addr && (mem_rd_i || mem_wr_i);  // General memory exception

    //===================== Atomic Operation Outputs ============//
    // Pass atomic operation signals to memory interface
    assign dmem_amo_ao      = is_amo_i & valid_i;   // Atomic operation active (excludes LR/SC)
    assign dmem_lr_ao       = is_lr_i & valid_i;    // Load-Reserved operation active
    assign dmem_sc_ao       = is_sc_i & valid_i;    // Store-Conditional operation active
    assign dmem_amo_op_ao   = amo_op_i;             // Atomic operation type
    assign dmem_amo_word_ao = amo_word_i;           // Atomic word operation flag


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Pipeline Registers                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Pipeline registers for the memory stage
    // Pass through data from execute stage to writeback stage with proper stall handling

    //===================== Validity Register ===================//
    // Track instruction validity through the memory stage
    always @(posedge clk_i) begin
        if (~rst_ni)
            valid_o <= 1'b0;                     // Reset: invalid instruction
        else if (~stall_i)
            valid_o <= valid && (~exception);    // Normal: valid if no exception (use processed validity from tracker)
    end

    //===================== Pipeline Data Registers =============//
    // Pass through execute stage data to writeback stage
    always @(posedge clk_i) begin
        if (~rst_ni) begin
            pc_o             <= '0;              // Reset: clear PC
            rd_data_o        <= '0;              // Reset: clear register write data
            rd_idx_o         <= '0;              // Reset: clear register index
            rd_wr_en_o       <= 1'b0;            // Reset: clear register write enable
            rd_wr_src_load_o <= 1'b0;            // Reset: clear write source load
            mem_width_1h_o   <= '0;              // Reset: clear memory access width
            mem_sign_o       <= 1'b0;            // Reset: clear sign extend flag
            byte_addr_o      <= '0;              // Reset: clear byte address
        end else if (~stall_i) begin
            pc_o             <= pc_i;             // Program counter
            rd_data_o        <= rd_data_i;        // Register write data
            rd_idx_o         <= rd_idx_i;         // Register index
            rd_wr_en_o       <= rd_wr_en_i && valid && ~bubble_i && ~squash_i;  // Register write enable (gated by validity and control signals)
            rd_wr_src_load_o <= rd_wr_src_load_i; // Write source is load
            mem_width_1h_o   <= mem_width_1h_i;   // Memory access width
            mem_sign_o       <= mem_sign_i;       // Sign extend flag
            byte_addr_o      <= dmem_full_addr_i[2:0];  // Byte address
        end
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  RISC-V Formal Interface                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // RISC-V Formal Interface (RVFI) for formal verification and instruction tracing
    // Provides complete instruction execution trace information

`ifdef CPU64_RVFI

    //===================== RVFI Trap Signal ====================//
    // Track trap conditions including memory exceptions
    always @(posedge clk_i) begin
        if (~rst_ni)
            rvfi_trap_o       <= '0;                           // Reset: no trap
        else if (squash_i || bubble_i)
            rvfi_trap_o       <= '0;                           // Squash/bubble: no trap
        else if (~stall_i)
            rvfi_trap_o       <= rvfi_trap_i | (exception && valid);    // Trap if input trap or memory exception (use processed validity from tracker)
    end

    //===================== RVFI Data Registers =================//
    // Pass through RVFI signals with memory-specific additions
    always @(posedge clk_i) begin
        if (~stall_i) begin
            //===================== Instruction Information ======//
            rvfi_insn_o       <= rvfi_insn_i;                  // Instruction word
            rvfi_rs1_addr_o   <= rvfi_rs1_addr_i;              // Source register 1 address
            rvfi_rs2_addr_o   <= rvfi_rs2_addr_i;              // Source register 2 address
            rvfi_rs1_rdata_o  <= rvfi_rs1_rdata_i;             // Source register 1 data
            rvfi_rs2_rdata_o  <= rvfi_rs2_rdata_i;             // Source register 2 data
            rvfi_pc_rdata_o   <= rvfi_pc_rdata_i;              // Program counter (read)
            rvfi_pc_wdata_o   <= rvfi_pc_wdata_i;              // Program counter (write)
            
            //===================== Memory Information ===========//
            rvfi_mem_addr_o   <= 64'(dmem_word_addr);          // Memory address (64-bit)
            rvfi_mem_rmask_o  <= dmem_we_ao ? '0            : byte_strobe;  // Read mask
            rvfi_mem_wmask_o  <= dmem_we_ao ? byte_strobe : '0;             // Write mask
            rvfi_mem_wdata_o  <= dmem_wdata_ao;                // Write data
        end
    end

`endif


endmodule
