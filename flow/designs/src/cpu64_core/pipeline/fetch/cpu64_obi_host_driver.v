///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_obi_host_driver                                                           //
// Description: This module handles driving memory reads and writes through an OBI interface.    //
//              It manages request and response stalls internally, including re-winding outputs  //
//              during stalls. The OBI (Open Bus Interface) is a subset of the OBI specification //
//              designed for simple, efficient memory access with proper handshaking protocols.  //
//              This driver handles the complex state machine required for reliable memory        //
//              transactions including request/response coordination and stall management.       //
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
// Open Bus Interface Host Driver
module cpu64_obi_host_driver #(
    parameter DATA_W  = 64,                    // Data width (64 bits for RV64)
    parameter ADDR_W  = 39,                    // Address width (39 bits for RV64)
    parameter BE_BITS = (DATA_W / 8 )          // Byte enable bits (8 bits for 64-bit data)
    ) (
    //===================== Clock and Reset =====================//
    input                   clk_i,              // System clock
    input                   rst_ni,             // Active-low reset

    //===================== Memory Interface ===================//
    input                   gnt_i,              // Memory grant signal
    input                   rvalid_i,           // Memory read valid signal

    //===================== Pipeline Control ===================//
    input                   stall_i,            // Pipeline stall signal

    //===================== Host Memory Controls ===============//
    input [BE_BITS-1:0]     be_i,               // Byte enable strobe
    input [ADDR_W-1:0]      addr_i,             // Memory address
    input [DATA_W-1:0]      wdata_i,            // Write data
    input                   rd_i,               // Read request
    input                   wr_i,               // Write request

    //===================== Memory Interface Outputs ===========//
    output wire                 stall_ao,       // Output stall signal
    output wire                 req_o,          // Memory request signal
    output wire                 we_ao,          // Memory write enable
    output wire [BE_BITS-1:0]   be_ao,          // Memory byte enable
    output wire [ADDR_W-1:0]    addr_ao,        // Memory address
    output wire [DATA_W-1:0]    wdata_ao        // Memory write data
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       Output Rewinder                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // The output rewinder saves the current memory transaction parameters when a stall occurs
    // and restores them when the stall ends. This ensures that memory transactions are not
    // lost during pipeline stalls and that the memory interface sees consistent signals.

    //===================== Saved Transaction Parameters ========//
    reg [ADDR_W-1:0]    addr_saved;     // Saved memory address
    reg [DATA_W-1:0]    wdata_saved;    // Saved write data
    reg [BE_BITS-1:0]   be_saved;       // Saved byte enable strobe
    reg                 we_saved;       // Saved write enable
    reg                 read_saved;     // Saved read enable
    
    //===================== Control Signals =====================//
    wire                read;           // Current read signal (stall-aware)
    wire                req;            // Current request signal
    wire                stall;          // Combined stall signal

    //===================== Output Rewinder Logic ===============//
    // Save transaction parameters when not stalled and request is active
    // Restore saved parameters when stalled to maintain transaction consistency
    always @(posedge clk_i) begin
        if (!rst_ni) begin
            // Reset: clear all saved parameters
            read_saved  <= 'b0;
            we_saved    <= 'b0;
            be_saved    <= 'b0;
            addr_saved  <= 'b0;
            wdata_saved <= 'b0;
        end else if (~memory_stall && req) begin
            // Not stalled and request active: save current parameters
            read_saved  <= rd_i;        // Save read enable
            we_saved    <= wr_i;        // Save write enable
            be_saved    <= be_i;        // Save byte enable strobe
            addr_saved  <= addr_i;      // Save memory address
            wdata_saved <= wdata_i;     // Save write data
        end
    end

    //===================== Stall-Aware Read Signal =============//
    // Use saved read signal when memory-stalled, current read signal when not memory-stalled
    wire memory_stall = request_stall_r || response_stall_a;
    assign read = (memory_stall) ? read_saved : rd_i;


    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 Transaction State Machine                                 //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // The transaction state machine manages the OBI protocol handshaking between the host and memory.
    // It handles request/response coordination, stall conditions, and ensures proper transaction
    // ordering. The state machine tracks outstanding read transactions and manages both request
    // and response stalls to maintain protocol compliance.

    //===================== State Machine Registers =============//
    reg  read_outstanding;    // Read transaction is outstanding (waiting for response)
    reg  write_accepted;      // Write transaction accepted this cycle
    reg  request_stall_r;     // Request stall register (delayed request_stall_a)
    reg  response_stall_r;    // Response stall register (prevents glitches)
    
    //===================== State Machine Wires ================//
    wire read_accepted;       // Read transaction has been accepted by memory

    //===================== Stall Condition Detection ===========//
    // Response stall: waiting for read response when read is outstanding
    wire response_stall_a = read_outstanding ? ~rvalid_i : 'b0;
    // Request stall: waiting for memory grant when request is active
    wire request_stall_a  = req && (~gnt_i);

    //===================== State Machine Update ================//
    // Update state machine registers on clock edge
    always @(posedge clk_i) begin
        if (~rst_ni) begin
            read_outstanding  <= 'b0;        // Reset: no outstanding reads
            write_accepted    <= 'b0;        // Reset: no write accepted
            request_stall_r   <= 'b0;        // Reset: no request stall
            response_stall_r  <= 'b0;        // Reset: no response stall
        end else begin
            read_outstanding  <= read_accepted;  // Update outstanding read status
            write_accepted    <= (wr_i && req && gnt_i);  // Write accepted this cycle
            request_stall_r   <= request_stall_a; // Update request stall status
            response_stall_r  <= response_stall_a; // Register response stall to prevent glitches
        end
    end

    //===================== State Machine Logic =================//
    // Determine read acceptance and request generation based on current state  
    // Fixed: Only accept NEW read if no outstanding read exists (prevents AMO double-execution)
    assign read_accepted = (read_outstanding && ~rvalid_i) || (read && req && gnt_i && ~read_outstanding);
    // Generate request: allow back-to-back for IMEM (DATA_W=32), not for DMEM (DATA_W=64)
    assign req = (~read_outstanding || (DATA_W == 32 ? rvalid_i : 1'b0)) && (read || (wr_i && !write_accepted));
    
    //===================== Combined Stall Signal ===============//
    // Stall when any of: request stall, response stall, or pipeline stall
    // Use registered response_stall to prevent one-cycle glitches during load operations
    assign stall = request_stall_r || response_stall_r || stall_i;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          Outputs                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Generate memory interface outputs with proper stall handling
    // Use saved values when stalled to maintain transaction consistency

    //===================== Memory Interface Outputs =============//
    // Use saved values when memory-stalled, current values when not memory-stalled
    assign we_ao    = (memory_stall) ? we_saved    : wr_i;        // Write enable output
    assign be_ao    = (memory_stall) ? be_saved    : be_i;        // Byte enable output
    assign addr_ao  = addr_i;                                     // Address output - always use current address
    assign wdata_ao = (memory_stall) ? wdata_saved : wdata_i;     // Write data output
    
    //===================== Control Outputs ======================//
    assign req_o    = req;                                  // Memory request output
    assign stall_ao = (request_stall_r || response_stall_a); // Output stall signal (excludes pipeline stall)

`ifdef CPU64_DBG_TRACE
    //===================== Debug Trace ==========================//
    always @(posedge clk_i) begin
        if (rst_ni && req_o && gnt_i) begin
            $display("[OBI_HOST] rd=%0b wr=%0b addr=0x%0h be=0x%0h wdata=0x%0h rvalid=%0b stall=%0b", 
                     read, wr_i, addr_ao, be_ao, wdata_ao, rvalid_i, stall);
        end
        if (rst_ni && (request_stall_a || response_stall_a)) begin
            $display("[OBI_HOST] stall cause req_stall=%0b resp_stall=%0b read_out=%0b req=%0b rd_i=%0b wr_i=%0b gnt_i=%0b rvalid_i=%0b", 
                     request_stall_a, response_stall_a, read_outstanding, req, rd_i, wr_i, gnt_i, rvalid_i);
        end
    end
`endif


endmodule 

