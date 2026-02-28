cpu64 L1 Data Cache (Option A)

Geometry: 32 KiB, 8-way set associative, 64B lines (64 sets). 64-bit addr/data, little-endian.

Interfaces
- CPU-side: req_i, we_i, be_i[7:0], addr_i[63:0], wdata_i[63:0] → gnt_o, rvalid_o, rdata_o[63:0]
- Memory-side: req_o, we_o, be_o[7:0], addr_o[63:0], wdata_o[63:0] ↔ gnt_i, rvalid_i, rdata_i[63:0]
- Maintenance: invalidate_all_i (optional). When high in IDLE, clears all valid/dirty bits.

Policy
- Write-back + write-allocate. Store miss triggers Read-For-Ownership (RFO), then BE-merge into the line.
- Single outstanding request. Read hit visible in 1 cycle.
- Refill and writeback transfer full lines in 8×8B beats.

Replacement
- 8-way PLRU (7-bit tree) per set. Invalid-first victim selection. Update on hits and post-refill use.

Timing rules
- gnt_o asserted when a request is accepted in IDLE (hit or miss). rvalid_o only for reads.
- During miss/writeback, further requests are stalled (gnt_o deasserted).
- Refill response occurs only after the full line is refilled; no early return.

BE semantics
- On write hits and post-RFO store, perform byte-enable aware RMW of the target 64b word. Writebacks use be_o=8'hFF per beat.

Files
- cpu64_l1_dcache.v: top-level controller and OBI handshakes
- cpu64_l1_arrays.v: data/tag/valid/dirty arrays with BE-aware word writes
- cpu64_l1_plru.v: 8-way PLRU tree with invalid-first


