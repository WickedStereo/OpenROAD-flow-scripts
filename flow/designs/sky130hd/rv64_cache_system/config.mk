export DESIGN_NICKNAME = rv64_cache_system
export DESIGN_NAME     = rv64_cache_system
export PLATFORM        = sky130hd

export VERILOG_FILES = $(sort $(wildcard ./designs/src/$(DESIGN_NICKNAME)/*.v \
                       ./designs/src/$(DESIGN_NICKNAME)/l1/*.v \
                       ./designs/src/$(DESIGN_NICKNAME)/l2/*.v \
                       ./designs/src/$(DESIGN_NICKNAME)/system/*.v \
                       ./designs/src/$(DESIGN_NICKNAME)/xbar/*.v))

export VERILOG_INCLUDE_DIRS = ./designs/src/$(DESIGN_NICKNAME)

export SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

export SYNTH_HIERARCHICAL = 1
export SYNTH_MEMORY_MAX_BITS = 4000000

export CORE_UTILIZATION = 20
export PLACE_DENSITY ?= 0.45

export TNS_END_PERCENT = 100

export EQUIVALENCE_CHECK ?= 1
export REMOVE_CELLS_FOR_EQY = sky130_fd_sc_hd__tapvpwrvgnd*
