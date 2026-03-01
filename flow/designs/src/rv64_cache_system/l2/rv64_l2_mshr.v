`timescale 1ns/1ps

module rv64_l2_mshr #(
    parameter ADDR_W = 64,
    parameter SOURCE_W = 6, // 4 (L1 Source) + 2 (Client ID)
    parameter TYPE_W = 3,   // Opcode
    parameter CORES = 4
) (
    input  wire clk,
    input  wire rst_n,

    // Allocation Interface
    input  wire                     alloc_req,
    input  wire [ADDR_W-1:0]        alloc_addr,
    input  wire [SOURCE_W-1:0]      alloc_source,
    input  wire [TYPE_W-1:0]        alloc_type,
    output wire                     alloc_ready, // 1 if MSHR is free

    // Deallocation Interface
    input  wire                     dealloc_req,

    // Probe Management
    // FSM sets the initial set of probes to wait for
    input  wire                     set_probes,
    input  wire [CORES-1:0]         probes_mask,
    
    // Probe Ack (clears bit for specific core)
    input  wire                     probe_ack,
    input  wire [$clog2(CORES)-1:0] probe_ack_id,

    // Status Outputs
    output wire                     valid,
    output wire [ADDR_W-1:0]        addr,
    output wire [SOURCE_W-1:0]      source,
    output wire [TYPE_W-1:0]        req_type,
    output wire [CORES-1:0]         pending_probes
);

    reg                     valid_q;
    reg [ADDR_W-1:0]        addr_q;
    reg [SOURCE_W-1:0]      source_q;
    reg [TYPE_W-1:0]        req_type_q;
    reg [CORES-1:0]         pending_probes_q;

    assign alloc_ready = !valid_q;
    
    assign valid          = valid_q;
    assign addr           = addr_q;
    assign source         = source_q;
    assign req_type           = req_type_q;
    assign pending_probes = pending_probes_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_q <= 1'b0;
            addr_q <= {ADDR_W{1'b0}};
            source_q <= {SOURCE_W{1'b0}};
            req_type_q <= {TYPE_W{1'b0}};
            pending_probes_q <= {CORES{1'b0}};
        end else begin
            if (dealloc_req) begin
                valid_q <= 1'b0;
                pending_probes_q <= {CORES{1'b0}};
            end else if (alloc_req && !valid_q) begin
                valid_q <= 1'b1;
                addr_q <= alloc_addr;
                source_q <= alloc_source;
                req_type_q <= alloc_type;
                pending_probes_q <= {CORES{1'b0}}; // Initially 0, FSM sets it later
            end else begin
                // Probe Management
                if (set_probes) begin
                    pending_probes_q <= probes_mask;
                end else if (probe_ack) begin
                    pending_probes_q[probe_ack_id] <= 1'b0;
                end
            end
        end
    end

endmodule
