export DESIGN_NICKNAME = rv64_cache_l2ctrl
export DESIGN_NAME     = rv64_l2_fsm
export PLATFORM        = sky130hd

export VERILOG_FILES = ./designs/src/rv64_cache_system/l2/rv64_l2_fsm.v \
					   ./designs/src/rv64_cache_system/l2/rv64_l2_dir_lookup.v \
					   ./designs/src/rv64_cache_system/l2/rv64_l2_probe_planner.v \
					   ./designs/src/rv64_cache_system/l2/rv64_l2_probe_engine.v \
					   ./designs/src/rv64_cache_system/l2/rv64_l2_grant_update_engine.v \
					   ./designs/src/rv64_cache_system/l2/rv64_l2_plru.v
export VERILOG_INCLUDE_DIRS = ./designs/src/rv64_cache_system
export SYNTH_HIERARCHICAL = 1
export HIER_REPORT_SCRIPT = ./designs/sky130hd/rv64_cache_l2ctrl/hier_report_fixed.tcl

export SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc
export FASTROUTE_TCL = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/fastroute.tcl

export CORE_UTILIZATION = 15
export PLACE_DENSITY ?= 0.45
export DIE_AREA = 0 0 1400 1400
export CORE_AREA = 20 20 1380 1380

export TNS_END_PERCENT = 100

export EQUIVALENCE_CHECK ?= 0
export REMOVE_CELLS_FOR_EQY = sky130_fd_sc_hd__tapvpwrvgnd*
