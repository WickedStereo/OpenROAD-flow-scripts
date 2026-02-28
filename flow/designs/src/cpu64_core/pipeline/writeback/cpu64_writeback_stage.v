///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_writeback_stage                                                           //
// Description: Writeback stage writes results back to register file and handles
//              instruction retirement. Selects appropriate result source (ALU,
//              memory, CSR, PC+4) and processes load data with proper sign
//              extension and byte selection. This is the final stage of the pipeline
//              where all instruction results are written back to the register file
//              and instruction retirement is completed.
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_writeback_stage (
    //===================== Clock and Reset =====================//
    input                       clk_i,              // System clock
    input                       rst_ni,             // Active-low reset
    
    //===================== Pipeline Control ===================//
    input                       squash_i,           // Squash current instruction
    input                       bubble_i,           // Insert bubble (NOP)
    input                       stall_i,            // Stall pipeline

    //===================== Memory Pipeline Inputs =============//
    input                       valid_i,            // Instruction is valid
    //===================== Pipeline Metadata ==================//
    input       [`XLEN-1:0]     pc_i,               // Program counter
    //===================== Destination Register ===============//
    input       [`XLEN-1:0]     rd_data_i,          // Register write data
    input       [4:0]           rd_idx_i,           // Destination register index
    input                       rd_wr_en_i,         // Register write enable
    input                       rd_wr_src_load_i,   // Register write source is load result
    //===================== Data Memory Load Inputs ============//
    input                       dmem_rvalid_i,      // Data memory read valid
    input        [`XLEN-1:0]    dmem_rdata_i,       // Data memory read data
    input        [3:0]          mem_width_1h_i,     // Memory access width (one-hot)
    input                       mem_sign_i,         // Sign extend load data
    input        [2:0]          byte_addr_i,        // Byte address within word

    //===================== Register File Controls =============//
    output reg [`XLEN-1:0]      rd_data_ao,         // Register write data output
    output reg [4:0]            rd_idx_ao,          // Destination register index output
    output reg                  rd_wr_en_ao,        // Register write enable output

    //===================== Pipeline Outputs ===================//
    output wire                 inst_retired_ao,    // Instruction retired signal
    output wire                 valid_ao            // Output instruction valid

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
    input [`XLEN   - 1 : 0]      rvfi_mem_addr_i,    // Memory address
    input [`XLEN/8 - 1 : 0]      rvfi_mem_rmask_i,   // Memory read mask
    input [`XLEN/8 - 1 : 0]      rvfi_mem_wmask_i,   // Memory write mask
    input [`XLEN   - 1 : 0]      rvfi_mem_wdata_i,   // Memory write data

    output reg                   rvfi_valid_o,       // RVFI valid output
    output reg [  64 - 1 : 0]    rvfi_order_o,       // Instruction order
    output reg [  32 - 1 : 0]    rvfi_insn_o,        // Instruction word output
    output reg                   rvfi_trap_o,        // Trap indicator output
    output reg                   rvfi_halt_o,        // Halt indicator output
    output reg                   rvfi_intr_o,        // Interrupt indicator output
    output reg [2    - 1 : 0]    rvfi_mode_o,        // Privilege mode output
    output reg [2    - 1 : 0]    rvfi_ixl_o,         // Instruction length output
    output reg [   5 - 1 : 0]    rvfi_rs1_addr_o,    // Source register 1 address output
    output reg [   5 - 1 : 0]    rvfi_rs2_addr_o,    // Source register 2 address output
    output reg [`XLEN - 1 : 0]   rvfi_rs1_rdata_o,   // Source register 1 data output
    output reg [`XLEN - 1 : 0]   rvfi_rs2_rdata_o,   // Source register 2 data output
    output reg [   5 - 1 : 0]    rvfi_rd_addr_o,     // Destination register address output
    output reg [`XLEN - 1 : 0]   rvfi_rd_wdata_o,    // Destination register write data output
    output reg [`XLEN - 1 : 0]   rvfi_pc_rdata_o,    // Program counter (read) output
    output reg [`XLEN - 1 : 0]   rvfi_pc_wdata_o,    // Program counter (write) output
    output reg [`XLEN   - 1 : 0] rvfi_mem_addr_o,    // Memory address output
    output reg [`XLEN/8 - 1 : 0] rvfi_mem_rmask_o,   // Memory read mask output
    output reg [`XLEN/8 - 1 : 0] rvfi_mem_wmask_o,   // Memory write mask output
    output reg [`XLEN   - 1 : 0] rvfi_mem_rdata_o,   // Memory read data output
    output reg [`XLEN   - 1 : 0] rvfi_mem_wdata_o    // Memory write data output
`endif
);
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      Validity Tracker                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Track instruction validity through the writeback stage
    // Handles squash, bubble, and stall conditions with sticky flags

    wire valid;    // Valid instruction signal after validity tracking

    cpu64_validity_tracker WB_validity_tracker (
        .clk_i          (clk_i),        // System clock
        .rst_ni         (rst_ni),       // Active-low reset

        .valid_i        (valid_i),      // Input instruction valid
        
        .squash_i       (squash_i),     // Squash current instruction
        .bubble_i       (bubble_i),     // Insert bubble (NOP)
        .stall_i        (stall_i),      // Stall pipeline

        .valid_ao       (valid)         // Output instruction valid
    );

    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Byte Addressing Logic                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Process load data with proper byte selection and sign extension
    // Handles different memory access widths (byte, halfword, word, doubleword)
    // and applies correct sign extension based on instruction type

    //===================== Data Slicing Arrays =================//
    // Break down 64-bit memory data into bytes, halfwords, and words
    wire [7:0]      bytes [0:7];     // 8 bytes (0-7)
    wire [15:0]     halfs [0:3];     // 4 halfwords (0-3)
    wire [31:0]     words [0:1];     // 2 words (0-1)
    
    //===================== Load Data Processing ================//
    reg [`XLEN-1:0] load_data_sliced;  // Processed load data with sign extension
    reg             msb;                // Most significant bit for sign extension

    //===================== Data Array Assignment ===============//
    // Break down 64-bit memory data into smaller chunks for byte addressing
    assign { bytes[7], bytes[6], bytes[5], bytes[4], 
             bytes[3], bytes[2], bytes[1], bytes[0] } = dmem_rdata_i[63:0];
    assign { halfs[3], halfs[2], halfs[1], halfs[0] } = dmem_rdata_i[63:0];
    assign { words[1], words[0] }                     = dmem_rdata_i[63:0];

    //===================== Load Data Processing Logic ==========//
    // Select appropriate data slice and apply sign extension based on access width
    always @ (*) begin
        case (mem_width_1h_i)
            //===================== Byte Access (8-bit) =========//
            `MEM_WIDTH_1H_BYTE:   begin
                msb              = (mem_sign_i == `MEM_SIGNED) ? bytes[byte_addr_i][7] : 1'b0;
                load_data_sliced = { {56{msb}}, bytes[byte_addr_i]} ;  // Sign extend to 64 bits
            end
            
            //===================== Halfword Access (16-bit) ====//
            `MEM_WIDTH_1H_HALF:   begin
                msb              = (mem_sign_i == `MEM_SIGNED) ? halfs[byte_addr_i[2:1]][15] : 1'b0;
                load_data_sliced = { {48{msb}}, halfs[byte_addr_i[2:1]] };  // Sign extend to 64 bits
            end
            
            //===================== Word Access (32-bit) ========//
            `MEM_WIDTH_1H_WORD:   begin
                msb              = (mem_sign_i == `MEM_SIGNED) ? words[byte_addr_i[2]][31] : 1'b0;
                load_data_sliced = { {32{msb}}, words[byte_addr_i[2]] };  // Sign extend to 64 bits
            end
            
            //===================== Doubleword Access (64-bit) ==//
            `MEM_WIDTH_1H_DOUBLE: begin
                msb              = dmem_rdata_i[`XLEN-1];  // Use MSB of 64-bit data
                load_data_sliced = dmem_rdata_i;           // Use data as-is
            end
            
            //===================== Default/Invalid =============//
            default: begin
                msb              = 1'b0;                    // No sign extension
                load_data_sliced = 'b0;                     // Zero data
            end
        endcase
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  Register File Controls                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate register file write signals and instruction retirement signals
    // Select appropriate data source and ensure proper write enable conditions

    //===================== Pipeline Outputs ====================//
    // Generate instruction retirement and validity signals
    assign inst_retired_ao = valid && ~stall_i;                // Instruction retired: valid and not stalled
    
    // Register valid flag to align with registered rd_wr_en_ao
    reg       valid_reg;
    assign    valid_ao = valid_reg && rst_ni;                  // Output valid: registered and not reset

    //===================== Writeback Pipeline Registers =======//
    // Register file write signals  
    // Write enable pulses only ONCE per instruction, even if instruction stays in WB multiple cycles
    reg       already_written;
    reg [4:0] last_rd_idx;
    reg [`XLEN-1:0] last_rd_data;
    reg [`XLEN-1:0] last_pc;
    wire      instruction_changed;
    wire      should_write;
    
    // AMO/Load data latching to prevent corruption on instruction replay
    reg [`XLEN-1:0] latched_load_data;
    reg             load_data_latched;
    
    // Detect when a different instruction enters WB (PC or rd changes)
    assign instruction_changed = (pc_i != last_pc) || (rd_idx_i != last_rd_idx);
    
    // Latch load/AMO data on first rvalid to prevent corruption from replays
    wire use_latched_data = load_data_latched && !instruction_changed;
    wire [`XLEN-1:0] safe_load_data = use_latched_data ? latched_load_data : load_data_sliced;
    
    // Write when:
    // 1. Instruction is valid
    // 2. Has write enable from decode
    // 3. Not squashed or bubbled  
    // 4. Either hasn't written yet OR new instruction just arrived
    // 5. For loads/AMO: data must be valid (dmem_rvalid_i)
    wire data_ready = rd_wr_src_load_i ? dmem_rvalid_i : 1'b1;  // For loads/AMO, wait for rvalid; otherwise always ready
    assign should_write = rd_wr_en_i && ~bubble_i && ~squash_i && (~already_written || instruction_changed) && data_ready;
    
    always @(posedge clk_i) begin
        if (~rst_ni) begin
            rd_data_ao      <= '0;
            rd_idx_ao       <= '0;
            rd_wr_en_ao     <= 1'b0;
            already_written <= 1'b0;
            last_rd_idx     <= '0;
            last_rd_data    <= '0;
            last_pc         <= '0;
            valid_reg       <= 1'b0;
            latched_load_data <= '0;
            load_data_latched <= 1'b0;
        end else if (~stall_i) begin
            rd_data_ao  <= (rd_wr_src_load_i) ? safe_load_data : rd_data_i;
            rd_idx_ao   <= rd_idx_i;
            rd_wr_en_ao <= should_write;
            
            // Latch load/AMO data on first rvalid for this instruction
            if (rd_wr_src_load_i && dmem_rvalid_i && !load_data_latched) begin
                latched_load_data <= load_data_sliced;
                load_data_latched <= 1'b1;
            end
            
            // Clear latch when instruction changes
            if (instruction_changed) begin
                load_data_latched <= 1'b0;
            end
            
