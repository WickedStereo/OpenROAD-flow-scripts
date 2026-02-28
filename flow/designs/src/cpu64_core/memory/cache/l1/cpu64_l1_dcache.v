// cpu64_l1_dcache.v - Top-level Option A L1 D$ wrapper (scaffold)
// Includes LR/SC (Load-Reserved/Store-Conditional) support with reservation tracking
`timescale 1ns/1ps

module cpu64_l1_dcache (
	input              clk_i,
	input              rst_ni,

	// Optional maintenance
	input              invalidate_all_i,

	// Back-invalidate from L2 → L1 (inclusive)
	input              binv_req_i,
	input      [63:0]  binv_addr_i,
	output reg         binv_ack_o,

	// CPU-side (slave-like OBI style)
	input              req_i,
	input              we_i,
	input       [7:0]  be_i,
	input      [63:0]  addr_i,
	input      [63:0]  wdata_i,
	output reg         gnt_o,
	output reg         rvalid_o,
	output reg [63:0]  rdata_o,
	// Atomic operation inputs
	input              amo_i,          // Atomic operation flag (excludes LR/SC)
	input              lr_i,           // Load-Reserved operation
	input              sc_i,           // Store-Conditional operation
	input       [4:0]  amo_op_i,       // Atomic operation type
	input              amo_word_i,     // Atomic word operation flag

	// Memory-side (host-like)
	output reg         req_o,
	output reg         we_o,
	output reg  [7:0]  be_o,
	output reg [63:0]  addr_o,
	output reg [63:0]  wdata_o,
	input              gnt_i,
	input              rvalid_i,
	input      [63:0]  rdata_i
);

	// Fixed configuration parameters
	localparam integer ADDR_W          = 64;
	localparam integer DATA_W          = 64;
	localparam integer LINE_BYTES      = 64;
	localparam integer WORDS_PER_LINE  = 8;   // 64B / 8B
	localparam integer SETS            = 64;  // 32KiB / (64B * 8 ways)
	localparam integer WAYS            = 8;
	localparam integer BYTE_OFF_W      = 3;   // addr[2:0]
	localparam integer WORD_OFF_W      = 3;   // addr[5:3]
	localparam integer LINE_OFF_W      = 6;   // addr[5:0]
	localparam integer INDEX_W         = 6;   // addr[11:6]
	localparam integer TAG_W           = 52;  // addr[63:12]

	// Address decode
	wire [INDEX_W-1:0] index  = addr_i[11:6];
	wire [WORD_OFF_W-1:0] word_off = addr_i[5:3];
	wire [TAG_W-1:0]    tag    = addr_i[63:12];

	// Array interfaces (scaffold wiring)
	wire [63:0]  arr_rdata_sel;
	wire [51:0]  arr_tag_sel;
	wire         arr_valid_sel;
	wire         arr_dirty_sel;
	wire [8*64-1:0] arr_rdata_way_flat;
	wire [8*52-1:0] arr_tag_way_flat;
	wire [7:0]      arr_valid_way;
	wire [7:0]      arr_dirty_way;

cpu64_l1_arrays u_arrays (
		.clk_i              (clk_i),
		.rst_ni             (rst_ni),
		.invalidate_all_i   (state == S_IDLE ? invalidate_all_i : 1'b0),
		.index_i            (arr_index_w),
		.word_sel_i         (arr_word_sel_w),
		.way_sel_i          (arr_way_sel_w),
		.write_en_i         (arr_write_en),
		.set_valid_i        (arr_set_valid),
		.set_dirty_i        (arr_set_dirty),
		.be_i               (arr_be),
		.tag_in_i           (arr_tag_in),
		.wdata_i            (arr_wdata),
		.rdata_selected_o   (arr_rdata_sel),
		.tag_selected_o     (arr_tag_sel),
		.valid_selected_o   (arr_valid_sel),
		.dirty_selected_o   (arr_dirty_sel),
		.rdata_way_flat_o   (arr_rdata_way_flat),
		.tag_way_flat_o     (arr_tag_way_flat),
		.valid_way_o        (arr_valid_way),
		.dirty_way_o        (arr_dirty_way)
	);

	// PLRU
	wire [2:0] victim_way;
	reg        plru_access_q;
	reg [2:0]  plru_used_way_q;
	cpu64_l1_plru u_plru (
		.clk_i     (clk_i),
		.rst_ni    (rst_ni),
		.set_i     (index),
		.access_i  (plru_access_q),
		.used_way_i(plru_used_way_q),
		.valid_i   (arr_valid_way),
		.victim_o  (victim_way)
	);

	// Verilog-2001 friendly: use indexed part-selects directly; derive hit_data_word when hit_way known
	wire [63:0] hit_data_word;
	assign hit_data_word = arr_rdata_way_flat[(((hit_way+1)*DATA_W)-1) -: DATA_W];

	// State and control for refill + writeback FSM
	localparam [2:0] S_IDLE = 3'd0,
	                 S_REF_REQ = 3'd1,
	                 S_REF_WAIT = 3'd2,
	                 S_WRITE_BEAT = 3'd3,
	                 S_RESP = 3'd4,
	                 S_WB_REQ = 3'd5,
	                 S_AMO_MODIFY = 3'd6,   // Atomic modify state
	                 S_AMO_WRITE = 3'd7;    // Atomic write state

	// Additional states for back-invalidate
	localparam [2:0] S_BINV_WB = 3'd5; // alias to S_WB_REQ timing
	// Reuse S_IDLE path to clear and ack when clean

	// "_q" suffix = registered (current) value; "_n" suffix = next-state value
	reg [2:0] state, state_n;                               // FSM state
	reg [2:0] beat_q, beat_n;                               // Refill/writeback beat counter
	reg [INDEX_W-1:0] pend_index_q, pend_index_n;           // Pending set index
	reg [TAG_W-1:0]   pend_tag_q, pend_tag_n;               // Pending tag
	reg [WORD_OFF_W-1:0] pend_word_q, pend_word_n;          // Pending word offset
	reg [2:0]         pend_victim_q, pend_victim_n;         // Pending victim way
	reg               pend_is_store_q, pend_is_store_n;     // Pending is store op
	reg [63:0]        pend_wdata_q, pend_wdata_n;           // Pending write data
	reg [7:0]         pend_be_q, pend_be_n;                 // Pending byte enables
	reg [TAG_W-1:0]   pend_evict_tag_q, pend_evict_tag_n;   // Pending evict tag
	reg [63:0]        rdata_beat_q, rdata_beat_n;           // Data beat for refill

	// Atomic operation registers
	reg               pend_is_amo_q, pend_is_amo_n;         // Pending is atomic op
	reg [4:0]         pend_amo_op_q, pend_amo_op_n;         // Pending AMO operation
	reg               pend_amo_word_q, pend_amo_word_n;     // Pending AMO word flag
	reg [63:0]        amo_old_value_q, amo_old_value_n;     // Old value for AMO (to return to CPU)

	// LR/SC reservation registers
	reg               resv_valid_q, resv_valid_n;           // Reservation valid flag
	reg [51:0]        resv_addr_q, resv_addr_n;             // Reservation address (tag + index = bits [63:12])
	reg               resv_word_q, resv_word_n;             // Reservation size: 1=word(32-bit), 0=double(64-bit)
	reg               pend_is_lr_q, pend_is_lr_n;           // Pending LR operation
	reg               pend_is_sc_q, pend_is_sc_n;           // Pending SC operation
	reg               sc_success_q, sc_success_n;           // SC result: 0=success, 1=failure

	// For back-invalidate
	reg [INDEX_W-1:0] binv_index;
	reg [TAG_W-1:0]   binv_tag;
	reg               binv_hit;
	reg [2:0]         binv_way;

	// Atomic ALU for RMW operations
	wire [63:0] amo_new_value;
	cpu64_atomic_alu u_atomic_alu (
		.amo_op_i      (pend_amo_op_q),
		.amo_word_i    (pend_amo_word_q),
		.old_value_i   (amo_old_value_q),
		.operand_i     (pend_wdata_q),
		.new_value_o   (amo_new_value)
	);

	// Array control registers
	// Note: Verilator UNOPTFLAT warning suppressed - these signals are part of a cache
	// hit detection path that appears as combinational loop in static analysis, but is
	// semantically correct: FSM state ensures no actual combinational loop occurs because
	// array reads for hit detection use parallel _flat outputs (independent of way_sel),
	// and specific way_sel only matters for writes which are FSM-state-controlled.
	/* verilator lint_off UNOPTFLAT */
	reg [2:0]         arr_word_sel;
	reg [2:0]         arr_way_sel;
	/* verilator lint_on UNOPTFLAT */
	reg               arr_write_en;
	reg               arr_set_valid;
	reg               arr_set_dirty;
	reg [7:0]         arr_be;
	reg [TAG_W-1:0]   arr_tag_in;
	reg [63:0]        arr_wdata;

	// Combinational array index selection (avoids UNOPTFLAT feedback warning)
	wire [INDEX_W-1:0] binv_index_w = binv_addr_i[11:6];
	wire [INDEX_W-1:0] arr_index_w =
		((state == S_WB_REQ) || (state == S_WRITE_BEAT) || (state == S_RESP)) ? pend_index_q :
		((state == S_IDLE) && binv_req_i ? binv_index_w : index);

	// Break combinational loop: use only state (registered signal) for mux control
	// During IDLE, array reads all ways in parallel, so specific way_sel doesn't affect
	// tag/valid outputs used for hit detection. word_off from address decode is independent.
	// NOTE: UNOPTFLAT warning suppressed below - mux uses state (registered) but Verilator
	// traces through arr_word_sel/arr_way_sel which can be assigned from array-derived
	// signals, creating apparent loop. FSM semantics guarantee no actual loop exists.
	/* verilator lint_off UNOPTFLAT */
	wire [2:0] arr_word_sel_w;
	wire [2:0] arr_way_sel_w;
	/* verilator lint_on UNOPTFLAT */
	
	// In S_IDLE, use word_off for word selection (from address decode)
	// For way selection, use arr_way_sel which is set by FSM for store-hits (to hit_way)
	// and defaults to 0 otherwise (reads don't write so don't care)
	assign arr_word_sel_w = (state == S_IDLE) ? word_off : arr_word_sel;
	assign arr_way_sel_w  = arr_way_sel;  // Always use FSM-computed way (not hardcoded 0)

	// Hit detection (combinational)
	reg hit;
	reg [2:0] hit_way;
	integer i;
	reg [TAG_W-1:0] tag_slice;
	always @(*) begin
		hit = 1'b0;
		hit_way = 3'd0;
		for (i = 0; i < WAYS; i = i + 1) begin
			tag_slice = arr_tag_way_flat[((i+1)*TAG_W-1) -: TAG_W];
			if (arr_valid_way[i] && (tag_slice == tag)) begin
				hit = 1'b1;
				hit_way = i[2:0];
			end
		end
	end

	// Next-state logic and outputs
	reg gnt_n, rvalid_n;
	reg [63:0] rdata_n;
	reg req_n, we_n;
	reg [7:0] be_n;
	reg [63:0] addr_n, wdata_n;
	reg        plru_access_n;
	reg [2:0]  plru_used_way_n;
	reg        binv_ack_n;

	always @(*) begin
		// Defaults
		state_n       = state;
		beat_n        = beat_q;
		pend_index_n  = pend_index_q;
		pend_tag_n    = pend_tag_q;
		pend_word_n   = pend_word_q;
		pend_victim_n = pend_victim_q;
		pend_is_store_n  = pend_is_store_q;
		pend_wdata_n     = pend_wdata_q;
		pend_be_n        = pend_be_q;
		pend_evict_tag_n = pend_evict_tag_q;
		rdata_beat_n  = rdata_beat_q;
		// Atomic defaults
		pend_is_amo_n    = pend_is_amo_q;
		pend_amo_op_n    = pend_amo_op_q;
		pend_amo_word_n  = pend_amo_word_q;
		amo_old_value_n  = amo_old_value_q;
		// LR/SC defaults
		resv_valid_n     = resv_valid_q;
		resv_addr_n      = resv_addr_q;
		resv_word_n      = resv_word_q;
		pend_is_lr_n     = pend_is_lr_q;
		pend_is_sc_n     = pend_is_sc_q;
		sc_success_n     = sc_success_q;

		gnt_n    = 1'b0;
		rvalid_n = 1'b0;
		rdata_n  = 64'd0;
		req_n    = 1'b0;
		we_n     = 1'b0;
		be_n     = 8'h00;
		addr_n   = 64'd0;
		wdata_n  = 64'd0;

		// Array control defaults
		// Fixed defaults to break combinational loop - parallel way readout doesn't depend on selection
		arr_word_sel  = 3'd0;
		arr_way_sel   = 3'd0;
		arr_write_en  = 1'b0;
		arr_set_valid = 1'b0;
		arr_set_dirty = 1'b0;
		arr_be        = 8'h00;
		arr_tag_in    = {TAG_W{1'b0}};
		arr_wdata     = 64'd0;

		plru_access_n   = 1'b0;
		plru_used_way_n = 3'd0;

		// Precompute back-invalidate decode
		binv_index = binv_addr_i[11:6];
		binv_tag   = binv_addr_i[63:12];
		binv_hit   = 1'b0;
		binv_way   = 3'd0;
		for (i = 0; i < WAYS; i = i + 1) begin
			tag_slice = arr_tag_way_flat[((i+1)*TAG_W-1) -: TAG_W];
			if (arr_valid_way[i] && (tag_slice == binv_tag)) begin
				binv_hit = 1'b1;
				binv_way = i[2:0];
			end
		end

		case (state)
		S_IDLE: begin
			// Handle back-invalidate when IDLE
			if (binv_req_i) begin
				if (binv_hit) begin
					arr_way_sel  = binv_way;  // Needed for write to correct way
					if (arr_dirty_way[binv_way]) begin
						// Writeback dirty line then clear and ack
						pend_index_n    = binv_index;
						pend_victim_n   = binv_way;
						pend_evict_tag_n= binv_tag;
						beat_n = 3'd0;
						state_n = S_WB_REQ; // reuse WB state
					end else begin
						// Clear valid/dirty via masked write, then ack
						arr_write_en  = 1'b1;
						arr_set_valid = 1'b0;
						arr_set_dirty = 1'b0;
						arr_be        = 8'h00;
						binv_ack_n    = 1'b1;
					end
				end else begin
					// Not present → immediate ack
					binv_ack_n = 1'b1;
				end
			// Block accepting new request while invalidate_all_i asserted
			end else if (invalidate_all_i) begin
				// Keep outputs idle; arrays will clear valids
			end else begin
			// ============ LR/SC Handling ============
			// LR (Load-Reserved) hit: Read data and set reservation
			if (req_i && lr_i && hit) begin
				gnt_n           = 1'b1;
				rvalid_n        = 1'b1;
				rdata_n         = hit_data_word;
				// Set reservation
				resv_valid_n    = 1'b1;
				resv_addr_n     = {tag, index};  // 52-bit tag + 6-bit index
				resv_word_n     = amo_word_i;
				// Clear any pending LR/SC state
				pend_is_lr_n    = 1'b0;
				pend_is_sc_n    = 1'b0;
				plru_access_n   = 1'b1;
				plru_used_way_n = hit_way;
`ifdef VERILATOR
				$display("[L1 LR HIT] addr=0x%016h data=0x%016h word=%0b setting reservation", addr_i, hit_data_word, amo_word_i);
