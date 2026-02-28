`define ICACHE_DBG
// `include "cpu64_l1i_arrays.v"
// `include "cpu64_l1_plru.v"
`timescale 1ns/1ps

module cpu64_icache_top (
  input              clk_i,
  input              rst_ni,

  // Optional maintenance
  input              invalidate_all_i,

  // CPU fetch side (simplified 32-bit output)
  input      [63:0]  fetch_pc_i,   // PC (word-aligned by core)
  input              fetch_req_i,
  output reg         fetch_gnt_o,
  output reg         instr_valid_o,
  output reg [31:0]  instr_o,
  // Removed: instr_is_16_o - core's decode will determine instruction length

  // Memory/bus side (read-only bursts)
  output reg         req_o,
  output reg         we_o,
  output reg  [7:0]  be_o,
  output reg [63:0]  addr_o,
  output reg [63:0]  wdata_o,
  input              gnt_i,
  input              rvalid_i,
  input      [63:0]  rdata_i
);

  // -----------------------------
  // Fixed configuration
  // -----------------------------
  localparam integer DATA_W          = 64;
  localparam integer WORDS_PER_LINE  = 8;   // 64B / 8B
  localparam integer SETS            = 64;  // 32KiB / (64B * 8 ways)
  localparam integer WAYS            = 8;
  localparam integer WORD_OFF_W      = 3;   // [5:3]
  localparam integer INDEX_W         = 6;   // [11:6]
  localparam integer TAG_W           = 52;  // [63:12]

  // -----------------------------
  // Invalidate: convert level to ONE-CYCLE PULSE on rising edge
  // -----------------------------
  reg inv_seen_q;
  wire inv_pulse = invalidate_all_i & ~inv_seen_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) inv_seen_q <= 1'b0;
    else         inv_seen_q <= invalidate_all_i;
  end

  // -----------------------------
  // I$ core arrays + PLRU
  // -----------------------------
  reg               core_req;
  reg  [63:0]       core_addr;
  wire              core_gnt;
  wire              core_rvalid;
  wire [63:0]       core_rdata;

  wire [INDEX_W-1:0]    index_core    = core_addr[11:6];
  wire [WORD_OFF_W-1:0] word_off_core = core_addr[5:3];
  wire [TAG_W-1:0]      tag_core      = core_addr[63:12];

  wire [63:0]           arr_rdata_sel;
  wire [TAG_W-1:0]      arr_tag_sel;
  wire                  arr_valid_sel;
  wire [8*64-1:0]       arr_rdata_way_flat;
  wire [8*TAG_W-1:0]    arr_tag_way_flat;
  wire [7:0]            arr_valid_way;

  reg  [INDEX_W-1:0]    arr_index;
  reg  [2:0]            arr_word_sel;
  reg  [2:0]            arr_way_sel;
  reg                   arr_write_en;
  reg                   arr_set_valid;
  reg  [TAG_W-1:0]      arr_tag_in;
  reg  [63:0]           arr_wdata;

  localparam [1:0] S_IDLE       = 2'd0,
                   S_REF_REQ    = 2'd1,
                   S_REF_STREAM = 2'd2,
                   S_RESP       = 2'd3;

  reg [1:0] state, state_n;

  cpu64_l1i_arrays u_arrays (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    // Apply invalidate exactly once, only when RE is idle.
    .invalidate_all_i ((state == S_IDLE) ? inv_pulse : 1'b0),
    .index_i          (arr_index),
    .word_sel_i       (arr_word_sel),
    .way_sel_i        (arr_way_sel),
    .write_en_i       (arr_write_en),
    .set_valid_i      (arr_set_valid),
    .tag_in_i         (arr_tag_in),
    .wdata_i          (arr_wdata),
    .rdata_selected_o (arr_rdata_sel),
    .tag_selected_o   (arr_tag_sel),
    .valid_selected_o (arr_valid_sel),
    .rdata_way_flat_o (arr_rdata_way_flat),
    .tag_way_flat_o   (arr_tag_way_flat),
    .valid_way_o      (arr_valid_way)
  );

  // PLRU
  wire [2:0] victim_way;
  reg        plru_access_q;
  reg [2:0]  plru_used_way_q;

  cpu64_l1i_plru u_plru (
    .clk_i     (clk_i),
    .rst_ni    (rst_ni),
    .set_i     (index_core),
    .access_i  (plru_access_q),
    .used_way_i(plru_used_way_q),
    .valid_i   (arr_valid_way),
    .victim_o  (victim_way)
  );

  // -----------------------------
  // Hit detection across 8 ways
  // -----------------------------
  reg        hit_core;        // valid && tag
  reg [2:0]  hit_way_core;

  reg        tag_hit_core;    // tag-only (for FE direct read)
  reg [2:0]  tag_hit_way_core;

  integer i;
  reg [TAG_W-1:0] tag_slice;

  always @(*) begin
    hit_core         = 1'b0;
    hit_way_core     = 3'd0;
    tag_hit_core     = 1'b0;
    tag_hit_way_core = 3'd0;

    for (i = 0; i < WAYS; i = i + 1) begin
      tag_slice = arr_tag_way_flat[((i+1)*TAG_W-1) -: TAG_W];

      if (!tag_hit_core && (tag_slice == tag_core)) begin
        tag_hit_core     = 1'b1;
        tag_hit_way_core = i[2:0];
      end

      if (!hit_core && arr_valid_way[i] && (tag_slice == tag_core)) begin
        hit_core     = 1'b1;
        hit_way_core = i[2:0];
      end
    end
  end

  // -----------------------------
  // Refill FSM (read-only, STREAMING)
  // -----------------------------
  reg [2:0]            beat_q, beat_n;
  reg [INDEX_W-1:0]    pend_index_q, pend_index_n;
  reg [TAG_W-1:0]      pend_tag_q,   pend_tag_n;
  reg [WORD_OFF_W-1:0] pend_word_q,  pend_word_n;
  reg [2:0]            pend_victim_q,pend_victim_n;

  reg        core_gnt_n, core_rvalid_n;
  reg [63:0] core_rdata_n;
  reg        plru_access_n;
  reg [2:0]  plru_used_way_n;

  reg        req_n, we_n;
  reg [7:0]  be_n;
  reg [63:0] addr_n, wdata_n;

  // Return tag split into line base + word offset
  reg [63:0] ret_addr_q,     ret_addr_n;     // line base (...[5:0]=0)
  reg [2:0]  ret_word_off_q, ret_word_off_n; // which 8B word in the line

  always @(*) begin
    state_n        = state;
    beat_n         = beat_q;
    pend_index_n   = pend_index_q;
    pend_tag_n     = pend_tag_q;
    pend_word_n    = pend_word_q;
    pend_victim_n  = pend_victim_q;

    core_gnt_n     = 1'b0;
    core_rvalid_n  = 1'b0;
    core_rdata_n   = 64'd0;

    req_n          = 1'b0;
    we_n           = 1'b0;
    be_n           = 8'h00;
    addr_n         = 64'd0;
    wdata_n        = 64'd0;

    ret_addr_n      = ret_addr_q;
    ret_word_off_n  = ret_word_off_q;

    // Array defaults (pointed by core_addr)
    arr_index      = index_core;
    arr_word_sel   = word_off_core;
    arr_way_sel    = hit_core ? hit_way_core : tag_hit_way_core;
    arr_write_en   = 1'b0;
    arr_set_valid  = 1'b0;
    arr_tag_in     = {TAG_W{1'b0}};
    arr_wdata      = 64'd0;

    plru_access_n   = 1'b0;
    plru_used_way_n = 3'd0;

    case (state)
      // Allow hit/miss selection unconditionally (invalidate is edge-pulsed)
      S_IDLE: begin
        if (core_req && hit_core) begin
          core_gnt_n      = 1'b1;
          plru_access_n   = 1'b1;
          plru_used_way_n = hit_way_core;

          core_rvalid_n   = 1'b1;
          core_rdata_n    = arr_rdata_sel;

          ret_addr_n      = {core_addr[63:6], 6'b0};
          ret_word_off_n  = core_addr[5:3];
        end else if (core_req && !hit_core) begin
          // MISS path - tag doesn't match OR line invalid
          pend_index_n  = index_core;
          pend_tag_n    = tag_core;
          pend_word_n   = word_off_core;
          pend_victim_n = victim_way;

          req_n         = 1'b1;
          we_n          = 1'b0;
          be_n          = 8'h00;
          addr_n        = {tag_core, index_core, 6'b0}; // line base

          beat_n        = 3'd0;
          state_n       = S_REF_REQ;
          core_gnt_n    = 1'b1;
        end
      end

      S_REF_REQ: begin
        req_n  = 1'b1;
        we_n   = 1'b0;
        be_n   = 8'h00;
        addr_n = {pend_tag_q, pend_index_q, 6'b0};
        if (gnt_i) begin
          state_n = S_REF_STREAM;
        end
      end

      S_REF_STREAM: begin
        if (rvalid_i) begin
          arr_index     = pend_index_q;
          arr_word_sel  = beat_q;                 // word offset == beat number
          arr_way_sel   = pend_victim_q;
          arr_write_en  = 1'b1;
          arr_set_valid = (beat_q == 3'd7);
          arr_tag_in    = pend_tag_q;
          arr_wdata     = rdata_i;

          if (beat_q == 3'd7) begin
            state_n = S_RESP; // done; full line present
          end else begin
            beat_n  = beat_q + 3'd1;
            state_n = S_REF_STREAM;
          end
        end
      end

      S_RESP: begin
        arr_index       = pend_index_q;
        arr_word_sel    = pend_word_q;
        arr_way_sel     = pend_victim_q;

        plru_access_n   = 1'b1;
        plru_used_way_n = pend_victim_q;

        core_rvalid_n   = 1'b1;
        core_rdata_n    = arr_rdata_sel;

        ret_addr_n      = {pend_tag_q, pend_index_q, 6'b0};
        ret_word_off_n  = pend_word_q;

        state_n         = S_IDLE;
      end

      default: state_n = S_IDLE;
    endcase
  end

  // Sequential: refill state + mem side regs
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state         <= S_IDLE;
      beat_q        <= 3'd0;
      pend_index_q  <= {INDEX_W{1'b0}};
      pend_tag_q    <= {TAG_W{1'b0}};
      pend_word_q   <= {WORD_OFF_W{1'b0}};
      pend_victim_q <= 3'd0;

      req_o   <= 1'b0;
      we_o    <= 1'b0;
      be_o    <= 8'h00;
      addr_o  <= 64'd0;
      wdata_o <= 64'd0;

      ret_addr_q      <= 64'd0;
      ret_word_off_q  <= 3'd0;
    end else begin
      state         <= state_n;
      beat_q        <= beat_n;
      pend_index_q  <= pend_index_n;
      pend_tag_q    <= pend_tag_n;
      pend_word_q   <= pend_word_n;
      pend_victim_q <= pend_victim_n;

      req_o   <= req_n;
      we_o    <= we_n;
      be_o    <= be_n;
      addr_o  <= addr_n;
      wdata_o <= wdata_n;

      ret_addr_q      <= ret_addr_n;
      ret_word_off_q  <= ret_word_off_n;
    end
  end

  // PLRU update
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      plru_access_q   <= 1'b0;
      plru_used_way_q <= 3'd0;
    end else begin
      plru_access_q   <= plru_access_n;
      plru_used_way_q <= plru_used_way_n;
    end
  end

  // -----------------------------
  // Simplified Front-end FSM (32-bit fetch only)
  // -----------------------------
  localparam [1:0] FE_IDLE  = 2'd0,
                   FE_WAIT  = 2'd1,
                   FE_RESP  = 2'd2;

  reg [1:0]  fe_q, fe_n;
  reg [63:0] req_pc_q;
  reg        req_word_sel_q;  // Saved word selector for current request

  // Registered, glitch-free public outputs
  reg        instr_valid_q;
  reg [31:0] instr_q;

  // Word address for cache lookup
  wire [63:0] word_addr = {req_pc_q[63:3], 3'b000};

  // Direct-read ready condition
  wire fe_can_direct = (state == S_IDLE);
  wire [63:0] direct_data = arr_rdata_sel;
  wire data_ready = (fe_q == FE_WAIT) && fe_can_direct && hit_core;  // Use hit_core, not tag_hit_core!

  // Extract 32-bit instruction from 64-bit word based on saved word selector
  // req_word_sel_q=0 -> lower word [31:0], req_word_sel_q=1 -> upper word [63:32]
  reg [31:0] resp_instr_c;
  always @(*) begin
    if (req_word_sel_q)
      resp_instr_c = direct_data[63:32];
    else
      resp_instr_c = direct_data[31:0];
  end

  // FE combinational FSM
  always @(*) begin
    fe_n        = fe_q;
    core_req    = 1'b0;
    core_addr   = 64'd0;
    fetch_gnt_o = 1'b0;

    case (fe_q)
      FE_IDLE: begin
        if (fetch_req_i) begin
          fetch_gnt_o = 1'b1;
          core_req    = 1'b1;
          core_addr   = {fetch_pc_i[63:3], 3'b000};  // Use incoming PC directly
          fe_n        = FE_WAIT;
        end
      end

      FE_WAIT: begin
        core_req  = 1'b1;
        core_addr = word_addr;  // Continue using saved PC

        if (data_ready) begin
          fe_n = FE_RESP;
        end
      end

      FE_RESP: begin
        core_addr = word_addr;  // Keep using saved PC for instruction extraction
        fe_n = FE_IDLE;  // Don't accept new requests until we return to IDLE
      end

      default: fe_n = FE_IDLE;
    endcase
  end

  // FE sequential
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fe_q            <= FE_IDLE;
      req_pc_q        <= 64'd0;
      req_word_sel_q  <= 1'b0;
      instr_valid_q   <= 1'b0;
      instr_q         <= 32'h0;
    end else begin
      fe_q <= fe_n;

      // Default: no instruction this cycle unless FE_RESP
      instr_valid_q <= 1'b0;

      // Latch PC and word selector when accepting new request in FE_IDLE
      if (fe_q == FE_IDLE && fetch_req_i) begin
        req_pc_q       <= fetch_pc_i;
        req_word_sel_q <= fetch_pc_i[2];
      end

      // Register final output
      if (fe_q == FE_RESP) begin
        instr_valid_q <= 1'b1;
        instr_q       <= resp_instr_c;
      end

      // Flush on invalidate
      if (inv_pulse) begin
        instr_valid_q <= 1'b0;
        instr_q       <= 32'h0;
      end
    end
  end

  // Map core_* registered outputs + return tags
  reg [63:0] core_rdata_q;
  reg        core_gnt_q, core_rvalid_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      core_gnt_q     <= 1'b0;
      core_rvalid_q  <= 1'b0;
      core_rdata_q   <= 64'd0;
    end else begin
      core_gnt_q     <= core_gnt_n;
      core_rvalid_q  <= core_rvalid_n;
      core_rdata_q   <= core_rdata_n;
    end
  end

  assign core_gnt    = core_gnt_q;
  assign core_rvalid = core_rvalid_q;
  assign core_rdata  = core_rdata_q;

  // Drive public outputs from registered versions
  always @(*) begin
    instr_valid_o = instr_valid_q;
    instr_o       = instr_q;
  end

// ============================================================
// COMPACT MONITOR (minimal noise; stall warning optional)
// ============================================================
`ifdef ICACHE_DBG
  `ifndef ICACHE_MON_EVERY
    `define ICACHE_MON_EVERY 0      // 0 = no periodic prints
  `endif
  `ifndef ICACHE_STALL_WARN
    `define ICACHE_STALL_WARN 2048  // cycles in same state before warning
  `endif

  function [79*8-1:0] fe_name;
    input [1:0] s;
    begin
      case (s)
        2'd0: fe_name = "FE_IDLE";
        2'd1: fe_name = "FE_WAIT";
        2'd2: fe_name = "FE_RESP";
        default: fe_name = "FE_??? ";
      endcase
    end
  endfunction

  function [63*8-1:0] re_name;
    input [1:0] s;
    begin
      case (s)
        2'd0: re_name = "S_IDLE      ";
        2'd1: re_name = "S_REF_REQ   ";
        2'd2: re_name = "S_REF_STREAM";
        2'd3: re_name = "S_RESP      ";
        default: re_name = "S_???       ";
      endcase
    end
  endfunction

  reg [31:0] dbg_cycle_q;
  reg [15:0] dbg_stall_q;
  reg [1:0]  fe_prev_q;
  reg [1:0]  re_prev_q;

  wire state_changed = (fe_prev_q != fe_q) || (re_prev_q != state);
  wire periodic_tick = (`ICACHE_MON_EVERY != 0) &&
                       (dbg_cycle_q % `ICACHE_MON_EVERY == 0);
  wire stall_warn    = (dbg_stall_q == `ICACHE_STALL_WARN);

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dbg_cycle_q <= 32'd0;
      dbg_stall_q <= 16'd0;
      fe_prev_q   <= FE_IDLE;
      re_prev_q   <= S_IDLE;
    end else begin
      dbg_cycle_q <= dbg_cycle_q + 32'd1;
      dbg_stall_q <= state_changed ? 16'd0 : dbg_stall_q + 16'd1;

      if (state_changed || periodic_tick || stall_warn) begin
        if (stall_warn) begin
          $display("[%0t] MON: STALL %0d cyc in RE=%s FE=%s  req_pc=%016h word_off=%0d  core_req=%0d",
            $time, `ICACHE_STALL_WARN, re_name(state), fe_name(fe_q),
            req_pc_q, req_pc_q[5:3], core_req);
        end else begin
          $display("[%0t] MON: RE=%s FE=%s  req_pc=%016h word_off=%0d instr_valid=%0d",
            $time, re_name(state), fe_name(fe_q),
            req_pc_q, req_pc_q[5:3], instr_valid_q);
        end
      end

      fe_prev_q <= fe_q;
      re_prev_q <= state;
      
      // Debug instruction delivery
      if (instr_valid_o) begin
        $display("[%0t] ICACHE DELIVER: PC=%016h word_sel=%0d word_off=%0d arr_data=%016h instr=%08h",
          $time, req_pc_q, req_word_sel_q, word_off_core, arr_rdata_sel, instr_o);
      end
    end
  end

  // Request/Response logging to file
  integer icache_log_fd;
  integer cycle_count;
  
  initial begin
    icache_log_fd = $fopen("obj_dir/icache_req_resp.txt", "w");
    cycle_count = 0;
    $fdisplay(icache_log_fd, "==============================================");
    $fdisplay(icache_log_fd, "  ICache Request/Response Transaction Log");
    $fdisplay(icache_log_fd, "==============================================");
    $fdisplay(icache_log_fd, "");
    $fdisplay(icache_log_fd, "Legend:");
    $fdisplay(icache_log_fd, "  REQ: Fetch unit makes request (fetch_req_i=1)");
    $fdisplay(icache_log_fd, "  GNT: ICache grants request (fetch_gnt_o=1)");
    $fdisplay(icache_log_fd, "  RSP: ICache delivers instruction (instr_valid_o=1)");
    $fdisplay(icache_log_fd, "");
    $fdisplay(icache_log_fd, "Cycle | Time(ns) | Event | PC               | Instr    | State    | Hit | Notes");
    $fdisplay(icache_log_fd, "------+----------+-------+------------------+----------+----------+-----+------------------");
  end

  always @(posedge clk_i) begin
    if (rst_ni) begin
      cycle_count = cycle_count + 1;
    end
    
    // Log fetch requests
    if (fetch_req_i && fe_q == FE_IDLE) begin
      $fdisplay(icache_log_fd, "%5d | %8.1f | REQ   | 0x%016h |          | %s | %0d   | New request accepted",
                cycle_count, $realtime, fetch_pc_i, fe_name(fe_q), hit_core);
    end
    
    // Log grants
    if (fetch_gnt_o) begin
      $fdisplay(icache_log_fd, "%5d | %8.1f | GNT   | 0x%016h |          | %s |     | Grant issued",
                cycle_count, $realtime, fetch_pc_i, fe_name(fe_q));
    end
    
    // Log responses (instruction delivery)
    if (instr_valid_o) begin
      $fdisplay(icache_log_fd, "%5d | %8.1f | RSP   | 0x%016h | 0x%08h | %s | %0d   | Instruction delivered",
                cycle_count, $realtime, req_pc_q, instr_o, fe_name(fe_q), hit_core);
    end
    
    // Log state transitions
    if (fe_prev_q != fe_q) begin
      $fdisplay(icache_log_fd, "%5d | %8.1f | STATE |                  |          | %s->%s |     | FSM transition",
                cycle_count, $realtime, fe_name(fe_prev_q), fe_name(fe_q));
    end
  end

  final begin
    if (icache_log_fd) begin
      $fdisplay(icache_log_fd, "------+----------+-------+------------------+----------+----------+-----+------------------");
      $fdisplay(icache_log_fd, "");
      $fdisplay(icache_log_fd, "End of ICache request/response log - Total cycles: %0d", cycle_count);
      $fclose(icache_log_fd);
    end
  end
`endif

endmodule
