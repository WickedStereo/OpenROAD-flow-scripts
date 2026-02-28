cpu64 L2 Data Cache

Geometry: 256 KiB, 16-way set associative, 64B lines (256 sets). 64-bit addr/data, little-endian.

Interfaces
- CPU-side: OBI-style from L1: req_i,we_i,be_i[7:0],addr_i[63:0],wdata_i[63:0] → gnt_o,rvalid_o,rdata_o[63:0]
- Memory-side: OBI-style to L3: req_o,we_o,be_o[7:0],addr_o[63:0],wdata_o[63:0] ↔ gnt_i,rvalid_i,rdata_i[63:0]
- Maintenance: invalidate_all_i (clears valid/dirty in IDLE)
- Inclusive back-invalidate:
  - From L3→L2: binv_req_i, binv_addr_i[63:0] → binv_ack_o
  - From L2→L1: inv_req_o, inv_addr_o[63:0] ↔ inv_ack_i

Policy
- Write-back + write-allocate. Single outstanding miss. 8×8B beats per line for refill/writeback.
- Inclusive hierarchy: on L2 eviction of a valid line, send back-invalidate to L1 and wait for ack before replacement. If evicted line dirty, write back to L3 first.

Replacement
- 16-way PLRU (tree-based), invalid-first victim selection.

Files
- cpu64_l2_dcache.v: controller + OBI + inclusive invalidation
- cpu64_l2_arrays.v: data/tag/valid/dirty storage, BE-aware word writes
- cpu64_l2_plru.v: 16-way PLRU tree