`endif
			// LR (Load-Reserved) miss: Start refill
			end else if (req_i && lr_i && !hit) begin
				gnt_n           = 1'b1;
				pend_index_n    = index;
				pend_tag_n      = tag;
				pend_word_n     = word_off;
				pend_victim_n   = victim_way;
				pend_is_lr_n    = 1'b1;
				pend_is_sc_n    = 1'b0;
				pend_is_store_n = 1'b0;
				pend_amo_word_n = amo_word_i;
				pend_evict_tag_n = arr_tag_way_flat[((victim_way+1)*TAG_W-1) -: TAG_W];
				beat_n          = 3'd0;
				if (arr_valid_way[victim_way] && arr_dirty_way[victim_way]) begin
					state_n = S_WB_REQ;
				end else begin
					state_n = S_REF_REQ;
				end
`ifdef VERILATOR
				$display("[L1 LR MISS] addr=0x%016h starting refill", addr_i);
`endif
			// SC (Store-Conditional) hit: Check reservation
			end else if (req_i && sc_i && hit) begin
				gnt_n           = 1'b1;
				// Check reservation validity
				// Reservation matches if: valid, same address (tag+index), same size
				if (resv_valid_q && ({tag, index} == resv_addr_q) && (amo_word_i == resv_word_q)) begin
					// SC succeeds: Write data and return 0
					arr_word_sel  = word_off;
					arr_way_sel   = hit_way;
					arr_write_en  = 1'b1;
					arr_set_valid = 1'b1;
					arr_set_dirty = 1'b1;
					arr_be        = amo_word_i ? 8'h0F : 8'hFF;
					arr_tag_in    = tag;
					arr_wdata     = wdata_i;
					rvalid_n      = 1'b1;
					rdata_n       = 64'd0;  // Success
					// Clear reservation
					resv_valid_n  = 1'b0;
					plru_access_n   = 1'b1;
					plru_used_way_n = hit_way;
`ifdef VERILATOR
					$display("[L1 SC HIT SUCCESS] addr=0x%016h wdata=0x%016h, reservation valid, returning 0", addr_i, wdata_i);
