///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// File Name  : cpu64_csr.v                                                                     //
// Description: Control and Status Registers (CSR) module implementing machine-mode
//              CSRs and interrupt controller. Manages system state, exceptions,
//              interrupts, and performance counters. Provides trap handling
//              and privilege mode management for the CPU64 core.
//              Implements RISC-V Machine Mode CSRs as per Privileged Architecture v1.12.        //
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_csr_defs.vh"
`include "cpu64_defs.vh"


module cpu64_csr #(parameter VADDR = 39) (
    //===================== Clock and Reset =====================//
    input                   clk_i,              // System clock
    input                   rst_ni,             // Active-low reset

    //===================== CSR Read Interface =================//
    input                   rd_en_i,            // CSR read enable
    input      [11:0]       rd_addr_i,          // CSR read address (12-bit)
    output reg [`XLEN-1:0]  rdata_o,            // CSR read data (64-bit)
    output                  csr_rd_ex_ao,       // CSR read exception

    //===================== CSR Write Interface ================//
    input                   wr_en_i,            // CSR write enable
    input      [11:0]       wr_addr_i,          // CSR write address (12-bit)
    input      [`XLEN-1:0]  wdata_i,            // CSR write data (64-bit)
    output                  csr_wr_ex_ao,       // CSR write exception

    //===================== Exception Inputs ===================//
    input                   unalign_load_ex_i,  // Load address misaligned exception
    input                   unalign_store_ex_i, // Store address misaligned exception
    input                   ecall_ex_i,         // ECALL exception
    input                   ebreak_ex_i,        // EBREAK exception
    input                   illegal_inst_ex_i,  // Illegal instruction exception

    //===================== Interrupt Inputs ===================//
    input                   m_ext_inter_i,      // Machine external interrupt
    input                   m_soft_inter_i,     // Machine software interrupt
    input                   m_timer_inter_i,    // Machine timer interrupt

    //===================== Program Counter Inputs =============//
    input [VADDR-1:0]       EXE_exc_pc_i,       // EXE stage PC for exceptions
    input [VADDR-1:0]       MEM_exc_pc_i,       // MEM stage PC for exceptions
    input [VADDR-1:0]       load_store_bad_addr, // Bad address for load/store exceptions

    //===================== Control Inputs =====================//
    input                   mret_i,             // MRET instruction (trap return)
    input                   instr_retired_i,    // Instruction retired signal
    input      [`XLEN-1:0]  time_i,             // External time counter

    //===================== Control Outputs ====================//
    output wire             csr_interrupt_ao,   // CSR interrupt taken signal
    output reg  [VADDR-1:0] csr_branch_addr_o,  // CSR branch target address
    output wire [VADDR-1:0] trap_ret_addr_o     // Trap return address (mepc)
);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                __  __            _     _               ____ ____  ____                    //
    //               |  \/  | __ _  ___| |__ (_)_ __   ___   / ___/ ___||  _ \ ___               //
    //               | |\/| |/ _` |/ __| '_ \| | '_ \ / _ \ | |   \___ \| |_) / __|              //
    //               | |  | | (_| | (__| | | | | | | |  __/ | |___ ___) |  _ <\__ \              //
    //               |_|  |_|\__,_|\___|_| |_|_|_| |_|\___|  \____|____/|_| \_\___/              //
    //                                                                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    //===================== Privilege Mode State =================//
    reg [1:0] privilege_mode;    // Current privilege mode (MACHINE_MODE only)

    //===================== Register Write Controls ==============//
    // Write enable signals for each CSR register
    reg wr_mstatus,   wr_misa,       wr_mie,        wr_mtvec,     wr_mcountinhibit,  wr_mscratch, 
        wr_mepc,      wr_mcause,     wr_mtval,      wr_mip,       wr_mtval2,         wr_mcycle,
        wr_minstret,  wr_mcounteren;

    //===================== Interrupt Control Signals ============//
    // Interrupt enable, detection, and handling signals
    wire M_inter_en;              // Machine interrupt enable (global)
    wire M_ext_inter;             // Machine external interrupt active
    wire M_timer_inter;           // Machine timer interrupt active
    wire M_soft_inter;            // Machine software interrupt active
    wire M_interrupt_a;           // Any machine interrupt active
    wire M_intr_taken_a;          // Interrupt or exception taken (async)
    wire M_exception_a;           // Exception active
    reg  M_intr_taken_r;          // Interrupt taken (registered)   

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                Machine ISA Register (misa)                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine ISA register: Reports supported ISA extensions and XLEN
    // Format: [63:62] = MXL (XLEN encoding), [25:0] = Extensions (A-Z)

    reg  [25:0] extensions;    // Supported ISA extensions (writable portion)

    //===================== MISA Register Logic ==================//
    // Update extensions field on write, maintain supported extensions only
    always @(posedge clk_i) begin : misa_logic
        if (~rst_ni)
            extensions <= `MISA_SUPPORTED;        // Reset to supported extensions
        else if (wr_misa)
            extensions <= wdata_i[25:0];          // Write new extensions (masked by supported)
    end

    //===================== MISA Read Data =======================//
    // Format: [63:62] = MXL (XLEN=64), [61:36] = Reserved, [25:0] = Extensions
    wire [`XLEN-1:0] misa_rdata = { `MXLEN, 36'b0, (extensions & `MISA_SUPPORTED) };


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                             Machine Status Register (mstatus)                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Status register: Global interrupt enable, privilege mode, and system state
    // Controls interrupt enable, privilege mode transitions, and system configuration

    //===================== MSTATUS Field Declarations ===========//
    // Machine Mode Fields
    reg       MIE;             // Machine Interrupt Enable (global)
    reg       MPIE;            // Machine Previous Interrupt Enable
    reg [1:0] MPP;             // Machine Previous Privilege Mode
    reg       MPRV;            // Modify PRiVilege (memory access control)
    
    // Supervisor Mode Fields (not fully implemented)
    reg       TSR;             // Trap SRET (supervisor mode)
    reg       TW;              // Timeout Wait (supervisor mode)
    reg       TVM;             // Trap Virtual Memory (supervisor mode)
    reg       MXR;             // Make eXecutable Readable (supervisor mode)
    reg       SUM;             // Supervisor User Memory access (supervisor mode)
    reg       SIE;             // Supervisor Interrupt Enable
    reg       SPP;             // Supervisor Previous Privilege Mode
    reg       SPIE;            // Supervisor Previous Interrupt Enable

    //===================== Unsupported Feature Fields ===========//
    // These fields are hardwired to fixed values (read-only)
    wire       MBE = `MSTATUS_LITTLE_ENDIAN;   // Machine byte endianness (little-endian)
    wire       SBE = MBE;                      // Supervisor byte endianness (same as machine)
    wire       UBE = MBE;                      // User byte endianness (same as machine)
    wire [1:0] SXL = `MXLEN;                   // Supervisor Mode XLEN (64-bit)
    wire [1:0] UXL = `MXLEN;                   // User Mode XLEN (64-bit)
    wire [1:0] FS  = 'b0;                      // Floating point unit state (off)
    wire [1:0] VS  = 'b0;                      // Vector unit state (off)
    wire [1:0] XS  = 'b0;                      // User Mode extension state (off)
    wire       SD  = 'b0;                      // Extension state dirty (clean) 

    //===================== MSTATUS Register Logic ===============//
    // Update MSTATUS fields on write or MRET instruction
    always @(posedge clk_i) begin : mstatus_logic
        if (~rst_ni) begin
            //===================== Reset State ===================//
            // Machine Mode Fields
            privilege_mode  <= `MACHINE_MODE;   // Start in machine mode
            MPP             <= `MACHINE_MODE;   // Previous privilege mode
            MPRV            <= 'b0;             // No privilege modification
            MIE             <= 'b0;             // Interrupts disabled
            MPIE            <= 'b0;             // Previous interrupt state
            
            // Supervisor Mode Fields (not fully implemented)
            TW              <= 'b0;             // No timeout wait
            TSR             <= 'b0;             // No SRET trap
            TVM             <= 'b0;             // No virtual memory trap
            MXR             <= 'b0;             // No executable readable
            SUM             <= 'b0;             // No supervisor user memory
            SIE             <= 'b0;             // Supervisor interrupts disabled
            SPP             <= 'b0;             // Supervisor previous privilege
            SPIE            <= 'b0;             // Supervisor previous interrupt
        end else if (wr_mstatus) begin
            //===================== CSR Write =====================//
            // Update writable MSTATUS fields from write data
            MIE             <= wdata_i[3];      // Machine Interrupt Enable
            MPIE            <= wdata_i[7];      // Machine Previous Interrupt Enable
            MPP             <= wdata_i[12:11];  // Machine Previous Privilege
            MPRV            <= wdata_i[17];     // Modify Privilege
        end else if (mret_i) begin
            //===================== MRET Instruction ==============//
            // Restore previous privilege mode and interrupt state
            privilege_mode  <= MPP;             // Restore previous privilege mode
            MIE             <= MPIE;            // Restore previous interrupt enable
            MPIE            <= 'b1;             // Set previous interrupt enable
            MPRV            <= (MPP == `MACHINE_MODE) ? MPRV : 'b0;  // Clear MPRV if not machine mode
            MPP             <= `LOWEST_PRIVILEGE;  // Clear previous privilege mode
        end
    end

    //===================== MSTATUS Read Data ====================//
    // Format MSTATUS register according to RISC-V specification
    // [63] = SD, [62:38] = Reserved, [37] = MBE, [36] = SBE, [35:34] = SXL, [33:32] = UXL
    // [31:23] = Reserved, [22] = TSR, [21] = TW, [20] = TVM, [19] = MXR, [18] = SUM
    // [17] = MPRV, [16:15] = XS, [14:13] = FS, [12:11] = MPP, [10:9] = VS, [8] = SPP
    // [7] = MPIE, [6] = UBE, [5] = SPIE, [4] = Reserved, [3] = MIE, [2] = Reserved, [1] = SIE, [0] = Reserved
    wire [`XLEN-1:0] mstatus_rdata = { SD,   25'b0, MBE,  SBE,  SXL, UXL, 9'b0, TSR, TW,   TVM, 
                                     MXR,  SUM,   MPRV, XS,   FS,  MPP, VS,   SPP, MPIE, UBE, 
                                     SPIE, 1'b0,  MIE,  1'b0, SIE, 1'b0 };


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                     Machine Trap-Vector Base-Address Register (mtvec)                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Trap Vector: Base address for trap handlers and trap mode configuration
    // Controls where the processor jumps when an exception or interrupt occurs

    reg  [1:0]  mtvec_mode;      // Trap vector mode (direct or vectored)
    reg  [VADDR-1:2] mtvec_base; // Trap vector base address (aligned to 4-byte boundary)

    //===================== MTVEC Register Logic =================//
    // Update trap vector base address and mode on write
    always @(posedge clk_i) begin : mtvec_logic
        if (~rst_ni)
            { mtvec_base, mtvec_mode } <= 'b0;        // Reset: no trap vector
        else if (wr_mtvec)
            { mtvec_base, mtvec_mode } <= wdata_i[VADDR-1:0];  // Write new base and mode
    end

    //===================== MTVEC Read Data =======================//
    // Format: [63:VADDR] = Reserved, [VADDR-1:2] = Base address, [1:0] = Mode
    wire [`XLEN-1:0] mtvec_rdata = { {`XLEN-VADDR{1'b0}}, mtvec_base, mtvec_mode };


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                               Machine Interrupt Enable (mie)                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Interrupt Enable: Controls which interrupts are enabled
    // Individual interrupt enable bits for external, timer, and software interrupts

    reg mie_MEIE;    // Machine External Interrupt Enable
    reg mie_MTIE;    // Machine Timer Interrupt Enable  
    reg mie_MSIE;    // Machine Software Interrupt Enable

    //===================== MIE Register Logic ===================//
    // Update interrupt enable bits on write
    always @(posedge clk_i) begin : mie_logic
        if (~rst_ni) begin
            mie_MEIE <= 'b0;    // Reset: all interrupts disabled
            mie_MTIE <= 'b0;
            mie_MSIE <= 'b0;
        end else if (wr_mie) begin
            mie_MEIE <= wdata_i[11];  // External interrupt enable
            mie_MTIE <= wdata_i[7];   // Timer interrupt enable
            mie_MSIE <= wdata_i[5];   // Software interrupt enable
        end 
    end

    //===================== MIE Read Data ========================//
    // Format: [63:12] = Reserved, [11] = MEIE, [10:8] = Reserved, [7] = MTIE, [6:4] = Reserved, [3] = MSIE, [2:0] = Reserved
    wire [`XLEN-1:0] mie_rdata = {52'b0, mie_MEIE, 3'b0, mie_MTIE, 3'b0, mie_MSIE, 3'b0};


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              Machine Interrupt Pending (mip)                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Interrupt Pending: Shows which interrupts are currently pending
    // Combines external interrupt sources with enable bits to determine active interrupts

    reg mip_MEIP;    // Machine External Interrupt Pending
    reg mip_MTIP;    // Machine Timer Interrupt Pending
    reg mip_MSIP;    // Machine Software Interrupt Pending

    //===================== MIP Register Logic ===================//
    // Update interrupt pending bits based on external sources and enable bits
    always @(posedge clk_i) begin : mip_logic
        if (~rst_ni || M_intr_taken_r) begin
            // Reset or interrupt taken: clear all pending interrupts
            mip_MEIP <= 'b0;
            mip_MTIP <= 'b0;
            mip_MSIP <= 'b0;
        end else if (wr_mip) begin
            // CSR write: update pending bits directly
            mip_MEIP <= wdata_i[11];  // External interrupt pending
            mip_MTIP <= wdata_i[7];   // Timer interrupt pending
            mip_MSIP <= wdata_i[3];   // Software interrupt pending
        end else begin
            // Normal operation: pending = enable & external source
            mip_MEIP <= mie_MEIE & m_ext_inter_i;    // External interrupt pending
            mip_MTIP <= mie_MTIE & m_timer_inter_i;  // Timer interrupt pending
            mip_MSIP <= mie_MSIE & m_soft_inter_i;   // Software interrupt pending
        end
    end

    //===================== MIP Read Data ========================//
    // Format: [63:12] = Reserved, [11] = MEIP, [10:8] = Reserved, [7] = MTIP, [6:4] = Reserved, [3] = MSIP, [2:0] = Reserved
    wire [`XLEN-1:0] mip_rdata = {52'b0, mip_MEIP, 3'b0, mip_MTIP, 3'b0, mip_MSIP, 3'b0};


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                         Machine Counter-Inhibit CSR (mcountinhibit)                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Counter Inhibit: Controls which performance counters are enabled/disabled
    // Allows software to selectively enable or disable individual counters

    reg [31:0] mcountinhibit;    // Counter inhibit bits (one per counter)

    //===================== MCOUNTINHIBIT Register Logic =========//
    // Update counter inhibit bits on write
    always @(posedge clk_i) begin : mcountinhibit_logic
        if (~rst_ni)
            mcountinhibit <= 'b0;                // Reset: all counters enabled
        else if (wr_mcountinhibit)
            mcountinhibit <= wdata_i[31:0];      // Write new inhibit bits
    end

    //===================== Counter Inhibit Signals ==============//
    // Individual counter inhibit signals for performance counters
    wire mcycle_inhibited   = mcountinhibit[0];  // Machine cycle counter inhibit
    wire minstret_inhibited = mcountinhibit[2];  // Machine instruction retired counter inhibit

    //===================== MCOUNTINHIBIT Read Data ==============//
    // Format: [63:32] = Reserved, [31:0] = Counter inhibit bits
    wire [`XLEN-1:0] mcountinhibit_rdata = { 32'b0, mcountinhibit };


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                           Machine Counter-Enable CSR (mcounteren)                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Counter Enable: Controls which counters are accessible in user mode
    // Allows machine mode to control user access to performance counters

    reg [31:0] mcounteren;    // Counter enable bits for user mode access

    //===================== MCOUNTEREN Register Logic =============//
    // Update counter enable bits on write
    always @(posedge clk_i) begin : mcounteren_logic
        if (~rst_ni)
            mcounteren <= 'b0;                // Reset: no user access to counters
        else if (wr_mcounteren)
            mcounteren <= wdata_i[31:0];      // Write new enable bits
    end

    //===================== Counter Enable Signals ===============//
    // Individual counter enable signals for user mode access
    wire cycle_enabled   = mcounteren[0];     // Cycle counter user access
    wire time_enabled    = mcounteren[1];     // Time counter user access
    wire instret_enabled = mcounteren[2];     // Instruction retired counter user access

    //===================== MCOUNTEREN Read Data =================//
    // Format: [63:32] = Reserved, [31:0] = Counter enable bits
    wire [`XLEN-1:0] mcounteren_rdata = { 32'b0, mcounteren };


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                            Machine Scratch Register (mscratch)                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Scratch: General-purpose scratch register for trap handlers
    // Used by trap handlers to save and restore processor state

    reg [`XLEN-1:0] mscratch;    // 64-bit scratch register

    //===================== MSCRATCH Register Logic ==============//
    // Update scratch register on write
    always @(posedge clk_i) begin : mscratch_logic
        if (~rst_ni)
            mscratch <= 'b0;                // Reset: clear scratch register
        else if (wr_mscratch)
            mscratch <= wdata_i;            // Write new scratch value
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                         Machine Exception Program Counter (mepc)                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Exception PC: Stores the PC where an exception or interrupt occurred
    // Used by MRET instruction to return to the interrupted instruction

    reg [`XLEN-1:1] mepc;    // Exception PC (bit 0 always 0 for alignment)

    //===================== PC Address Conversion ================//
    // Convert virtual addresses to 64-bit format for MEPC storage
    wire [`XLEN-1:1] MEM_pc = { {`XLEN-VADDR{1'b0}}, MEM_exc_pc_i[VADDR-1:1]};  // MEM stage PC
    wire [`XLEN-1:0] EXE_pc = { {`XLEN-VADDR{1'b0}}, EXE_exc_pc_i[VADDR-1:0]};  // EXE stage PC

    //===================== MEPC Register Logic ===================//
    // Update MEPC on exception/interrupt or CSR write
    always @(posedge clk_i) begin : mepc_logic
        if (~rst_ni)
            mepc <= 'b0;                                    // Reset: clear MEPC
        else if (wr_mepc)
            mepc <= wdata_i[`XLEN-1:1];                     // CSR write: update MEPC
        else if (unalign_store_ex_i || unalign_load_ex_i)
            mepc <= MEM_pc[`XLEN-1:1];                      // Memory exception: use MEM stage PC
        else if (M_intr_taken_a)
            mepc <= EXE_pc[`XLEN-1:1];                      // Interrupt: use EXE stage PC
    end

    //===================== MEPC Read Data ========================//
    // Format: [63:1] = Exception PC, [0] = Always 0 (alignment)
    wire [`XLEN-1:0] mepc_rdata = { mepc, 1'b0 };
    
    // Unused signal (prevents synthesis warnings)
    wire _unused = MEM_exc_pc_i[0];


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                              Machine Cause Register (mcause)                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Cause: Stores the cause of the last exception or interrupt
    // Format: [63] = Interrupt flag, [62:0] = Cause code

    reg mcause_int;        // Interrupt flag (1=interrupt, 0=exception)
    reg [62:0] mcause_code; // Cause code (exception or interrupt type)

    //===================== MCAUSE Register Logic ==================//
    // Update cause code based on exception/interrupt type or CSR write
    always @(posedge clk_i) begin : mcause_logic
        if (~rst_ni)
            mcause_code <= 'b0;                                    // Reset: clear cause code
        else if (ebreak_ex_i)
            mcause_code  <= `MCAUSE_BREAKPOINT;                    // EBREAK exception
        else if (ecall_ex_i)
            mcause_code  <= `MCAUSE_ECALL_FROM_M_MODE;             // ECALL from machine mode
        else if (illegal_inst_ex_i)
            mcause_code  <= `MCAUSE_ILLEGAL_INST;                  // Illegal instruction
        else if (unalign_load_ex_i)
            mcause_code  <= `MCAUSE_LOAD_ADDR_MISALIGNED;          // Load address misaligned
        else if (unalign_store_ex_i)
            mcause_code  <= `MCAUSE_STORE_AMO_MISALIGNED;          // Store address misaligned
        else if (M_timer_inter)
            mcause_code  <= `MCAUSE_MACH_TIMER_INT;                // Machine timer interrupt
        else if (M_ext_inter)
            mcause_code  <= `MCAUSE_MACH_EXT_INT;                  // Machine external interrupt
        else if (M_soft_inter)
            mcause_code  <= `MCAUSE_MACH_SOFT_INT;                 // Machine software interrupt
        else if (wr_mcause)
            mcause_code <= wdata_i[62:0];                          // CSR write: update cause code

        // Update interrupt flag based on exception/interrupt type
        if (~rst_ni || M_exception_a)
            mcause_int <= 'b0;                                     // Reset or exception: clear interrupt flag
        else if (M_interrupt_a)
            mcause_int <= 'b1;                                     // Interrupt: set interrupt flag
        else if (wr_mcause)
            mcause_int <= wdata_i[`XLEN-1];                        // CSR write: update interrupt flag
    end

    //===================== MCAUSE Read Data =======================//
    // Format: [63] = Interrupt flag, [62:0] = Cause code
    wire [`XLEN-1:0] mcause_rdata = { mcause_int, mcause_code };


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 Machine Trap Value (mtval)                                //    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Trap Value: Stores additional information about the exception or interrupt
    // Contains bad address for memory exceptions, instruction for breakpoints, etc.

    reg  [`XLEN-1:0] mtval;    // Trap value register
    wire [`XLEN-1:0] LS_bad_addr = { {`XLEN-VADDR{1'b0}}, load_store_bad_addr[VADDR-1:0]};  // Load/store bad address

    //===================== MTVAL Register Logic ===================//
    // Update trap value based on exception type or CSR write
    always @(posedge clk_i) begin : mtval_logic
        if (~rst_ni)
            mtval <= 'b0;                                    // Reset: clear trap value
        else if ( ebreak_ex_i )
            mtval <= EXE_pc;                                 // EBREAK: store instruction address
        else if ( unalign_load_ex_i || unalign_store_ex_i )
            mtval <= LS_bad_addr;                            // Memory exception: store bad address
        else if ( wr_mtval )
            mtval <= wdata_i;                                // CSR write: update trap value
        else if ( M_exception_a && ~ecall_ex_i )
            mtval <= 'b0;                                    // Other exceptions: clear trap value
        // TODO: implement mtval behavior on all exceptions.
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                               Machine Trap Value 2 (mtval2)                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Trap Value 2: Additional trap value register for hypervisor extensions
    // Currently minimal implementation, may be extended for hypervisor support

    reg [`XLEN-1:0] mtval2;    // Second trap value register
    
    //===================== MTVAL2 Register Logic ==================//
    // Update trap value 2 on CSR write
    always @(posedge clk_i) begin : mtval2_logic
        if (~rst_ni)
            mtval2 <= 'b0;                // Reset: clear trap value 2
        else if (wr_mtval2)
            mtval2 <= wdata_i;            // CSR write: update trap value 2
        // TODO : any additional behavior for mtval2
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //      __  __  _   _  ____   __  __      ____                      _                        //
    //     |  \/  || | | ||  _ \ |  \/  |    / ___| ___   _   _  _ __  | |_  ___  _ __  ___      //
    //     | |\/| || |_| || |_) || |\/| |   | |    / _ \ | | | || '_ \ | __|/ _ \| '__|/ __|     //
    //     | |  | ||  _  ||  __/ | |  | |   | |___| (_) || |_| || | | || |_|  __/| |   \__ \     //
    //     |_|  |_||_| |_||_|    |_|  |_|    \____|\___/  \__,_||_| |_| \__|\___||_|   |___/     //
    //                                                                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                Machine Cycle Counter (mcycle)                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Cycle Counter: Counts CPU clock cycles
    // Increments every clock cycle when not inhibited

    reg [`XLEN-1:0] mcycle;    // 64-bit cycle counter

    //===================== MCYCLE Register Logic ==================//
    // Update cycle counter on write or increment when not inhibited
    always @(posedge clk_i) begin : mcycle_logic
        if (~rst_ni)
            mcycle <= 'b0;                    // Reset: clear cycle counter
        else if (wr_mcycle)
            mcycle <= wdata_i;                // CSR write: update cycle counter
        else if (~mcycle_inhibited)
            mcycle <= mcycle + 1;             // Normal operation: increment counter
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                        Machine Instruction Retired Counter (minstret)                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Machine Instruction Retired Counter: Counts completed instructions
    // Increments when an instruction completes execution (retires)

    reg [`XLEN-1:0] minstret;    // 64-bit instruction retired counter

    //===================== MINSTRET Register Logic ================//
    // Update instruction counter on write or increment when instruction retires
    always @(posedge clk_i) begin : minstret_logic
        if (~rst_ni)
            minstret <= 'b0;                                    // Reset: clear instruction counter
        else if (wr_minstret)
            minstret <= wdata_i;                                // CSR write: update instruction counter
        else if (instr_retired_i && ~minstret_inhibited)
            minstret <= minstret + 1;                           // Instruction retired: increment counter
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //              Unnamed Machine Hardware Performance Counters (mhpmcounter 3 - 31)           //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Additional hardware performance monitoring counters
    // Currently not implemented, reserved for future expansion

    // TODO (finish) : Add additional counters
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //         ____                              _                   ____ ____  ____             //
    //        / ___| _   _ _ __   ___ _ ____   _(_)___  ___  _ __   / ___/ ___||  _ \ ___        //
    //        \___ \| | | | '_ \ / _ \ '__\ \ / / / __|/ _ \| '__| | |   \___ \| |_) / __|       //
    //         ___) | |_| | |_) |  __/ |   \ V /| \__ \ (_) | |    | |___ ___) |  _ <\__ \       //
    //        |____/ \__,_| .__/ \___|_|    \_/ |_|___/\___/|_|     \____|____/|_| \_\___/       //
    //                    |_|                                                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //               ____                _    ____            _             _                    //
    //              |  _ \ ___  __ _  __| |  / ___|___  _ __ | |_ _ __ ___ | |___                //
    //              | |_) / _ \/ _` |/ _` | | |   / _ \| '_ \| __| '__/ _ \| / __|               //
    //              |  _ <  __/ (_| | (_| | | |__| (_) | | | | |_| | | (_) | \__ \               //
    //              |_| \_\___|\__,_|\__,_|  \____\___/|_| |_|\__|_|  \___/|_|___/               //
    //                                                                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    //===================== CSR Read/Write State ==================//
    reg [`XLEN-1:0] rdata_next;        // Next read data value
    reg             illegal_m_rd;      // Machine mode read illegal
    reg             illegal_sv_rd;     // Supervisor mode read illegal
    reg             illegal_hv_rd;     // Hypervisor mode read illegal
    reg             illegal_u_rd;      // User mode read illegal
    reg             illegal_csr_rd;    // Any CSR read illegal
    
    // TODO: illegal read detection must be done asyncronously and fed back to the stage that
    //       requests it.

    //===================== CSR Read Logic ========================//
    // Decode CSR read operations based on privilege level and address
    always @(*) begin
        if (~rst_ni) begin
            // Reset: clear all read data and illegal flags
            rdata_next     = '0;
            illegal_m_rd   = '0;
            illegal_hv_rd  = '0;
            illegal_sv_rd  = '0;
            illegal_u_rd   = '0;
        end else begin
            // Normal operation: decode CSR read
            illegal_m_rd   = '0;
            illegal_sv_rd  = '0;
            illegal_u_rd   = '0;
            illegal_hv_rd  = '0;

            if (rd_en_i) begin
                // Decode CSR address based on privilege level (bits 9:8)
                case (rd_addr_i[9:8]) // CSR privilege Modes

                    `MACHINE_MODE: begin
                        // Machine mode CSRs: accessible only in machine mode
                        if (privilege_mode != `MACHINE_MODE) begin
                            rdata_next                      = {52'b0, rd_addr_i};  // Return address for illegal access
                            illegal_m_rd                    = 'b1;                  // Set illegal read flag
                        end else case (rd_addr_i)
                            //===================== Machine Information Registers (Read-Only) =====//
                            `CSR_MVENDORID     : rdata_next = `VENDOR_ID_VAL;      // Vendor ID
                            `CSR_MARCHID       : rdata_next = `MARCH_ID_VAL;       // Architecture ID
                            `CSR_MIMPID        : rdata_next = `IMP_ID_VAL;         // Implementation ID
                            `CSR_MHARTID       : rdata_next = `HART_ID_VAL;        // Hardware thread ID
                            `CSR_MCONFIGPTR    : rdata_next = `CONFIG_PTR_VAL;     // Configuration pointer
                            
                            //===================== Machine Trap Setup (Read-Write) =============//
                            `CSR_MSTATUS       : rdata_next = mstatus_rdata;       // Machine status
                            `CSR_MISA          : rdata_next = misa_rdata;           // Machine ISA
                            `CSR_MIE           : rdata_next = mie_rdata;            // Machine interrupt enable
                            `CSR_MTVEC         : rdata_next = mtvec_rdata;          // Machine trap vector
                            
                            //===================== Machine Counter Setup (Read-Write) ==========//
                            `CSR_MCOUNTEREN    : rdata_next = mcounteren_rdata;     // Machine counter enable
                            `CSR_MCOUNTINHIBIT : rdata_next = mcountinhibit_rdata;  // Machine counter inhibit
                            
                            //===================== Machine Trap Handling (Read-Write) ==========//
                            `CSR_MSCRATCH      : rdata_next = mscratch;             // Machine scratch
                            `CSR_MEPC          : rdata_next = mepc_rdata;           // Machine exception PC
                            `CSR_MCAUSE        : rdata_next = mcause_rdata;         // Machine cause
                            `CSR_MTVAL         : rdata_next = mtval;                // Machine trap value
                            `CSR_MIP           : rdata_next = mip_rdata;            // Machine interrupt pending
                            `CSR_MTVAL2        : rdata_next = mtval2;               // Machine trap value 2
                            
                            //===================== Machine Performance Counters ===============//
                            `CSR_MCYCLE        : rdata_next = mcycle;               // Machine cycle counter
                            `CSR_MINSTRET      : rdata_next = minstret;             // Machine instruction retired

                            default: begin
                                rdata_next               = {52'b0, rd_addr_i};      // Unknown CSR: return address
                                illegal_m_rd             = 'b1;                      // Set illegal read flag
                            end
                        endcase
                    end // Machine Mode


                    `SUPERVISOR_MODE: begin
                        // Supervisor mode CSRs: not accessible from user mode
                        if (privilege_mode == `USER_MODE) begin
                            rdata_next                   = {52'b0, rd_addr_i};      // Return address for illegal access
                            illegal_sv_rd                = 'b1;                      // Set illegal read flag
                        end else case (rd_addr_i)
                            // Supervisor mode CSRs not implemented
                            default: begin
                                rdata_next               = {52'b0, rd_addr_i};      // Unknown CSR: return address
                                illegal_sv_rd            = 'b1;                      // Set illegal read flag
                            end
                        endcase
                    end // Supervisor Mode

                    `USER_MODE: begin
                        // User mode CSRs: accessible based on mcounteren enable bits
                        case (rd_addr_i)
                            `CSR_CYCLE: begin
                                // Cycle counter: accessible if enabled in mcounteren
                                illegal_u_rd = ~cycle_enabled;                       // Illegal if not enabled
                                rdata_next   = cycle_enabled ? mcycle : '0;          // Return counter or 0
                            end

                            `CSR_TIME: begin
                                // Time counter: accessible if enabled in mcounteren
                                illegal_u_rd = ~time_enabled;                        // Illegal if not enabled
                                rdata_next   = time_enabled ? time_i : '0;           // Return time or 0
                            end

                            `CSR_INSTRET: begin
                                // Instruction retired counter: accessible if enabled in mcounteren
                                illegal_u_rd = ~instret_enabled;                     // Illegal if not enabled
                                rdata_next   = instret_enabled ? minstret : '0;      // Return counter or 0
                            end

                            default: begin
                                rdata_next               = {52'b0, rd_addr_i};      // Unknown CSR: return address
                                illegal_u_rd             = 'b1;                      // Set illegal read flag
                            end
                        endcase
                    end // User Mode

                    default: begin
                        // Hypervisor mode CSRs: not implemented
                        rdata_next    = {52'b0, rd_addr_i};                          // Return address for illegal access
                        illegal_hv_rd = '1;                                          // Set illegal read flag
                    end

                endcase // case (rd_addr_i[9:8])
            end // rd_en_i

            illegal_csr_rd = illegal_m_rd || illegal_sv_rd || illegal_u_rd || illegal_hv_rd;

        end
    end

    always @(posedge clk_i) begin
        if (rd_en_i)
            rdata_o <= rdata_next;
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //       __        __      _  _           ____               _                _              //
    //       \ \      / /_ __ (_)| |_  ___   / ___| ___   _ __  | |_  _ __  ___  | | ___         //
    //        \ \ /\ / /| '__|| || __|/ _ \ | |    / _ \ | '_ \ | __|| '__|/ _ \ | |/ __|        //
    //         \ V  V / | |   | || |_|  __/ | |___| (_) || | | || |_ | |  | (_) || |\__ \        //
    //          \_/\_/  |_|   |_| \__|\___|  \____|\___/ |_| |_| \__||_|   \___/ |_||___/        //
    //                                                                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    //===================== CSR Write State =======================//
    reg illegal_m_wr;      // Machine mode write illegal
    reg illegal_sv_wr;     // Supervisor mode write illegal
    reg illegal_hv_wr;     // Hypervisor mode write illegal
    reg illegal_u_wr;      // User mode write illegal
    reg illegal_csr_wr;    // Any CSR write illegal
    
    //===================== CSR Write Logic =======================//
    // Decode CSR write operations based on privilege level and address
    always @(*) begin
        if (~rst_ni) begin
            // Reset: clear all write enable and illegal flags
            { illegal_m_wr, illegal_sv_wr, illegal_u_wr, wr_mstatus, wr_misa, wr_mie, wr_mtvec, 
              wr_mcountinhibit, wr_mscratch, wr_mepc, wr_mcause, wr_mtval, wr_mip, wr_mtval2, 
              wr_mcycle, wr_minstret, illegal_csr_wr, wr_mcounteren, illegal_hv_wr } = 'b0;
        end else begin
            // Normal operation: decode CSR write
            { illegal_m_wr, illegal_sv_wr, illegal_u_wr, wr_mstatus, wr_misa, wr_mie, wr_mtvec, 
              wr_mcountinhibit, wr_mscratch, wr_mepc, wr_mcause, wr_mtval, wr_mip, wr_mtval2, 
              wr_mcycle, wr_minstret, wr_mcounteren, illegal_hv_wr } = 'b0;

            if (wr_en_i) begin
                // Decode CSR address based on privilege level (bits 9:8)
                case (wr_addr_i[9:8]) // CSR privilege Modes

                    `MACHINE_MODE: begin
                        // Machine mode CSRs: writable only in machine mode
                        if (privilege_mode != `MACHINE_MODE) 
                            illegal_m_wr                            = 1'b1;          // Set illegal write flag
                        else case (wr_addr_i)
                            //===================== Machine Trap Setup (Read-Write) =============//
                            `CSR_MSTATUS       : wr_mstatus         = 1'b1;          // Machine status
                            `CSR_MISA          : wr_misa            = 1'b1;          // Machine ISA
                            `CSR_MIE           : wr_mie             = 1'b1;          // Machine interrupt enable
                            `CSR_MTVEC         : wr_mtvec           = 1'b1;          // Machine trap vector
                            
                            //===================== Machine Counter Setup (Read-Write) ==========//
                            `CSR_MCOUNTEREN    : wr_mcounteren      = 1'b1;          // Machine counter enable
                            `CSR_MCOUNTINHIBIT : wr_mcountinhibit   = 1'b1;          // Machine counter inhibit
                            
                            //===================== Machine Trap Handling (Read-Write) ==========//
                            `CSR_MSCRATCH      : wr_mscratch        = 1'b1;          // Machine scratch
                            `CSR_MEPC          : wr_mepc            = 1'b1;          // Machine exception PC
                            `CSR_MCAUSE        : wr_mcause          = 1'b1;          // Machine cause
                            `CSR_MTVAL         : wr_mtval           = 1'b1;          // Machine trap value
                            `CSR_MIP           : wr_mip             = 1'b1;          // Machine interrupt pending
                            `CSR_MTVAL2        : wr_mtval2          = 1'b1;          // Machine trap value 2
                            
                            //===================== Machine Performance Counters ===============//
                            `CSR_MCYCLE        : wr_mcycle          = 1'b1;          // Machine cycle counter
                            `CSR_MINSTRET      : wr_minstret        = 1'b1;          // Machine instruction retired

                            default            : illegal_m_wr       = 1'b1;          // Unknown CSR: illegal write
                        endcase
                    end // Machine Mode


                    `SUPERVISOR_MODE: begin
                        // Supervisor mode CSRs: not writable from user mode
                        if (privilege_mode == `USER_MODE)
                            illegal_sv_wr          = 'b1;                              // Set illegal write flag
                        else case (wr_addr_i)
                            default: illegal_sv_wr = 'b1;                              // Supervisor CSRs not implemented
                        endcase
                    end // Supervisor

                    `USER_MODE: begin
                        // User mode CSRs: no writable CSRs in user mode
                        case (wr_addr_i)
                            default: illegal_u_wr = 'b1;                               // All user mode writes illegal
                        endcase
                    end // User Mode

                    default: illegal_hv_wr = 'b1;                                      // Hypervisor mode CSRs not implemented

                endcase // case (wr_addr_i[9:8])
            end // wr_en_i

            illegal_csr_wr = illegal_m_wr || illegal_sv_wr || illegal_u_wr || illegal_hv_wr;
        end
    end


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      Interrupt Handling                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Handles interrupt and exception processing, trap vector generation, and control flow

    //===================== Trap Vector Generation ================//
    // Generate trap vector addresses for interrupt/exception handling
    wire [VADDR-1:0] vectored_offset = mcause_code[VADDR+1:2];  // Vectored mode offset
    wire [VADDR-1:0] direct_target   = { mtvec_base, 2'b0 };     // Direct mode target

    //===================== Interrupt Taken Register ==============//
    // Register interrupt taken signal for proper timing
    always @(posedge clk_i) begin
        M_intr_taken_r <= rst_ni ? M_intr_taken_a : 'b0;         // Register interrupt taken
    end

    //===================== Branch Address Generation =============//
    // Generate branch target address for trap handling
    always @(*) begin
        if (mtvec_mode == `MTVEC_MODE_VECTORED && ~M_exception_a) 
            csr_branch_addr_o  = direct_target + vectored_offset;  // Vectored mode: base + offset
        else begin
            csr_branch_addr_o  = direct_target;                    // Direct mode: base address only
        end
    end

    //===================== Interrupt Masking Logic ==============//
    // Generate interrupt enable and active signals
    assign M_inter_en    = MIE || (privilege_mode != `MACHINE_MODE);  // Global interrupt enable
    assign M_ext_inter   = mip_MEIP && mie_MEIE && M_inter_en;        // External interrupt active
    assign M_timer_inter = mip_MTIP && mie_MTIE && M_inter_en;        // Timer interrupt active
    assign M_soft_inter  = mip_MSIP && mie_MSIE && M_inter_en;        // Software interrupt active
    assign M_interrupt_a = M_ext_inter || M_timer_inter || M_soft_inter;  // Any interrupt active

    //===================== Exception Detection ==================//
    // Generate exception and interrupt taken signals
    assign csr_wr_ex_ao   = illegal_csr_wr;                       // CSR write exception
    assign csr_rd_ex_ao   = illegal_csr_rd;                       // CSR read exception
    assign M_exception_a = (unalign_load_ex_i  || illegal_inst_ex_i || ecall_ex_i || 
                          unalign_store_ex_i || ebreak_ex_i );     // Any exception active
    assign M_intr_taken_a = M_exception_a || M_interrupt_a;       // Exception or interrupt taken
    assign csr_interrupt_ao = M_intr_taken_a;                     // CSR interrupt output
    assign trap_ret_addr_o = mepc_rdata[VADDR-1:0];              // Trap return address


endmodule
