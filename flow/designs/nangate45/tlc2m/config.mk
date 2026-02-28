export DESIGN_NICKNAME = tlc2m
export DESIGN_NAME = tidc_top
export PLATFORM    = nangate45

export VERILOG_FILES = $(sort $(wildcard ./designs/src/$(DESIGN_NICKNAME)/*.v))
export SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

export CORE_UTILIZATION = 45
export PLACE_DENSITY_LB_ADDON = 0.2
export TNS_END_PERCENT = 100