`endif
				end else begin
					// SC fails: Return 1 without writing
					rvalid_n      = 1'b1;
					rdata_n       = 64'd1;  // Failure
					// Clear reservation on failure as well
					resv_valid_n  = 1'b0;
`ifdef VERILATOR
					$display("[L1 SC HIT FAIL] addr=0x%016h resv_valid=%0b resv_addr=0x%013h req_addr=0x%013h word_match=%0b", 
							 addr_i, resv_valid_q, resv_addr_q, {tag, index}, (amo_word_i == resv_word_q));
`endif
				end
			// SC (Store-Conditional) miss: Need to refill first to check/write
			end else if (req_i && sc_i && !hit) begin
				gnt_n           = 1'b1;
				pend_index_n    = index;
				pend_tag_n      = tag;
				pend_word_n     = word_off;
				pend_victim_n   = victim_way;
				pend_is_lr_n    = 1'b0;
				pend_is_sc_n    = 1'b1;
				pend_is_store_n = 1'b0;
				pend_amo_word_n = amo_word_i;
				pend_wdata_n    = wdata_i;
				// Pre-compute SC success based on current reservation
				// (reservation can't change during refill in single-core)
				if (resv_valid_q && ({tag, index} == resv_addr_q) && (amo_word_i == resv_word_q)) begin
					sc_success_n = 1'b1;  // Will succeed after refill
				end else begin
					sc_success_n = 1'b0;  // Will fail after refill
				end
				pend_evict_tag_n = arr_tag_way_flat[((victim_way+1)*TAG_W-1) -: TAG_W];
				beat_n          = 3'd0;
				if (arr_valid_way[victim_way] && arr_dirty_way[victim_way]) begin
					state_n = S_WB_REQ;
				end else begin
					state_n = S_REF_REQ;
				end
`ifdef VERILATOR
				$display("[L1 SC MISS] addr=0x%016h starting refill, pre-computed success=%0b", addr_i, sc_success_n);
