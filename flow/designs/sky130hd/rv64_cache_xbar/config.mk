export DESIGN_NICKNAME = rv64_cache_xbar
export DESIGN_NAME     = tl_socket_m1
export PLATFORM        = sky130hd

export VERILOG_FILES = $(sort $(wildcard ./designs/src/rv64_cache_system/xbar/*.v))

export SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

export PLACE_DENSITY ?= 0.60
export DIE_AREA   = 0 0 950 950
export CORE_AREA  = 10 10 940 940

export TNS_END_PERCENT = 100

export EQUIVALENCE_CHECK = 0
export REMOVE_CELLS_FOR_EQY = sky130_fd_sc_hd__tapvpwrvgnd*
