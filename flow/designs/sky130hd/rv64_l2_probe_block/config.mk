export DESIGN_NICKNAME = rv64_l2_probe_block
export DESIGN_NAME     = rv64_l2_probe_block
export PLATFORM        = sky130hd

export VERILOG_FILES = ./designs/src/rv64_cache_system/l2/rv64_l2_probe_block.v \
                       ./designs/src/rv64_cache_system/l2/rv64_l2_probe_planner.v \
                       ./designs/src/rv64_cache_system/l2/rv64_l2_probe_engine.v

export SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

export SYNTH_HIERARCHICAL = 1
export CORE_UTILIZATION = 25
export PLACE_DENSITY ?= 0.50
export DIE_AREA = 0 0 300 300
export CORE_AREA = 10 10 290 290

export TNS_END_PERCENT = 100
export HOLD_SLACK_MARGIN = 0.05
export MAX_BUFFER_PERCENT = 80

export EQUIVALENCE_CHECK ?= 0
export REMOVE_CELLS_FOR_EQY = sky130_fd_sc_hd__tapvpwrvgnd*