`endif
			// ============ End LR/SC Handling ============
			// Atomic operation hit: Read-Modify-Write sequence
			end else if (req_i && amo_i && hit) begin
				gnt_n           = 1'b1;       // Accept atomic operation
				// Latch old value for return to CPU
				amo_old_value_n = hit_data_word;
				// Store atomic metadata
				pend_is_amo_n   = 1'b1;
				pend_amo_op_n   = amo_op_i;
				pend_amo_word_n = amo_word_i;
				pend_wdata_n    = wdata_i;    // operand (rs2 value)
				pend_index_n    = index;
				pend_tag_n      = tag;
				pend_word_n     = word_off;
				pend_victim_n   = hit_way;    // Remember which way for AMO write
				// Clear reservation if AMO writes to reserved address
				if (resv_valid_q && ({tag, index} == resv_addr_q)) begin
					resv_valid_n = 1'b0;
				end
				// Go to modify state to compute new value
				state_n         = S_AMO_MODIFY;
				plru_access_n   = 1'b1;
				plru_used_way_n = hit_way;
			// Atomic operation miss: Start refill first
			end else if (req_i && amo_i && !hit) begin
				gnt_n           = 1'b1;       // GRANT on miss - accept the transaction
				pend_index_n    = index;
				pend_tag_n      = tag;
				pend_word_n     = word_off;
				pend_victim_n   = victim_way;
				pend_is_amo_n   = 1'b1;      // Mark as atomic operation
				pend_amo_op_n   = amo_op_i;
				pend_amo_word_n = amo_word_i;
				pend_wdata_n    = wdata_i;    // Store operand
				// Clear reservation if AMO writes to reserved address
				if (resv_valid_q && ({tag, index} == resv_addr_q)) begin
					resv_valid_n = 1'b0;
				end
				pend_evict_tag_n = arr_tag_way_flat[((victim_way+1)*TAG_W-1) -: TAG_W];
				beat_n          = 3'd0;
				if (arr_valid_way[victim_way] && arr_dirty_way[victim_way]) begin
					state_n = S_WB_REQ;
				end else begin
					state_n = S_REF_REQ;
				end
			// Read-hit: 1-cycle response
			end else if (req_i && !we_i && hit) begin
				gnt_n    = 1'b1;
				rvalid_n = 1'b1;
				rdata_n  = hit_data_word;
				plru_access_n   = 1'b1;
				plru_used_way_n = hit_way;
			end else if (req_i && we_i && hit) begin
				// Write hit with BE merge
				gnt_n    = 1'b1;      // accept write
					// Program array write for selected way/word
				arr_word_sel  = word_off;
				arr_way_sel   = hit_way;
				arr_write_en  = 1'b1;
				arr_set_valid = 1'b1;
				arr_set_dirty = 1'b1;
				arr_be        = be_i;
				arr_tag_in    = tag;
				arr_wdata     = wdata_i;
				// Clear reservation if store writes to reserved address
				if (resv_valid_q && ({tag, index} == resv_addr_q)) begin
					resv_valid_n = 1'b0;
				end
				plru_access_n   = 1'b1;
				plru_used_way_n = hit_way;
`ifdef VERILATOR
				$display("[L1 STORE HIT] index=%0d way=%0d word=%0d addr=0x%016h tag=0x%h wdata=0x%016h be=0x%02h",
				         index, hit_way, word_off, addr_i, tag, wdata_i, be_i);
