///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
// Module Name: bypass_unit                                                                      //
// Description: Bypass unit implements data forwarding for RAW hazard resolution.
//              Forwards data from EXE, MEM, and WB stages to dependent
//              instructions. Detects load-use hazards and manages forwarding
//              multiplexers for source register operands.
//              hazards are detected by this unit, but handling them is left to the user.        //
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////
`include "cpu64_defs.vh"


module cpu64_bypass_unit (
    //===================== Clock and Reset =====================//
    input                   clk_i,              // System clock
    input                   rst_ni,             // Active-low reset

    //===================== Pipeline Control ====================//
    input                   bubble_i,           // Bubble signal (insert NOP)
    input                   stall_i,            // Stall signal (freeze pipeline)
    
    //===================== Forwarded Data from Later Stages ====//
    // Data from EXE stage (1 cycle ahead)
    input                   EXE_mem_read_i,     // EXE stage is doing memory read
    input                   EXE_rd_wr_en_i,     // EXE stage will write to register
    input                   EXE_valid_i,        // EXE stage instruction is valid
    input      [4:0]        EXE_rd_idx_i,       // EXE stage destination register index
    input   [`XLEN-1:0]     EXE_rd_data_i,      // EXE stage result data
    
    // Data from MEM stage (2 cycles ahead)
    input                   MEM_rd_wr_en_i,     // MEM stage will write to register
    input                   MEM_valid_i,        // MEM stage instruction is valid
    input      [4:0]        MEM_rd_idx_i,       // MEM stage destination register index
    input   [`XLEN-1:0]     MEM_rd_data_i,      // MEM stage result data
    
    // Data from WB stage (3 cycles ahead)
    input                   WB_rd_wr_en_i,      // WB stage will write to register
    input                   WB_valid_i,         // WB stage instruction is valid
    input      [4:0]        WB_rd_idx_i,        // WB stage destination register index
    input   [`XLEN-1:0]     WB_rd_data_i,       // WB stage result data

    //===================== Source Register Inputs ==============//
    input      [4:0]        rs_idx_i,           // Source register index to forward
    input   [`XLEN-1:0]     rs_data_i,          // Original register data (from register file)
    input                   rs_used_i,          // Source register is actually used

    //===================== Bypass Outputs ======================//
    output wire [`XLEN-1:0] rs_data_ao,         // Forwarded register data
    output wire             load_use_hazard_ao  // Load-use hazard detected
);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                Retired Instruction Tracker                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // This section handles a special case where an instruction in EXE stage is stalled/bubbled
    // while a MEM stage instruction retires (writes to register file). Without this tracking,
    // the bypass data would become unavailable when the MEM instruction retires.

    // Storage for retired register write during EXE stall/bubble
    reg [`XLEN-1:0] retired_reg_wr_value;  // Value that was written to register file
    reg           retired_reg_wr_valid;    // Valid flag for retired write

    // Detect when EXE stage is waiting (stalled or bubbled)
    wire EXE_waiting = bubble_i || stall_i;

    always @(posedge clk_i) begin
        if (~rst_ni) begin
            // Reset: clear retired write tracking
            retired_reg_wr_value        <= 'b0;
            retired_reg_wr_valid        <= 'b0;            
        end else begin
            //===================== Retired Write Capture =====================//
            // If MEM stage writes to the same register that EXE stage needs,
            // and EXE stage is waiting, capture the retired write value
            if ((MEM_rd_idx_i == rs_idx_i) && MEM_rd_wr_en_i && EXE_waiting) begin
                retired_reg_wr_value    <= MEM_rd_data_i;  // Capture the retired value
                retired_reg_wr_valid    <= 'b1;            // Mark as valid
            end else if (~EXE_waiting)
                // When EXE stage resumes, clear the retired write tracking
                retired_reg_wr_valid    <= 'b0; 
        end
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       Bypass Logic                                        //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // This section implements the core data forwarding logic for RAW hazard resolution.
    // It determines which data source to use based on register conflicts and instruction validity.

    //===================== Conflict Detection =====================//
    // Detect potential register conflicts (same register index)
    reg mem_conflict, exe_conflict;  // Register index conflicts
    reg mem_raw, exe_raw;            // Actual RAW hazards (conflict + valid + used)
    reg [`XLEN-1:0] data_updated;    // Final forwarded data

    always @ (*) begin
        //===================== Register Conflict Detection ================//
        // Check if source register matches destination registers in later stages
        mem_conflict = (rs_idx_i == MEM_rd_idx_i);  // Conflict with MEM stage
        exe_conflict = (rs_idx_i == EXE_rd_idx_i);  // Conflict with EXE stage

        //===================== RAW Hazard Detection =======================//
        // A RAW hazard exists when:
        // 1. Register indices match (conflict detected above)
        // 2. Later stage will write to the register (rd_wr_en_i)
        // 3. Later stage instruction is valid (valid_i)
        // 4. Source register is actually used (rs_used_i)
        // Note: EXE forwarding now safe - uses actual MEM stage data, not self-forwarding
        mem_raw = (mem_conflict && MEM_rd_wr_en_i && MEM_valid_i && rs_used_i);
        exe_raw = (exe_conflict && EXE_rd_wr_en_i && EXE_valid_i && rs_used_i);

        //===================== Data Forwarding Priority ===================//
        // Forward data with priority: EXE > MEM > Retired > Original
        // Higher priority stages have more recent data
        data_updated = rs_data_i;                    // Start with original register data
        if (retired_reg_wr_valid) data_updated = retired_reg_wr_value;  // Use retired write
        if (mem_raw)              data_updated = MEM_rd_data_i;         // Use MEM stage data
        if (exe_raw)              data_updated = EXE_rd_data_i;         // Use EXE stage data (highest priority)
    end

    //===================== Output Generation =====================//
    // Load-use hazard: EXE stage is doing memory read and has RAW conflict
    // This requires a bubble to be inserted (handled by pipeline controller)
    assign load_use_hazard_ao = exe_raw && EXE_mem_read_i;
    
    // Forwarded register data (with proper bypass priority)
    assign rs_data_ao         = data_updated;

endmodule
