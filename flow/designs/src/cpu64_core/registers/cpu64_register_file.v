///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: cpu64_register_file                                                             //
// Description: 31-register file with read-only-zero x0 register. Provides asynchronous
//              reads and synchronous writes with bypass logic for RAW hazard
//              resolution. Implements data forwarding from writeback stage.
//              This register file implements the RISC-V general-purpose register file
//              with 31 registers (x1-x31) plus the hardwired zero register (x0).
//              Features include asynchronous reads, synchronous writes, and bypass
//              logic to resolve Read-After-Write (RAW) hazards.
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////


module cpu64_register_file #( parameter XLEN = 64 ) (
    //===================== Clock ===============================//
    input                  clk_i,              // System clock

    //===================== Register Addresses ==================//
    input            [4:0] rs1_idx_i,          // Register source 1 index (0-31)
    input            [4:0] rs2_idx_i,          // Register source 2 index (0-31)
    input            [4:0] rd_idx_i,           // Destination register index (0-31)

    //===================== Write Interface =====================//
    input       [XLEN-1:0] wr_data_i,          // Write data input (64-bit)
    input                  wr_en_i,            // Write enable strobe

    //===================== Read Interface ======================//
    output reg [XLEN-1:0] rs1_data_ao,         // Source register 1 data output (async)
    output reg [XLEN-1:0] rs2_data_ao          // Source register 2 data output (async)
);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Register File Storage                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // 31-register array (x1-x31), x0 is hardwired to zero
    // Only 31 registers are implemented as x0 is always zero

    reg [XLEN-1:0] RF [31:1];     // Register file array (31 registers, 64-bit each)
    
    // Initialize register file to zero on reset
    integer i;
    initial begin
        for (i = 1; i <= 31; i = i + 1) begin
            RF[i] = 64'h0;
        end
    end
    
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Bypass Logic Signals                                   //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Bypass logic for RAW hazard resolution
    // Forward write data to read ports when reading and writing the same register

    reg            rs1_bypass;    // Bypass enable for source register 1
    reg            rs2_bypass;    // Bypass enable for source register 2
    reg [XLEN-1:0] rs1_rdata;     // Raw read data for source register 1
    reg [XLEN-1:0] rs2_rdata;     // Raw read data for source register 2

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Read Control Logic                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Asynchronous read logic with bypass for RAW hazard resolution
    // Implements the RISC-V requirement that x0 always reads as zero

    always @(*) begin
        //===================== Bypass Detection =================//
        // Detect when we need to bypass write data to read ports
        // This happens when reading and writing the same register in the same cycle
        rs1_bypass = (rs1_idx_i == rd_idx_i) && wr_en_i;  // Bypass rs1 if same as write register
        rs2_bypass = (rs2_idx_i == rd_idx_i) && wr_en_i;  // Bypass rs2 if same as write register

        //===================== Data Selection ===================//
        // Select between bypassed write data or register file data
        // This implements data forwarding to resolve RAW hazards
        rs1_rdata  = rs1_bypass ? wr_data_i : RF[rs1_idx_i];  // Use write data if bypassing
        rs2_rdata  = rs2_bypass ? wr_data_i : RF[rs2_idx_i];  // Use write data if bypassing

        //===================== Zero Register Handling ===========//
        // RISC-V requirement: x0 always reads as zero
        // This is implemented by checking the register index
        rs1_data_ao = (rs1_idx_i != 'b0) ? rs1_rdata : 'b0;  // Return zero for x0
        rs2_data_ao = (rs2_idx_i != 'b0) ? rs2_rdata : 'b0;  // Return zero for x0
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    Write Control Logic                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // Synchronous write logic with x0 protection
    // Only writes to registers x1-x31, never to x0

    always @ (posedge clk_i) begin
        //===================== Write Enable and x0 Protection ===//
        // Only write if write enable is asserted and not writing to x0
        // This prevents writes to the hardwired zero register
        if(wr_en_i && (rd_idx_i != 'b0)) begin
            RF[rd_idx_i] <= wr_data_i;  // Write data to register file
        end
    end

 endmodule