`endif
			end else if (req_i && !we_i && !hit) begin
				// Start clean refill miss
				gnt_n         = 1'b1;       // GRANT on miss - accept the transaction
				pend_index_n  = index;
				pend_tag_n    = tag;
				pend_word_n   = word_off;
				pend_victim_n = victim_way;
				pend_is_store_n = 1'b0;
				pend_evict_tag_n = arr_tag_way_flat[((victim_way+1)*TAG_W-1) -: TAG_W];
				beat_n        = 3'd0;
				if (arr_valid_way[victim_way] && arr_dirty_way[victim_way]) begin
					state_n = S_WB_REQ;
				end else begin
					state_n = S_REF_REQ;
				end
			end else if (req_i && we_i && !hit) begin
				// Start store-miss RFO (read for ownership)
				gnt_n          = 1'b1;       // GRANT on miss - accept the transaction
				pend_index_n   = index;
				pend_tag_n     = tag;
				pend_word_n    = word_off;
				pend_victim_n  = victim_way;
				pend_is_store_n= 1'b1;
				pend_wdata_n   = wdata_i;
				pend_be_n      = be_i;
				pend_evict_tag_n = arr_tag_way_flat[((victim_way+1)*TAG_W-1) -: TAG_W];
				beat_n         = 3'd0;
`ifdef VERILATOR
				$display("[L1 STORE MISS] index=%0d victim_way=%0d word=%0d addr=0x%016h tag=0x%h wdata=0x%016h be=0x%02h",
				         index, victim_way, word_off, addr_i, tag, wdata_i, be_i);
