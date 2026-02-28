// cpu64_cache_stack.v - Wrapper for inclusive L1↔L2↔L3 cache stack (OBI interfaces)
`timescale 1ns/1ps

module cpu64_cache_stack (
	input              clk_i,
	input              rst_ni,

	// Optional maintenance
	input              invalidate_all_i,

	// CPU-side (to L1)
	input              req_i,
	input              we_i,
	input       [7:0]  be_i,
	input      [63:0]  addr_i,
	input      [63:0]  wdata_i,
	output             gnt_o,
	output             rvalid_o,
	output     [63:0]  rdata_o,
	// Atomic operation inputs
	input              amo_i,          // Atomic operation flag
	input              lr_i,           // Load-Reserved operation
	input              sc_i,           // Store-Conditional operation
	input       [4:0]  amo_op_i,       // Atomic operation type
	input              amo_word_i,     // Atomic word operation flag

	// Memory-side (from L3 to external memory)
	output             req_o,
	output             we_o,
	output      [7:0]  be_o,
	output     [63:0]  addr_o,
	output     [63:0]  wdata_o,
	input              gnt_i,
	input              rvalid_i,
	input      [63:0]  rdata_i
);

	// Interconnect wires: L1 <-> L2
	wire        l1l2_req;
	wire        l1l2_we;
	wire [7:0]  l1l2_be;
	wire [63:0] l1l2_addr;
	wire [63:0] l1l2_wdata;
	wire        l2l1_gnt;
	wire        l2l1_rvalid;
	wire [63:0] l2l1_rdata;

	// Interconnect wires: L2 <-> L3
	wire        l2l3_req;
	wire        l2l3_we;
	wire [7:0]  l2l3_be;
	wire [63:0] l2l3_addr;
	wire [63:0] l2l3_wdata;
	wire        l3l2_gnt;
	wire        l3l2_rvalid;
	wire [63:0] l3l2_rdata;

	// Back-invalidate sidebands
	wire        l2_to_l1_inv_req;
	wire [63:0] l2_to_l1_inv_addr;
	wire        l1_inv_ack;

	wire        l3_to_l2_inv_req;
	wire [63:0] l3_to_l2_inv_addr;
	wire        l2_inv_ack;

	// L1
	cpu64_l1_dcache u_l1 (
		.clk_i(clk_i), .rst_ni(rst_ni), .invalidate_all_i(invalidate_all_i),
		// binv from L2
		.binv_req_i(l2_to_l1_inv_req), .binv_addr_i(l2_to_l1_inv_addr), .binv_ack_o(l1_inv_ack),
		// CPU side
		.req_i(req_i), .we_i(we_i), .be_i(be_i), .addr_i(addr_i), .wdata_i(wdata_i), .gnt_o(gnt_o), .rvalid_o(rvalid_o), .rdata_o(rdata_o),
		// Atomic operations
		.amo_i(amo_i), .lr_i(lr_i), .sc_i(sc_i), .amo_op_i(amo_op_i), .amo_word_i(amo_word_i),
		// to L2
		.req_o(l1l2_req), .we_o(l1l2_we), .be_o(l1l2_be), .addr_o(l1l2_addr), .wdata_o(l1l2_wdata),
		.gnt_i(l2l1_gnt), .rvalid_i(l2l1_rvalid), .rdata_i(l2l1_rdata)
	);

	// L2
	cpu64_l2_dcache u_l2 (
		.clk_i(clk_i), .rst_ni(rst_ni), .invalidate_all_i(invalidate_all_i),
		// binv from L3 -> L2
		.binv_req_i(l3_to_l2_inv_req), .binv_addr_i(l3_to_l2_inv_addr), .binv_ack_o(l2_inv_ack),
		// from L1
		.req_i(l1l2_req), .we_i(l1l2_we), .be_i(l1l2_be), .addr_i(l1l2_addr), .wdata_i(l1l2_wdata), .gnt_o(l2l1_gnt), .rvalid_o(l2l1_rvalid), .rdata_o(l2l1_rdata),
		// to L3
		.req_o(l2l3_req), .we_o(l2l3_we), .be_o(l2l3_be), .addr_o(l2l3_addr), .wdata_o(l2l3_wdata), .gnt_i(l3l2_gnt), .rvalid_i(l3l2_rvalid), .rdata_i(l3l2_rdata),
		// back-invalidate to L1
		.inv_req_o(l2_to_l1_inv_req), .inv_addr_o(l2_to_l1_inv_addr), .inv_ack_i(l1_inv_ack)
	);

	// L3
	cpu64_l3_dcache u_l3 (
		.clk_i(clk_i), .rst_ni(rst_ni), .invalidate_all_i(invalidate_all_i),
		// from L2
		.req_i(l2l3_req), .we_i(l2l3_we), .be_i(l2l3_be), .addr_i(l2l3_addr), .wdata_i(l2l3_wdata), .gnt_o(l3l2_gnt), .rvalid_o(l3l2_rvalid), .rdata_o(l3l2_rdata),
		// to Mem
		.req_o(req_o), .we_o(we_o), .be_o(be_o), .addr_o(addr_o), .wdata_o(wdata_o), .gnt_i(gnt_i), .rvalid_i(rvalid_i), .rdata_i(rdata_i),
		// back-invalidate to L2
		.inv_req_o(l3_to_l2_inv_req), .inv_addr_o(l3_to_l2_inv_addr), .inv_ack_i(l2_inv_ack)
	);

endmodule



