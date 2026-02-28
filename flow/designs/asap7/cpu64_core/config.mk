export PLATFORM               = asap7

export DESIGN_NAME            = cpu64_core
export DESIGN_NICKNAME        = cpu64_core

export VERILOG_FILES          = $(shell find ./designs/src/$(DESIGN_NICKNAME) -name "*.v" | grep -v "/cache/" | grep -v "icache" | grep -v "_w_" | sort)
export VERILOG_INCLUDE_DIRS   = ./designs/src/$(DESIGN_NICKNAME)/core
export SDC_FILE               = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

export CORE_UTILIZATION       = 40
export CORE_ASPECT_RATIO      = 1
export CORE_MARGIN            = 2
export PLACE_DENSITY          = 0.35
export PLACE_DENSITY_LB_ADDON = 0.2
export TNS_END_PERCENT        = 100