`endif
				if (arr_valid_way[victim_way] && arr_dirty_way[victim_way]) begin
					state_n = S_WB_REQ;
				end else begin
					state_n = S_REF_REQ;
				end
			end
			end
		end

		S_REF_REQ: begin
			// Issue read beat request (serialized)
			req_n  = 1'b1;
			we_n   = 1'b0;
			be_n   = 8'h00;
			addr_n = {pend_tag_q, pend_index_q, 6'b0} + {58'd0, beat_q, 3'd0};
			if (gnt_i) begin
				state_n = S_REF_WAIT;
			end
		end

		S_REF_WAIT: begin
			// Wait for data for this beat
			if (rvalid_i) begin
				rdata_beat_n = rdata_i;
				state_n = S_WRITE_BEAT;
			end
		end

		S_WB_REQ: begin
			// Issue writeback of victim line, full-line beats
			// Select victim word for current beat
			arr_word_sel = beat_q;
			arr_way_sel  = pend_victim_q;
			req_n  = 1'b1;
			we_n   = 1'b1;
			be_n   = 8'hFF;
			addr_n = {pend_evict_tag_q, pend_index_q, 6'b0} + {58'd0, beat_q, 3'd0};
			wdata_n= arr_rdata_way_flat[((pend_victim_q+1)*DATA_W-1) -: DATA_W];
			if (gnt_i) begin
				if (beat_q == 3'd7) begin
					beat_n  = 3'd0;
					// If WB came from back-invalidate (no pending target tag), just clear+ack and go IDLE
					if (pend_tag_q == {TAG_W{1'b0}}) begin
						// Clear the line
						arr_way_sel   = pend_victim_q;
						arr_write_en  = 1'b1;
						arr_set_valid = 1'b0;
						arr_set_dirty = 1'b0;
						arr_be        = 8'h00;
						binv_ack_n    = 1'b1;
						state_n       = S_IDLE;
					end else begin
						state_n = S_REF_REQ; // proceed to refill for normal miss path
					end
				end else begin
					beat_n  = beat_q + 3'd1;
					state_n = S_WB_REQ;
				end
			end
		end

		S_WRITE_BEAT: begin
			// Write received beat into arrays
			// index driven by arr_index_w wire
			arr_word_sel  = beat_q;
			arr_way_sel   = pend_victim_q;
			arr_write_en  = 1'b1;
			arr_set_valid = (beat_q == 3'd7);
			arr_set_dirty = 1'b0;
			arr_be        = 8'hFF;
			arr_tag_in    = pend_tag_q;
			arr_wdata     = rdata_beat_q;
			if (beat_q == 3'd7) begin
				// Clear reservation if victim line contains the reserved address
				// (the line is about to be replaced with new data)
				if (resv_valid_q && ({pend_evict_tag_q, pend_index_q} == resv_addr_q)) begin
					resv_valid_n = 1'b0;
				end
				state_n = S_RESP;
			end else begin
				beat_n  = beat_q + 3'd1;
				state_n = S_REF_REQ;
			end
		end

		S_RESP: begin
			// Completion after full line refilled
			// index driven by arr_index_w wire
			arr_word_sel = pend_word_q;
			arr_way_sel  = pend_victim_q;
			plru_access_n   = 1'b1;
			plru_used_way_n = pend_victim_q;
			if (pend_is_lr_q) begin
				// LR miss completion: Return data from refilled line, set reservation
				rvalid_n     = 1'b1;
				rdata_n      = arr_rdata_sel;
				// Set reservation
				resv_valid_n = 1'b1;
				resv_addr_n  = {pend_tag_q, pend_index_q};
				resv_word_n  = pend_amo_word_q;
				pend_is_lr_n = 1'b0;
				state_n      = S_IDLE;
`ifdef VERILATOR
				$display("[L1 LR MISS COMPLETE] data=0x%016h setting reservation", arr_rdata_sel);