`ifdef VERILATOR
            if ((rd_idx_i != 0) && (rd_idx_i <= 11)) begin
                $display("[WB cyc] rd=x%0d should_write=%b rd_wr_en_i=%b bubble=%b squash=%b is_load=%b data=0x%016h", 
                         rd_idx_i, should_write, rd_wr_en_i, bubble_i, squash_i, rd_wr_src_load_i, 
                         (rd_wr_src_load_i ? safe_load_data : rd_data_i));
            end
`endif
            last_rd_idx <= rd_idx_i;
            last_rd_data <= rd_data_i;
            last_pc     <= pc_i;
            valid_reg   <= valid;
            
            // Set flag when we write, clear when instruction changes or valid goes low
            if (should_write) begin
                already_written <= 1'b1;
            end else if (instruction_changed || ~valid) begin
                already_written <= 1'b0;
            end
`ifdef CPU64_DBG_WB_DETAIL
            if (rd_idx_i == 5'd10) begin
                $display("[WB-x10] rd_wr_en_i=%b should_write=%b valid=%b bubble=%b squash=%b already_written=%b => rd_wr_en_ao=%b",
                         rd_wr_en_i, should_write, valid, bubble_i, squash_i, already_written, should_write);
            end
`endif
        end else begin
            // When stalled, clear write enable to prevent duplicate writes during stall
            rd_wr_en_ao   <= 1'b0;
            valid_reg     <= 1'b0;
        end
    end

