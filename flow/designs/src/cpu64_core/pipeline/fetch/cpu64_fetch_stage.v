`include "cpu64_defs.vh"
// `include "cpu64_obi_host_driver.v"
// `include "cpu64_obi_host_driver_cpu.v"
// `include "cpu64_validity_tracker.v"

/* verilator lint_off MULTITOP */
// =============================================================================
// cpu64_fetch_stage.v (Verilog-2001)
// - Single-outstanding fetch
// - Captures accepted request PC (pc_acc_q) on req_fire
// - ADVANCES issue PC ONLY on rsp_fire:
//       pc_req_q <= (redirect_pending ? redir_target_q
//                                      : pc_acc_q + (ret_is16_i ? 2 : 4));
// - First visible pc_o = RESET_ADDR; continuity holds: next_pc(prev) == pc(curr)
// =============================================================================

module cpu64_fetch_stage
#(
  parameter VADDR       = 39,
  parameter [VADDR-1:0] RESET_ADDR = {VADDR{1'b0}},
  // MODE: 0 = ICACHE behavior (default), 1 = CPU behavior
  parameter integer     MODE = 0
)(
  input                   clk_i,
  input                   rst_ni,

  // Pipeline control
  input                   squash_i,
  input                   bubble_i,
  input                   stall_i,
  input                   fencei_i,

  // Returned length (ICACHE) / Compressed feedback (CPU)
  input                   ret_is16_i,        // ICACHE: 1 => 16-bit return
  input                   compressed_instr_i,// CPU: previous instruction was 16-bit

  // Branch control
  input                   branch_i,
  input      [VADDR-1:0] target_addr_i,
  input                   csr_branch_i,
  input      [VADDR-1:0] csr_branch_addr_i,
  input                   trap_ret_i,
  input      [VADDR-1:0] trap_ret_addr_i,

  // I$-like instruction port
  output                  imem_req_o,
  output     [VADDR-1:0] imem_addr_ao,
  input                   imem_gnt_i,
  input                   imem_rvalid_i,
  input      [31:0]       imem_rdata_i,  // Instruction data from memory/cache
  output                  imem_stall_ao,

  // Outputs (visible same cycle as rvalid)
  output reg              valid_o,
  output reg [VADDR-1:0]  pc_o,
  output reg [VADDR-1:0]  next_pc_o,
  output     [31:0]       inst_o  // Instruction output
);

  // ==========================================================================
  // Branch on MODE: ICACHE (0) vs CPU (1)
  // ==========================================================================
  generate if (MODE == 0) begin : g_icache
    // --- constants ---
    wire [VADDR-1:0] STEP_2 = {{(VADDR-2){1'b0}}, 2'd2};
    wire [VADDR-1:0] STEP_4 = {{(VADDR-3){1'b0}}, 3'd4};

    // --- simple valid tracking ---
    reg valid_q;
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)        valid_q <= 1'b0;
      else if (squash_i)  valid_q <= 1'b0;
      else if (bubble_i)  valid_q <= 1'b0;
      else if (!(stall_i | imem_stall_ao))
                           valid_q <= 1'b1;
    end

    // --- request PC (for issuing), accepted PC (for reporting) ---
    reg  [VADDR-1:0] pc_req_q;   // issue address provided to OBI
    reg  [VADDR-1:0] pc_acc_q;   // address captured on accept; reported on return

    // --- pending redirect capture (handles branch/CSR/xRET while outstanding) ---
    reg              redir_valid_q;
    reg  [VADDR-1:0] redir_target_q;

    wire [VADDR-1:0] branch_target_raw =
        csr_branch_i ? csr_branch_addr_i :
        branch_i     ? target_addr_i     :
        trap_ret_i   ? trap_ret_addr_i   :
                       {VADDR{1'b0}};

    wire              branch_any = (csr_branch_i | branch_i | trap_ret_i);
    wire [VADDR-1:0]  branch_target_aligned = {branch_target_raw[VADDR-1:1], 1'b0};

    // Capture a redirect as soon as it appears; consume it at the next response
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        redir_valid_q  <= 1'b0;
        redir_target_q <= {VADDR{1'b0}};
      end else begin
        if (branch_any)
          redir_valid_q <= 1'b1;
        if (branch_any)
          redir_target_q <= branch_target_aligned;
        if (imem_rvalid_i) // consume the pending redirect when we advance PC
          redir_valid_q <= 1'b0;
      end
    end

    // handshakes
    wire rd_en    = valid_q & ~fencei_i; // fencei blocks fetch
    wire req_fire = imem_req_o   & imem_gnt_i;   // request accepted
    wire rsp_fire = imem_rvalid_i;               // instruction returned

    // Track if there's an outstanding fetch request (granted but not yet responded)
    reg fetch_outstanding;
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)
        fetch_outstanding <= 1'b0;
      else if (req_fire)
        fetch_outstanding <= 1'b1;
      else if (rsp_fire)
        fetch_outstanding <= 1'b0;
    end

    // Track if a branch/redirect occurred while a fetch was outstanding
    // This ensures we invalidate stale instructions that were fetched before the redirect
    reg branch_killed_fetch;
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        branch_killed_fetch <= 1'b0;
      end else if (rsp_fire) begin
        // Clear on response
        branch_killed_fetch <= 1'b0;
      end else if (fetch_outstanding && branch_any) begin
        // Set if branch happens while fetch is outstanding
        branch_killed_fetch <= 1'b1;
      end
    end

    // On accept: capture the request PC for this transaction (do not advance issue PC yet)
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        pc_req_q <= RESET_ADDR;
        pc_acc_q <= RESET_ADDR;
      end else begin
        if (req_fire)
          pc_acc_q <= pc_req_q;

        // ADVANCE ISSUE PC ONLY on response: apply pending redirect or +2/+4 from accepted PC
        if (rsp_fire) begin
          if (redir_valid_q)
            pc_req_q <= redir_target_q;
          else
            pc_req_q <= pc_acc_q + (ret_is16_i ? STEP_2 : STEP_4);
        end
      end
    end

    // --- fetched_pc captures PC at request time (not accept time) ---
    // This ensures PC stays synchronized with instruction even if branches occur
    // between request and response
    reg  [VADDR-1:0] fetched_pc;
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)
        fetched_pc <= RESET_ADDR;
      else if (req_fire)
        fetched_pc <= pc_req_q;  // Capture the PC being requested
    end

    //  Hold regs so outputs are stable when no return this cycle
    reg              valid_hold_q;
    reg [VADDR-1:0]  pc_hold_q;
    reg [VADDR-1:0]  next_hold_q;
    reg [31:0]       inst_hold_q;
    always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        valid_hold_q <= 1'b0;
        pc_hold_q    <= RESET_ADDR;
        next_hold_q  <= RESET_ADDR;
        inst_hold_q  <= 32'h00000013;  // NOP
      end else if (squash_i) begin
        // Clear valid on squash (branch misprediction)
        valid_hold_q <= 1'b0;
        inst_hold_q  <= 32'h00000013;  // NOP
      end else if (rsp_fire) begin
        // Invalidate if branch killed this fetch while it was outstanding
        valid_hold_q <= valid_q && !branch_killed_fetch;
        pc_hold_q    <= fetched_pc;  // Use fetched_pc instead of pc_acc_q
        next_hold_q  <= fetched_pc + (ret_is16_i ? STEP_2 : STEP_4);
        // Insert NOP if branch killed this fetch
        inst_hold_q  <= branch_killed_fetch ? 32'h00000013 : imem_rdata_i;
      end
    end

    // Combinational outputs: expose return in same cycle
    always @* begin
      valid_o   = valid_hold_q;
      pc_o      = pc_hold_q;
      next_pc_o = next_hold_q;
      if (rsp_fire) begin
        valid_o   = valid_q && !branch_killed_fetch;  // Invalidate if branch killed
        pc_o      = fetched_pc;  // Use fetched_pc instead of pc_acc_q
        next_pc_o = fetched_pc + (ret_is16_i ? STEP_2 : STEP_4);
      end
    end

    // Instruction output: expose returned instruction (or NOP if killed by branch)
    assign inst_o = rsp_fire ? (branch_killed_fetch ? 32'h00000013 : imem_rdata_i) : inst_hold_q;

    // OBI host driver (single-outstanding, read-only; address = pc_req_q)
    cpu64_obi_host_driver_icache #(
      .DATA_W (32),
      .ADDR_W (VADDR)
    ) u_obi_icache (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .gnt_i      (imem_gnt_i),
      .rvalid_i   (imem_rvalid_i),
      .stall_i    (stall_i),
      .be_i       (4'b0000),
      .addr_i     (pc_req_q),
      .wdata_i    (32'h0),
      .rd_i       (rd_en),
      .wr_i       (1'b0),
      .stall_ao   (imem_stall_ao),
      .req_o      (imem_req_o),
      .we_ao      (/*unused*/ ),
      .be_ao      (/*unused*/ ),
      .addr_ao    (imem_addr_ao),
      .wdata_ao   (/*unused*/ )
    );

  end else begin : g_cpu
    // ============================ CPU MODE ================================
    // Validity tracker
    wire valid;
    cpu64_validity_tracker FCH_validity_tracker (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .valid_i  (1'b1),
      .squash_i (squash_i),
      .bubble_i (bubble_i),
      .stall_i  (stall_i),
      .valid_ao (valid)
    );

    // Control and state
    reg stall_delayed, branch_taken_r, branch_taken_saved;
    reg [VADDR-1:0] pc, next_pc, next_pc_current, next_pc_saved, pc_updated;
    reg saved_pc_valid;  // Track if next_pc_saved contains a valid saved target

    wire branch_taken = (trap_ret_i || branch_i || csr_branch_i);

    // Stall delay
    always @(posedge clk_i) begin
      if (~rst_ni)
        stall_delayed <= 1'b0;
      else 
        stall_delayed <= stall_i;
    end

    // Save PC targets
    // When coming out of a stall, use the saved PC only if it was set during that stall
    always @(posedge clk_i) begin
      if (~rst_ni) begin
        next_pc_saved      <= 'b0;
        branch_taken_saved <= 'b0;
        saved_pc_valid     <= 1'b0;
      end else if (~stall_delayed) begin
        next_pc_saved      <= next_pc_current;
        branch_taken_saved <= branch_taken;
        saved_pc_valid     <= 1'b0;  // Clear validity when not stalled
      end else if (branch_i && ~saved_pc_valid) begin
        // Only save branch target if we haven't already saved one during this stall period
        next_pc_saved      <= target_addr_i;
        saved_pc_valid     <= 1'b1;  // Mark as valid
      end
    end

    // Current PC target
    always @(*) begin
      if      (csr_branch_i) next_pc_current = csr_branch_addr_i;
      else if (branch_i)     next_pc_current = target_addr_i;
      else if (trap_ret_i)   next_pc_current = trap_ret_addr_i;
      else                   next_pc_current = (pc + 4);
    end

    // PC update with compressed correction
    always @(*) begin
      // Only use saved PC if it's valid (was actually saved during a stall)
      pc_updated = (stall_delayed && saved_pc_valid) ? next_pc_saved : next_pc_current;

      if (branch_i) begin
        next_pc = target_addr_i;
      end else if (~branch_taken || (stall_delayed && ~branch_taken_saved)) begin
        next_pc = compressed_instr_i ? (pc_updated - 2) : pc_updated;
      end else begin
        next_pc = pc_updated;
      end
    end

    // Program counter register
    wire [VADDR-1:0] pc_out;
    always @(posedge clk_i) begin
      if      (~rst_ni)   pc <= RESET_ADDR;
      else if (~stall_i)  pc <= next_pc & (~('b1));
    end

    // Branch taken register
    always @(posedge clk_i) begin
      if      (~rst_ni)   branch_taken_r <= 'b0;
      else if (~stall_i)  branch_taken_r <= branch_taken;
    end

    // Compressed correction on output PC
    assign pc_out = (compressed_instr_i && ~branch_taken_r) ? (pc - 2) : pc;

    // OBI host driver (CPU mode - supports RW)
    wire [31:0] wdata;
    wire [3:0]  be;
    wire        we;
    wire        read = valid && ~fencei_i;

    cpu64_obi_host_driver #(
      .DATA_W(32), .ADDR_W(VADDR)
    ) imem_obi_host_driver_cpu (
      .clk_i    (clk_i),
      .rst_ni   (rst_ni),
      .gnt_i    (imem_gnt_i),
      .rvalid_i (imem_rvalid_i),
      .stall_i  (stall_i),
      .be_i     (4'b0),
      .addr_i   (pc_out),
      .wdata_i  (32'b0),
      .rd_i     (read),
      .wr_i     (1'b0),
      .stall_ao (imem_stall_ao),
      .req_o    (imem_req_o),
      .we_ao    (we),
      .be_ao    (be),
      .addr_ao  (imem_addr_ao),
      .wdata_ao (wdata)
    );

    // Valid output register
    always @(posedge clk_i) begin
      if (~rst_ni)
        valid_o <= 1'b0;
      else if (~stall_i)
        valid_o <= valid && imem_rvalid_i;
    end

    // Track fetched PC (address of granted request)
    reg [VADDR-1:0] fetched_pc;
    always @(posedge clk_i) begin
      if (~rst_ni)
        fetched_pc <= RESET_ADDR;
      else if (imem_req_o && imem_gnt_i)
        fetched_pc <= imem_addr_ao;
    end

    // PC output registers (advance on response)
    always @(posedge clk_i) begin
      if (~rst_ni) begin
        pc_o      <= RESET_ADDR;
        next_pc_o <= RESET_ADDR + 4;
      end else if (imem_rvalid_i) begin
        pc_o      <= fetched_pc;
        next_pc_o <= fetched_pc + 4;
      end
    end

    // Instruction output register (latch fetched instruction)
    reg [31:0] inst_q;
    always @(posedge clk_i) begin
      if (~rst_ni)
        inst_q <= 32'h00000013; // NOP
      else if (imem_rvalid_i && ~stall_i)
        inst_q <= imem_rdata_i;
    end
    
    assign inst_o = inst_q;

  end endgenerate

endmodule
/* verilator lint_on MULTITOP */