`endif
			end else if (pend_is_sc_q) begin
				// SC miss completion: Conditionally write based on pre-computed success
				if (sc_success_q) begin
					// Write data
					arr_write_en  = 1'b1;
					arr_set_valid = 1'b1;
					arr_set_dirty = 1'b1;
					arr_be        = pend_amo_word_q ? 8'h0F : 8'hFF;
					arr_tag_in    = pend_tag_q;
					arr_wdata     = pend_wdata_q;
					rvalid_n      = 1'b1;
					rdata_n       = 64'd0;  // Success
`ifdef VERILATOR
					$display("[L1 SC MISS COMPLETE SUCCESS] wrote data=0x%016h", pend_wdata_q);
`endif
				end else begin
					// Just return failure without writing
					rvalid_n      = 1'b1;
					rdata_n       = 64'd1;  // Failure
`ifdef VERILATOR
					$display("[L1 SC MISS COMPLETE FAIL] returning 1");
`endif
				end
				// Clear reservation
				resv_valid_n = 1'b0;
				pend_is_sc_n = 1'b0;
				state_n      = S_IDLE;
			end else if (pend_is_amo_q) begin
				// AMO miss completion: latch old value from refilled line, then modify
				amo_old_value_n = arr_rdata_sel;
				state_n = S_AMO_MODIFY;
			end else if (pend_is_store_q) begin
				// Perform BE-merge store into freshly refilled line, set dirty
				// Note: No grant here - store was already granted when miss was accepted in S_IDLE
				arr_write_en  = 1'b1;
				arr_set_valid = 1'b1; // keep valid set
				arr_set_dirty = 1'b1;
				arr_be        = pend_be_q;
				arr_tag_in    = pend_tag_q;
				arr_wdata     = pend_wdata_q;
				// gnt_n already 0 by default - store was accepted on initial miss grant
				rvalid_n      = 1'b0;
				state_n       = S_IDLE;
`ifdef VERILATOR
				$display("[L1 STORE MISS COMPLETE] index=%0d way=%0d word=%0d tag=0x%h wdata=0x%016h be=0x%02h",
				         pend_index_q, pend_victim_q, pend_word_q, pend_tag_q, pend_wdata_q, pend_be_q);
`endif
			end else begin
				// Read miss completion
				rvalid_n = 1'b1;
				rdata_n  = arr_rdata_sel;
				state_n  = S_IDLE;
			end
		end

		S_AMO_MODIFY: begin
			// Compute new value using atomic ALU (amo_new_value wire already computed)
			// Transition to write state
			state_n = S_AMO_WRITE;
		end

		S_AMO_WRITE: begin
			// Write new value back to cache array
			// index driven by arr_index_w wire (uses pend_index_q)
			arr_word_sel  = pend_word_q;
			arr_way_sel   = pend_victim_q;
			arr_write_en  = 1'b1;
			arr_set_valid = 1'b1;
			arr_set_dirty = 1'b1;
			arr_be        = (pend_amo_word_q) ? 8'h0F : 8'hFF;  // Lower 32 bits for word operations
			arr_tag_in    = pend_tag_q;
			arr_wdata     = amo_new_value;
			plru_access_n   = 1'b1;
			plru_used_way_n = pend_victim_q;
			// Return old value to CPU
			rvalid_n = 1'b1;
			rdata_n  = amo_old_value_q;
			// Clear AMO pending flag
			pend_is_amo_n = 1'b0;
			state_n  = S_IDLE;
`ifdef VERILATOR
			$display("[L1 S_AMO_WRITE] Setting rvalid_n=1, rdata_n=0x%016h (amo_old_value_q)", amo_old_value_q);
