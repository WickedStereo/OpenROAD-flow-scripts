// =============================================================================
// Project: TileLink Inclusive Directory Coherence (TIDC) System
// Module: TIDC Top Level
// Description: Top-level module that connects TileLink adapters directly
//              without cache controller stubs for TileLink testing
// =============================================================================

module tidc_top (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Direct L1 TileLink Adapter interfaces (no cache controller)
    // L1 Adapter 0 interface
    input  wire                         l1_0_request_valid,
    input  wire [63:0]                  l1_0_request_addr,
    input  wire [2:0]                   l1_0_request_type,
    input  wire [511:0]                 l1_0_request_data,
    input  wire [2:0]                   l1_0_request_permissions,
    output wire                         l1_0_request_ready,
    
    output wire                         l1_0_data_valid,
    output wire [511:0]                 l1_0_data,
    output wire                         l1_0_data_error,
    
    output wire                         l1_0_probe_req_valid,
    output wire [63:0]                  l1_0_probe_req_addr,
    output wire [2:0]                   l1_0_probe_req_permissions,
    
    input  wire                         l1_0_probe_ack_valid,
    input  wire [63:0]                  l1_0_probe_ack_addr,
    input  wire [2:0]                   l1_0_probe_ack_permissions,
    input  wire [511:0]                 l1_0_probe_ack_dirty_data,
    
    // L1 Adapter 1 interface
    input  wire                         l1_1_request_valid,
    input  wire [63:0]                  l1_1_request_addr,
    input  wire [2:0]                   l1_1_request_type,
    input  wire [511:0]                 l1_1_request_data,
    input  wire [2:0]                   l1_1_request_permissions,
    output wire                         l1_1_request_ready,
    
    output wire                         l1_1_data_valid,
    output wire [511:0]                 l1_1_data,
    output wire                         l1_1_data_error,
    
    output wire                         l1_1_probe_req_valid,
    output wire [63:0]                  l1_1_probe_req_addr,
    output wire [2:0]                   l1_1_probe_req_permissions,
    
    input  wire                         l1_1_probe_ack_valid,
    input  wire [63:0]                  l1_1_probe_ack_addr,
    input  wire [2:0]                   l1_1_probe_ack_permissions,
    input  wire [511:0]                 l1_1_probe_ack_dirty_data,
    
    // L2 TileLink Adapter interface (direct, no cache controller)
    output wire                         l2_cmd_valid,
    output wire [2:0]                   l2_cmd_type,
    output wire [63:0]                  l2_cmd_addr,
    output wire [511:0]                 l2_cmd_data,
    output wire [3:0]                   l2_cmd_size,
    output wire                         l2_cmd_dirty,
    
    input  wire                         l2_response_valid,
    input  wire [511:0]                 l2_response_data,
    input  wire                         l2_response_error
);

    // TileLink Channel Signals between L1 and L2
    
    // Channel A (L1 → L2)
    wire [1:0]                         a_valid;
    wire [5:0]                         a_opcode;        // 2 * 3 bits
    wire [5:0]                         a_param;         // 2 * 3 bits
    wire [7:0]                         a_size;          // 2 * 4 bits
    wire [7:0]                         a_source;        // 2 * 4 bits
    wire [127:0]                       a_address;       // 2 * 64 bits
    wire [1023:0]                      a_data;          // 2 * 512 bits
    wire [127:0]                       a_mask;          // 2 * 64 bits
    wire [1:0]                         a_ready;
    
    // Channel B (L2 → L1)
    wire [1:0]                         b_valid;
    wire [5:0]                         b_opcode;        // 2 * 3 bits
    wire [5:0]                         b_param;         // 2 * 3 bits
    wire [7:0]                         b_size;          // 2 * 4 bits
    wire [7:0]                         b_source;        // 2 * 4 bits
    wire [127:0]                       b_address;       // 2 * 64 bits
    wire [1023:0]                      b_data;          // 2 * 512 bits
    wire [127:0]                       b_mask;          // 2 * 64 bits
    wire [1:0]                         b_ready;
    
    // Channel C (L1 → L2)
    wire [1:0]                         c_valid;
    wire [5:0]                         c_opcode;        // 2 * 3 bits
    wire [5:0]                         c_param;         // 2 * 3 bits
    wire [7:0]                         c_size;          // 2 * 4 bits
    wire [7:0]                         c_source;        // 2 * 4 bits
    wire [127:0]                       c_address;       // 2 * 64 bits
    wire [1023:0]                      c_data;          // 2 * 512 bits
    wire [1:0]                         c_error;
    wire [1:0]                         c_ready;
    
    // Channel D (L2 → L1)
    wire [1:0]                         d_valid;
    wire [5:0]                         d_opcode;        // 2 * 3 bits
    wire [5:0]                         d_param;         // 2 * 3 bits
    wire [7:0]                         d_size;          // 2 * 4 bits
    wire [7:0]                         d_source;        // 2 * 4 bits
    wire [7:0]                         d_sink;          // 2 * 4 bits
    wire [1023:0]                      d_data;          // 2 * 512 bits
    wire [1:0]                         d_error;
    wire [1:0]                         d_ready;
    
    // Channel E (L1 → L2)
    wire [1:0]                         e_valid;
    wire [7:0]                         e_sink;          // 2 * 4 bits
    wire [1:0]                         e_ready;
    
    // Bundle L1 adapter interfaces for the generate loop
    wire [1:0]                                          l1_request_valid_array;
    wire [127:0]                                        l1_request_addr_array;      // 2 * 64 bits
    wire [5:0]                                          l1_request_type_array;      // 2 * 3 bits
    wire [1023:0]                                       l1_request_data_array;      // 2 * 512 bits
    wire [5:0]                                          l1_request_permissions_array; // 2 * 3 bits
    wire [1:0]                                          l1_request_ready_array;
    
    wire [1:0]                                          l1_data_valid_array;
    wire [1023:0]                                       l1_data_array;              // 2 * 512 bits
    wire [1:0]                                          l1_data_error_array;
    
    wire [1:0]                                          l1_probe_req_valid_from_l2;
    wire [127:0]                                        l1_probe_req_addr_from_l2;    // 2 * 64 bits
    wire [5:0]                                          l1_probe_req_permissions_from_l2; // 2 * 3 bits
    
    wire [1:0]                                          l1_probe_ack_valid_array;
    wire [127:0]                                        l1_probe_ack_addr_array;    // 2 * 64 bits
    wire [5:0]                                          l1_probe_ack_permissions_array; // 2 * 3 bits
    wire [1023:0]                                       l1_probe_ack_dirty_data_array; // 2 * 512 bits
    
    // Map individual L1 interfaces to arrays
    assign l1_request_valid_array = {l1_1_request_valid, l1_0_request_valid};
    assign l1_request_addr_array = {l1_1_request_addr, l1_0_request_addr};
    assign l1_request_type_array = {l1_1_request_type, l1_0_request_type};
    assign l1_request_data_array = {l1_1_request_data, l1_0_request_data};
    assign l1_request_permissions_array = {l1_1_request_permissions, l1_0_request_permissions};
    
    assign {l1_1_request_ready, l1_0_request_ready} = l1_request_ready_array;
    assign {l1_1_data_valid, l1_0_data_valid} = l1_data_valid_array;
    assign {l1_1_data, l1_0_data} = l1_data_array;
    assign {l1_1_data_error, l1_0_data_error} = l1_data_error_array;
    
    // Connect internal array signals to individual output ports
    assign l1_0_probe_req_valid = l1_probe_req_valid_from_l2[0];
    assign l1_1_probe_req_valid = l1_probe_req_valid_from_l2[1];
    
    assign l1_0_probe_req_addr = l1_probe_req_addr_from_l2[63:0];
    assign l1_1_probe_req_addr = l1_probe_req_addr_from_l2[127:64];
    
    assign l1_0_probe_req_permissions = l1_probe_req_permissions_from_l2[2:0];
    assign l1_1_probe_req_permissions = l1_probe_req_permissions_from_l2[5:3];
    
    assign l1_probe_ack_valid_array = {l1_1_probe_ack_valid, l1_0_probe_ack_valid};
    assign l1_probe_ack_addr_array = {l1_1_probe_ack_addr, l1_0_probe_ack_addr};
    assign l1_probe_ack_permissions_array = {l1_1_probe_ack_permissions, l1_0_probe_ack_permissions};
    assign l1_probe_ack_dirty_data_array = {l1_1_probe_ack_dirty_data, l1_0_probe_ack_dirty_data};
    
    // Instantiate L1 TileLink adapters explicitly (simplified for 2-master case)
    
    // L1 Adapter 0
    l1_tilelink_adapter l1_adapter_0 (
        .clk(clk),
        .rst_n(rst_n),
        .l1_id(2'b00),
        
        // L1 Adapter Interface
        .l1_request_valid(l1_request_valid_array[0]),
        .l1_request_addr(l1_request_addr_array[63:0]),
        .l1_request_type(l1_request_type_array[2:0]),
        .l1_request_data(l1_request_data_array[511:0]),
        .l1_request_permissions(l1_request_permissions_array[2:0]),
        .l1_request_ready(l1_request_ready_array[0]),
        
        .data_to_l1_valid(l1_data_valid_array[0]),
        .data_to_l1_data(l1_data_array[511:0]),
        .data_to_l1_error(l1_data_error_array[0]),
        
        .probe_req_to_l1_valid(l1_probe_req_valid_from_l2[0]),
        .probe_req_to_l1_addr(l1_probe_req_addr_from_l2[63:0]),
        .probe_req_to_l1_permissions(l1_probe_req_permissions_from_l2[2:0]),
        
        .probe_ack_from_l1_valid(l1_probe_ack_valid_array[0]),
        .probe_ack_from_l1_addr(l1_probe_ack_addr_array[63:0]),
        .probe_ack_from_l1_permissions(l1_probe_ack_permissions_array[2:0]),
        .probe_ack_from_l1_dirty_data(l1_probe_ack_dirty_data_array[511:0]),
        
        // TileLink interface
        .a_valid(a_valid[0]),
        .a_opcode(a_opcode[2:0]),
        .a_param(a_param[2:0]),
        .a_size(a_size[3:0]),
        .a_source(a_source[3:0]),
        .a_address(a_address[63:0]),
        .a_data(a_data[511:0]),
        .a_mask(a_mask[63:0]),
        .a_ready(a_ready[0]),
        
        .b_valid(b_valid[0]),
        .b_opcode(b_opcode[2:0]),
        .b_param(b_param[2:0]),
        .b_size(b_size[3:0]),
        .b_source(b_source[3:0]),
        .b_address(b_address[63:0]),
        .b_data(b_data[511:0]),
        .b_mask(b_mask[63:0]),
        .b_ready(b_ready[0]),
        
        .c_valid(c_valid[0]),
        .c_opcode(c_opcode[2:0]),
        .c_param(c_param[2:0]),
        .c_size(c_size[3:0]),
        .c_source(c_source[3:0]),
        .c_address(c_address[63:0]),
        .c_data(c_data[511:0]),
        .c_error(c_error[0]),
        .c_ready(c_ready[0]),
        
        .d_valid(d_valid[0]),
        .d_opcode(d_opcode[2:0]),
        .d_param(d_param[2:0]),
        .d_size(d_size[3:0]),
        .d_source(d_source[3:0]),
        .d_sink(d_sink[3:0]),
        .d_data(d_data[511:0]),
        .d_error(d_error[0]),
        .d_ready(d_ready[0]),
        
        .e_valid(e_valid[0]),
        .e_sink(e_sink[3:0]),
        .e_ready(e_ready[0])
    );
    
    // L1 Adapter 1
    l1_tilelink_adapter l1_adapter_1 (
        .clk(clk),
        .rst_n(rst_n),
        .l1_id(2'b01),
        
        // L1 Adapter Interface
        .l1_request_valid(l1_request_valid_array[1]),
        .l1_request_addr(l1_request_addr_array[127:64]),
        .l1_request_type(l1_request_type_array[5:3]),
        .l1_request_data(l1_request_data_array[1023:512]),
        .l1_request_permissions(l1_request_permissions_array[5:3]),
        .l1_request_ready(l1_request_ready_array[1]),
        
        .data_to_l1_valid(l1_data_valid_array[1]),
        .data_to_l1_data(l1_data_array[1023:512]),
        .data_to_l1_error(l1_data_error_array[1]),
        
        .probe_req_to_l1_valid(l1_probe_req_valid_from_l2[1]),
        .probe_req_to_l1_addr(l1_probe_req_addr_from_l2[127:64]),
        .probe_req_to_l1_permissions(l1_probe_req_permissions_from_l2[5:3]),
        
        .probe_ack_from_l1_valid(l1_probe_ack_valid_array[1]),
        .probe_ack_from_l1_addr(l1_probe_ack_addr_array[127:64]),
        .probe_ack_from_l1_permissions(l1_probe_ack_permissions_array[5:3]),
        .probe_ack_from_l1_dirty_data(l1_probe_ack_dirty_data_array[1023:512]),
        
        // TileLink interface
        .a_valid(a_valid[1]),
        .a_opcode(a_opcode[5:3]),
        .a_param(a_param[5:3]),
        .a_size(a_size[7:4]),
        .a_source(a_source[7:4]),
        .a_address(a_address[127:64]),
        .a_data(a_data[1023:512]),
        .a_mask(a_mask[127:64]),
        .a_ready(a_ready[1]),
        
        .b_valid(b_valid[1]),
        .b_opcode(b_opcode[5:3]),
        .b_param(b_param[5:3]),
        .b_size(b_size[7:4]),
        .b_source(b_source[7:4]),
        .b_address(b_address[127:64]),
        .b_data(b_data[1023:512]),
        .b_mask(b_mask[127:64]),
        .b_ready(b_ready[1]),
        
        .c_valid(c_valid[1]),
        .c_opcode(c_opcode[5:3]),
        .c_param(c_param[5:3]),
        .c_size(c_size[7:4]),
        .c_source(c_source[7:4]),
        .c_address(c_address[127:64]),
        .c_data(c_data[1023:512]),
        .c_error(c_error[1]),
        .c_ready(c_ready[1]),
        
        .d_valid(d_valid[1]),
        .d_opcode(d_opcode[5:3]),
        .d_param(d_param[5:3]),
        .d_size(d_size[7:4]),
        .d_source(d_source[7:4]),
        .d_sink(d_sink[7:4]),
        .d_data(d_data[1023:512]),
        .d_error(d_error[1]),
        .d_ready(d_ready[1]),
        
        .e_valid(e_valid[1]),
        .e_sink(e_sink[7:4]),
        .e_ready(e_ready[1])
    );
    
    // Instantiate L2 TileLink Adapter (simplified interface)
    l2_tilelink_adapter l2_adapter (
        .clk(clk),
        .rst_n(rst_n),
        
        // Simplified direct probe interfaces to L1 adapters
        .l1_0_probe_req_valid(l1_probe_req_valid_from_l2[0]),
        .l1_1_probe_req_valid(l1_probe_req_valid_from_l2[1]),
        .l1_0_probe_req_addr(l1_probe_req_addr_from_l2[63:0]),
        .l1_1_probe_req_addr(l1_probe_req_addr_from_l2[127:64]),
        .l1_0_probe_req_permissions(l1_probe_req_permissions_from_l2[2:0]),
        .l1_1_probe_req_permissions(l1_probe_req_permissions_from_l2[5:3]),
        
        .l1_0_probe_ack_valid(l1_probe_ack_valid_array[0]),
        .l1_1_probe_ack_valid(l1_probe_ack_valid_array[1]),
        .l1_0_probe_ack_addr(l1_probe_ack_addr_array[63:0]),
        .l1_1_probe_ack_addr(l1_probe_ack_addr_array[127:64]),
        .l1_0_probe_ack_permissions(l1_probe_ack_permissions_array[2:0]),
        .l1_1_probe_ack_permissions(l1_probe_ack_permissions_array[5:3]),
        .l1_0_probe_ack_dirty_data(l1_probe_ack_dirty_data_array[511:0]),
        .l1_1_probe_ack_dirty_data(l1_probe_ack_dirty_data_array[1023:512]),
        
        // TileLink interface (keep packed for backward compatibility)
        .a_valid(a_valid),
        .a_opcode(a_opcode),
        .a_param(a_param),
        .a_size(a_size),
        .a_source(a_source),
        .a_address(a_address),
        .a_data(a_data),
        .a_mask(a_mask),
        .a_ready(a_ready),
        
        // Simplified individual B and D channel signals
        .b_0_valid(b_valid[0]),
        .b_1_valid(b_valid[1]),
        .b_0_opcode(b_opcode[2:0]),
        .b_1_opcode(b_opcode[5:3]),
        .b_0_param(b_param[2:0]),
        .b_1_param(b_param[5:3]),
        .b_0_size(b_size[3:0]),
        .b_1_size(b_size[7:4]),
        .b_0_source(b_source[3:0]),
        .b_1_source(b_source[7:4]),
        .b_0_address(b_address[63:0]),
        .b_1_address(b_address[127:64]),
        .b_0_data(b_data[511:0]),
        .b_1_data(b_data[1023:512]),
        .b_0_mask(b_mask[63:0]),
        .b_1_mask(b_mask[127:64]),
        .b_0_ready(b_ready[0]),
        .b_1_ready(b_ready[1]),
        
        .c_valid(c_valid),
        .c_opcode(c_opcode),
        .c_param(c_param),
        .c_size(c_size),
        .c_source(c_source),
        .c_address(c_address),
        .c_data(c_data),
        .c_error(c_error),
        .c_ready(c_ready),
        
        .d_0_valid(d_valid[0]),
        .d_1_valid(d_valid[1]),
        .d_0_opcode(d_opcode[2:0]),
        .d_1_opcode(d_opcode[5:3]),
        .d_0_param(d_param[2:0]),
        .d_1_param(d_param[5:3]),
        .d_0_size(d_size[3:0]),
        .d_1_size(d_size[7:4]),
        .d_0_source(d_source[3:0]),
        .d_1_source(d_source[7:4]),
        .d_0_sink(d_sink[3:0]),
        .d_1_sink(d_sink[7:4]),
        .d_0_data(d_data[511:0]),
        .d_1_data(d_data[1023:512]),
        .d_0_error(d_error[0]),
        .d_1_error(d_error[1]),
        .d_0_ready(d_ready[0]),
        .d_1_ready(d_ready[1]),
        
        .e_valid(e_valid),
        .e_sink(e_sink),
        .e_ready(e_ready),
        
        // L2 Direct Interface (no cache controller)
        .l2_cmd_valid(l2_cmd_valid),
        .l2_cmd_type(l2_cmd_type),
        .l2_cmd_addr(l2_cmd_addr),
        .l2_cmd_data(l2_cmd_data),
        .l2_cmd_size(l2_cmd_size),
        .l2_cmd_dirty(l2_cmd_dirty),
        
        .l2_response_valid(l2_response_valid),
        .l2_response_data(l2_response_data),
        .l2_response_error(l2_response_error)
    );

endmodule 