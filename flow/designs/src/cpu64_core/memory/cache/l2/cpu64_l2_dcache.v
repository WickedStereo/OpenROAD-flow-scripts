// cpu64_l2_dcache.v - Top-level L2 D$ (256KiB, 16-way, 64B lines), OBI + inclusive back-invalidate
`timescale 1ns/1ps

module cpu64_l2_dcache (
	input              clk_i,
	input              rst_ni,

	// Optional maintenance
	input              invalidate_all_i,

	// Back-invalidate from L3 (lower) → L2
	input              binv_req_i,
	input      [63:0]  binv_addr_i,
	output reg         binv_ack_o,

	// CPU-side (slave-like OBI style) from L1
	input              req_i,
	input              we_i,
	input       [7:0]  be_i,
	input      [63:0]  addr_i,
	input      [63:0]  wdata_i,
	output reg         gnt_o,
	output reg         rvalid_o,
	output reg [63:0]  rdata_o,

	// Memory-side (host-like) to L3
	output reg         req_o,
	output reg         we_o,
	output reg  [7:0]  be_o,
	output reg [63:0]  addr_o,
	output reg [63:0]  wdata_o,
	input              gnt_i,
	input              rvalid_i,
	input      [63:0]  rdata_i,

	// Back-invalidate from L2 (this) → L1 (upper)
	output reg         inv_req_o,
	output reg [63:0]  inv_addr_o,
	input              inv_ack_i
);

	// Fixed configuration parameters for L2
	localparam integer ADDR_W          = 64;
	localparam integer DATA_W          = 64;
	localparam integer LINE_BYTES      = 64;
	localparam integer WORDS_PER_LINE  = 8;   // 64B / 8B
	localparam integer SETS            = 256; // 256KiB / (64B * 16 ways)
	localparam integer WAYS            = 16;
	localparam integer BYTE_OFF_W      = 3;   // addr[2:0]
	localparam integer WORD_OFF_W      = 3;   // addr[5:3]
	localparam integer LINE_OFF_W      = 6;   // addr[5:0]
	localparam integer INDEX_W         = 8;   // addr[13:6]
	localparam integer TAG_W           = 50;  // addr[63:14]

	// Address decode (CPU-side request)
	wire [INDEX_W-1:0] index  = addr_i[13:6];
	wire [WORD_OFF_W-1:0] word_off = addr_i[5:3];
	wire [TAG_W-1:0]    tag    = addr_i[63:14];

	// Array interfaces
	wire [63:0]  arr_rdata_sel;
	wire [TAG_W-1:0]  arr_tag_sel;
	wire         arr_valid_sel;
	wire         arr_dirty_sel;
	wire [WAYS*DATA_W-1:0] arr_rdata_way_flat;
	wire [WAYS*TAG_W-1:0]  arr_tag_way_flat;
	wire [WAYS-1:0]        arr_valid_way;
	wire [WAYS-1:0]        arr_dirty_way;

	cpu64_l2_arrays u_arrays (
		.clk_i              (clk_i),
		.rst_ni             (rst_ni),
		.invalidate_all_i   (state == S_IDLE ? invalidate_all_i : 1'b0),
		.index_i            (arr_index_w),
		.word_sel_i         (arr_word_sel),
		.way_sel_i          (arr_way_sel),
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
	wire [3:0] victim_way;
	reg        plru_access_q;
	reg [3:0]  plru_used_way_q;
	cpu64_l2_plru u_plru (
		.clk_i     (clk_i),
		.rst_ni    (rst_ni),
		.set_i     (index),
		.access_i  (plru_access_q),
		.used_way_i(plru_used_way_q),
		.valid_i   (arr_valid_way),
		.victim_o  (victim_way)
	);

	// Hit data word for selected way
	wire [63:0] hit_data_word;
	assign hit_data_word = arr_rdata_way_flat[(((hit_way+1)*DATA_W)-1) -: DATA_W];

	// State and control for refill + writeback + (back-)invalidation FSM
	localparam [3:0] S_IDLE      = 4'd0,
	                 S_REF_REQ   = 4'd1,
	                 S_REF_WAIT  = 4'd2,
	                 S_WRITE_BEAT= 4'd3,
	                 S_RESP      = 4'd4,
	                 S_WB_REQ    = 4'd5,
	                 S_INV_REQ   = 4'd6,
	                 S_BINV_WB   = 4'd7,
	                 S_BINV_CLR  = 4'd8;

	reg [3:0] state, state_n;
	reg [2:0] beat_q, beat_n;                       // 0..7
	reg [INDEX_W-1:0] pend_index_q, pend_index_n;   // Pending set index
	reg [TAG_W-1:0]   pend_tag_q, pend_tag_n;       // Pending tag (target)
	reg [WORD_OFF_W-1:0] pend_word_q, pend_word_n;  // Pending word offset
	reg [3:0]         pend_victim_q, pend_victim_n; // Pending victim way
	reg               pend_is_store_q, pend_is_store_n;
	reg [63:0]        pend_wdata_q, pend_wdata_n;
	reg [7:0]         pend_be_q, pend_be_n;
	reg [TAG_W-1:0]   pend_evict_tag_q, pend_evict_tag_n; // Victim tag to evict
	reg [63:0]        rdata_beat_q, rdata_beat_n;
	reg               wb_only_q, wb_only_n;         // Writeback-only (for back-invalidate) flag

	// Array control registers
	reg [2:0]         arr_word_sel;
	reg [3:0]         arr_way_sel;
	reg               arr_write_en;
	reg               arr_set_valid;
	reg               arr_set_dirty;
	reg [7:0]         arr_be;
	reg [TAG_W-1:0]   arr_tag_in;
	reg [63:0]        arr_wdata;

	// Combinational array index selection (avoids UNOPTFLAT feedback warning)
	wire [INDEX_W-1:0] arr_index_w =
		((state == S_WB_REQ) || (state == S_BINV_WB) || (state == S_BINV_CLR) ||
		 (state == S_WRITE_BEAT) || (state == S_RESP)) ? pend_index_q :
		((state == S_IDLE) && binv_req_i ? binv_index : index);

	// Hit detection (combinational)
	reg hit;
	reg [3:0] hit_way;
	integer i;
	reg [TAG_W-1:0] tag_slice;
	always @(*) begin
		hit = 1'b0;
		hit_way = 4'd0;
		for (i = 0; i < WAYS; i = i + 1) begin
			tag_slice = arr_tag_way_flat[((i+1)*TAG_W-1) -: TAG_W];
			if (arr_valid_way[i] && (tag_slice == tag)) begin
				hit = 1'b1;
				hit_way = i[3:0];
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
	reg [3:0]  plru_used_way_n;
	reg        inv_req_n;        // to L1
	reg [63:0] inv_addr_n;
	reg        binv_ack_n;

	// Decode for back-invalidate request (from L3)
	wire [INDEX_W-1:0] binv_index = binv_addr_i[13:6];
	wire [TAG_W-1:0]   binv_tag   = binv_addr_i[63:14];
	reg                binv_hit;
	reg [3:0]          binv_way;
	reg [TAG_W-1:0]    tmp_tag;

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
		wb_only_n     = wb_only_q;

		gnt_n    = 1'b0;
		rvalid_n = 1'b0;
		rdata_n  = 64'd0;
		req_n    = 1'b0;
		we_n     = 1'b0;
		be_n     = 8'h00;
		addr_n   = 64'd0;
		wdata_n  = 64'd0;
		inv_req_n= 1'b0;
		inv_addr_n=64'd0;
		binv_ack_n=1'b0;

		// Array control defaults
		arr_word_sel  = word_off;
		arr_way_sel   = hit_way;
		arr_write_en  = 1'b0;
		arr_set_valid = 1'b0;
		arr_set_dirty = 1'b0;
		arr_be        = 8'h00;
		arr_tag_in    = {TAG_W{1'b0}};
		arr_wdata     = 64'd0;

		plru_access_n   = 1'b0;
		plru_used_way_n = 4'd0;

		// Back-invalidate hit detection (from L3)
		binv_hit = 1'b0;
		binv_way = 4'd0;
		for (i = 0; i < WAYS; i = i + 1) begin
			tmp_tag = arr_tag_way_flat[((i+1)*TAG_W-1) -: TAG_W];
			if (arr_valid_way[i] && (tmp_tag == binv_tag)) begin
				binv_hit = 1'b1;
				binv_way = i[3:0];
			end
		end

		case (state)
		S_IDLE: begin
			// Handle lower-level back-invalidate if present (only in IDLE)
			if (binv_req_i) begin
				// Prepare to invalidate matching line; writeback if dirty
				if (binv_hit) begin
					arr_way_sel   = binv_way;
					if (arr_dirty_way[binv_way]) begin
						// Writeback to L3 then clear
						pend_index_n  = binv_index;
						pend_victim_n = binv_way;
						pend_evict_tag_n = binv_tag; // original tag
						beat_n = 3'd0;
						wb_only_n = 1'b1;
						state_n = S_BINV_WB;
					end else begin
						// Clear valid/dirty for that way via a masked write (be=0)
						arr_write_en  = 1'b1;
						arr_set_valid = 1'b0;
						arr_set_dirty = 1'b0;
						arr_be        = 8'h00;
						binv_ack_n    = 1'b1;
					end
				end else begin
					// Not present -> immediate ack
					binv_ack_n = 1'b1;
				end
			end else if (invalidate_all_i) begin
				// Arrays handle it when in IDLE via invalidate_all_i input
			end else begin
				// Normal request handling
				if (req_i && !we_i && hit) begin
					gnt_n    = 1'b1;
					rvalid_n = 1'b1;
					rdata_n  = hit_data_word;
					plru_access_n   = 1'b1;
					plru_used_way_n = hit_way;
				end else if (req_i && we_i && hit) begin
					gnt_n    = 1'b1;
					// BE merge write
					arr_word_sel  = word_off;
					arr_way_sel   = hit_way;
					arr_write_en  = 1'b1;
					arr_set_valid = 1'b1;
					arr_set_dirty = 1'b1;
					arr_be        = be_i;
					arr_tag_in    = tag;
					arr_wdata     = wdata_i;
					plru_access_n   = 1'b1;
					plru_used_way_n = hit_way;
				end else if (req_i && !we_i && !hit) begin
					// Read miss -> may need to evict victim; first send back-invalidate to L1 if victim valid
					pend_index_n  = index;
					pend_tag_n    = tag;
					pend_word_n   = word_off;
					pend_victim_n = victim_way;
					pend_is_store_n = 1'b0;
					pend_evict_tag_n = arr_tag_way_flat[((victim_way+1)*TAG_W-1) -: TAG_W];
					beat_n        = 3'd0;
					if (arr_valid_way[victim_way]) begin
						inv_req_n  = 1'b1;
						inv_addr_n = {pend_evict_tag_n, index, 6'b0};
						state_n    = S_INV_REQ;
					end else begin
						state_n = S_REF_REQ;
					end
				end else if (req_i && we_i && !hit) begin
					// Store miss -> RFO
					pend_index_n   = index;
					pend_tag_n     = tag;
					pend_word_n    = word_off;
					pend_victim_n  = victim_way;
					pend_is_store_n= 1'b1;
					pend_wdata_n   = wdata_i;
					pend_be_n      = be_i;
					pend_evict_tag_n = arr_tag_way_flat[((victim_way+1)*TAG_W-1) -: TAG_W];
					beat_n         = 3'd0;
					if (arr_valid_way[victim_way]) begin
						inv_req_n  = 1'b1;
						inv_addr_n = {pend_evict_tag_n, index, 6'b0};
						state_n    = S_INV_REQ;
					end else begin
						state_n = S_REF_REQ;
					end
				end
			end
		end

		S_INV_REQ: begin
			// Assert back-invalidate to L1 for victim line; accept write-hits from L1 (e.g., WB beats)
			inv_req_n  = 1'b1;
			inv_addr_n = {pend_evict_tag_q, pend_index_q, 6'b0};
			// Accept and process any write-hit from L1
			if (req_i && we_i) begin
				// Recompute hit/hit_way using current address
				// Allow BE-merge into arrays; this will typically target the victim line
				if (hit) begin
					gnt_n        = 1'b1;
					arr_word_sel  = word_off;
					arr_way_sel   = hit_way;
					arr_write_en  = 1'b1;
					arr_set_valid = 1'b1;
					arr_set_dirty = 1'b1;
					arr_be        = be_i;
					arr_tag_in    = tag;
					arr_wdata     = wdata_i;
				end
			end
			// When L1 acks, proceed to writeback (if dirty) or refill
			if (inv_ack_i) begin
				if (arr_valid_way[pend_victim_q] && arr_dirty_way[pend_victim_q]) begin
					state_n = S_WB_REQ;
					beat_n  = 3'd0;
					wb_only_n = 1'b0;
				end else begin
					state_n = S_REF_REQ;
				end
			end
		end

		S_REF_REQ: begin
			// Issue read beat request (serialized) to L3
			req_n  = 1'b1;
			we_n   = 1'b0;
			be_n   = 8'h00;
			addr_n = {pend_tag_q, pend_index_q, 6'b0} + {58'd0, beat_q, 3'd0};
			if (gnt_i) begin
				state_n = S_REF_WAIT;
			end
		end

		S_REF_WAIT: begin
			if (rvalid_i) begin
				rdata_beat_n = rdata_i;
				state_n = S_WRITE_BEAT;
			end
		end

		S_WB_REQ: begin
			// Writeback of victim line to L3 (full-line beats)
			// index driven by arr_index_w wire
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
					if (wb_only_q) begin
						// For back-invalidate writeback only, clear and ack (handled in S_BINV_CLR)
						state_n = S_BINV_CLR;
					end else begin
						state_n = S_REF_REQ;
					end
				end else begin
					beat_n  = beat_q + 3'd1;
					state_n = S_WB_REQ;
				end
			end
		end

		S_WRITE_BEAT: begin
			// Write received beat into arrays at victim
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
			if (pend_is_store_q) begin
				// Perform BE-merge store into freshly refilled line
				arr_write_en  = 1'b1;
				arr_set_valid = 1'b1;
				arr_set_dirty = 1'b1;
				arr_be        = pend_be_q;
				arr_tag_in    = pend_tag_q;
				arr_wdata     = pend_wdata_q;
				gnt_n         = 1'b1;
				state_n       = S_IDLE;
			end else begin
				rvalid_n = 1'b1;
				rdata_n  = arr_rdata_sel;
				state_n  = S_IDLE;
			end
		end

		S_BINV_WB: begin
			// Writeback for back-invalidate from L3; identical to S_WB_REQ but wb_only=1
			// index driven by arr_index_w wire
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
					state_n = S_BINV_CLR;
				end else begin
					beat_n  = beat_q + 3'd1;
					state_n = S_BINV_WB;
				end
			end
		end

		S_BINV_CLR: begin
			// After WB, clear valid/dirty and ack binv
			// index driven by arr_index_w wire
			arr_way_sel   = pend_victim_q;
			arr_write_en  = 1'b1;
			arr_set_valid = 1'b0;
			arr_set_dirty = 1'b0;
			arr_be        = 8'h00;
			binv_ack_n    = 1'b1;
			state_n       = S_IDLE;
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
			pend_victim_q <= 4'd0;
			rdata_beat_q <= 64'd0;
			pend_is_store_q <= 1'b0;
			pend_wdata_q <= 64'd0;
			pend_be_q <= 8'd0;
			pend_evict_tag_q <= {TAG_W{1'b0}};
			wb_only_q <= 1'b0;
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
			wb_only_q <= wb_only_n;
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
			inv_req_o<= 1'b0;
			inv_addr_o<=64'd0;
			binv_ack_o<=1'b0;
		end else begin
			gnt_o    <= gnt_n;
			rvalid_o <= rvalid_n;
			rdata_o  <= rdata_n;
			req_o    <= req_n;
			we_o     <= we_n;
			be_o     <= be_n;
			addr_o   <= addr_n;
			wdata_o  <= wdata_n;
			inv_req_o<= inv_req_n;
			inv_addr_o<=inv_addr_n;
			binv_ack_o<=binv_ack_n;
		end
	end

	// PLRU update regs
	always @(posedge clk_i or negedge rst_ni) begin
		if (!rst_ni) begin
			plru_access_q   <= 1'b0;
			plru_used_way_q <= 4'd0;
		end else begin
			plru_access_q   <= plru_access_n;
			plru_used_way_q <= plru_used_way_n;
		end
	end

endmodule