`endif
		end

		default: begin
			state_n = S_IDLE;
		end
		endcase
	end

	// Sequential state
	always @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni) begin
			state <= S_IDLE;
			beat_q <= 3'd0;
			pend_index_q <= {INDEX_W{1'b0}};
			pend_tag_q <= {TAG_W{1'b0}};
			pend_word_q <= {WORD_OFF_W{1'b0}};
			pend_victim_q <= 3'd0;
			rdata_beat_q <= 64'd0;
			pend_is_store_q <= 1'b0;
			pend_wdata_q <= 64'd0;
			pend_be_q <= 8'd0;
			pend_evict_tag_q <= {TAG_W{1'b0}};
			// Atomic registers
			pend_is_amo_q <= 1'b0;
			pend_amo_op_q <= 5'd0;
			pend_amo_word_q <= 1'b0;
			amo_old_value_q <= 64'd0;
			// LR/SC registers
			resv_valid_q <= 1'b0;
			resv_addr_q <= 52'd0;
			resv_word_q <= 1'b0;
			pend_is_lr_q <= 1'b0;
			pend_is_sc_q <= 1'b0;
			sc_success_q <= 1'b0;
		end else begin
			state <= state_n;
			beat_q <= beat_n;
			pend_index_q <= pend_index_n;
			pend_tag_q <= pend_tag_n;
			pend_word_q <= pend_word_n;
			pend_victim_q <= pend_victim_n;
			rdata_beat_q <= rdata_beat_n;
			pend_is_store_q <= pend_is_store_n;
			pend_wdata_q <= pend_wdata_n;
			pend_be_q <= pend_be_n;
			pend_evict_tag_q <= pend_evict_tag_n;
			// Atomic registers
			pend_is_amo_q <= pend_is_amo_n;
			pend_amo_op_q <= pend_amo_op_n;
			pend_amo_word_q <= pend_amo_word_n;
			amo_old_value_q <= amo_old_value_n;
			// LR/SC registers
			resv_valid_q <= resv_valid_n;
			resv_addr_q <= resv_addr_n;
			resv_word_q <= resv_word_n;
			pend_is_lr_q <= pend_is_lr_n;
			pend_is_sc_q <= pend_is_sc_n;
			sc_success_q <= sc_success_n;
		end
	end

	// Output registers
	always @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni) begin
			gnt_o    <= 1'b0;
			rvalid_o <= 1'b0;
			rdata_o  <= 64'd0;
			req_o    <= 1'b0;
			we_o     <= 1'b0;
			be_o     <= 8'h00;
			addr_o   <= 64'd0;
			wdata_o  <= 64'd0;
			binv_ack_o<= 1'b0;
		end else begin
			gnt_o    <= gnt_n;
			rvalid_o <= rvalid_n;
			rdata_o  <= rdata_n;
			req_o    <= req_n;
			we_o     <= we_n;
			be_o     <= be_n;
			addr_o   <= addr_n;
			wdata_o  <= wdata_n;
`ifdef VERILATOR
			if (rvalid_n) begin
				$display("[L1 OUTPUT REG] Capturing rdata_n=0x%016h into rdata_o", rdata_n);
			end
`endif
			binv_ack_o<= binv_ack_n;
		end
	end

`ifdef CPU64_DBG_TRACE
    //===================== Debug Trace ==========================//
    always @(posedge clk_i) begin
        if (rst_ni && req_i && gnt_o) begin
            $display("[L1 ] %s index=%0d way=%0d addr=0x%0h we=%0b be=0x%02h miss=%0b state=%0d", 
                     hit ? "HIT " : "MISS", index, hit ? hit_way : victim_way, addr_i, we_i, be_i, ~hit, state);
        end
        // Debug AMO rdata
        if (rst_ni && rvalid_n && pend_is_amo_q) begin
            $display("[L1 AMO RDATA] state=%0d rvalid_n=%0b rdata_n=0x%016h amo_old_value_q=0x%016h", 
                     state, rvalid_n, rdata_n, amo_old_value_q);
        end
        if (rst_ni && rvalid_o && pend_is_amo_q) begin
            $display("[L1 AMO OUTPUT] rvalid_o=%0b rdata_o=0x%016h", rvalid_o, rdata_o);
        end
    end
`endif

	// PLRU update: drive access pulse and used way
	// We reuse the existing instance; tie access_i to registered pulse
	// Note: victim selection uses current index; update uses pending index via access pulse timing
	always @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni) begin
			plru_access_q   <= 1'b0;
			plru_used_way_q <= 3'd0;
		end else begin
			plru_access_q   <= plru_access_n;
			plru_used_way_q <= plru_used_way_n;
		end
	end

endmodule