`ifdef CPU64_DBG_TRACE
    //===================== Debug Trace ==========================//
    always @(posedge clk_i) begin
        if (rst_ni && ~stall_i && inst_retired_ao) begin
            $display("[WB ] rd=x%0d we=%0b data=0x%016h is_load=%0b mem_data=0x%016h byte_addr=0x%0h", 
                     rd_idx_i, rd_wr_en_ao, rd_data_ao, rd_wr_src_load_i, dmem_rdata_i, byte_addr_i);
        end
    end
`endif


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  RISC-V Formal Interface                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // RISC-V Formal Interface (RVFI) for formal verification and instruction tracing
    // Provides complete instruction execution trace information for verification

`ifdef CPU64_RVFI

    //===================== RVFI Valid Signal ===================//
    // RVFI valid when instruction is retired or trap occurs
    wire   rvfi_valid;
    assign rvfi_valid = (inst_retired_ao | rvfi_trap_i) && rst_ni && ~stall_i;

    //===================== Instruction Order Counter ===========//
    // Track instruction execution order for verification
    reg [63:0] rvfi_order = '0;
    always @(posedge clk_i) begin
        if (rvfi_valid)
            rvfi_order <= rvfi_order + 64'd1;  // Increment order counter
    end

    //===================== Interrupt Prediction ================//
    // Track interrupt prediction for RVFI
    reg rvfi_intr_predicted;
    always @(posedge clk_i) begin
        if (~rst_ni)
            rvfi_intr_predicted <= 1'b0;           // Reset: no interrupt predicted
        else if (rvfi_trap_i && ~stall_i)
            rvfi_intr_predicted <= 1'b1;           // Trap: predict interrupt
        else if (inst_retired_ao)
            rvfi_intr_predicted <= 1'b0;           // Instruction retired: clear prediction
    end

    //===================== RVFI Output Generation ==============//
    // Generate all RVFI output signals for formal verification
    always @(*) begin
        //===================== Basic Information ===============//
        rvfi_valid_o      = rvfi_valid;            // RVFI valid signal
        rvfi_order_o      = rvfi_order;            // Instruction order
        rvfi_insn_o       = rvfi_insn_i;           // Instruction word
        rvfi_trap_o       = rvfi_trap_i;           // Trap indicator
        rvfi_halt_o       = 1'b0;                  // Halt indicator (always false)
        rvfi_intr_o       = rvfi_intr_predicted;   // Interrupt prediction
        
        //===================== Architecture Information ========//
        rvfi_mode_o       = 2'd3;                  // Machine mode (M-mode)
        rvfi_ixl_o        = 2'd2;                  // 64-bit instruction length
        
        //===================== Register Information ============//
        rvfi_rs1_addr_o   = rvfi_rs1_addr_i;       // Source register 1 address
        rvfi_rs2_addr_o   = rvfi_rs2_addr_i;       // Source register 2 address
        rvfi_rs1_rdata_o  = rvfi_rs1_rdata_i;      // Source register 1 data
        rvfi_rs2_rdata_o  = rvfi_rs2_rdata_i;      // Source register 2 data
        rvfi_rd_addr_o    = rd_wr_en_ao ? rd_idx_ao  : '0;  // Destination register address
        rvfi_rd_wdata_o   = rd_wr_en_ao ? rd_data_ao : '0;  // Destination register write data
        
        //===================== Program Counter =================//
        rvfi_pc_rdata_o   = rvfi_pc_rdata_i;       // Program counter (read)
        rvfi_pc_wdata_o   = rvfi_pc_wdata_i;       // Program counter (write)
        
        //===================== Memory Information ==============//
        rvfi_mem_addr_o   = rvfi_mem_addr_i;       // Memory address
        rvfi_mem_rmask_o  = rvfi_mem_rmask_i;      // Memory read mask
        rvfi_mem_wmask_o  = rvfi_mem_wmask_i;      // Memory write mask
        rvfi_mem_rdata_o  = dmem_rdata_i;          // Memory read data
        rvfi_mem_wdata_o  = rvfi_mem_wdata_i;      // Memory write data
    end

`endif

endmodule

