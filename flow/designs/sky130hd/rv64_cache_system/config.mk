export DESIGN_NICKNAME = rv64_cache_system
export DESIGN_NAME     = rv64_cache_system
export PLATFORM        = sky130hd

export VERILOG_FILES_ALL = $(sort $(wildcard ./designs/src/$(DESIGN_NICKNAME)/*.v \
                       ./designs/src/$(DESIGN_NICKNAME)/l1/*.v \
                       ./designs/src/$(DESIGN_NICKNAME)/l2/*.v \
                       ./designs/src/$(DESIGN_NICKNAME)/system/*.v \
                       ./designs/src/$(DESIGN_NICKNAME)/xbar/*.v))

export VERILOG_FILES = $(filter-out %/rv64_l2_probe_block.v %/rv64_l2_grant_update_block.v %/rv64_l2_macros_bb.v, $(VERILOG_FILES_ALL))
export VERILOG_FILES += ./designs/src/rv64_cache_system/l2/rv64_l2_macros_bb.v

export VERILOG_FILES += ./designs/src/rv64_cache_system/sky130ram_bb.v

export VERILOG_INCLUDE_DIRS = ./designs/src/$(DESIGN_NICKNAME)

export SDC_FILE      = ./designs/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

export ADDITIONAL_LEFS = \
    ./platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8.lef \
    ./platforms/sky130ram/sky130_sram_1rw1r_80x64_8/sky130_sram_1rw1r_80x64_8.lef \
    ./platforms/sky130ram/sky130_sram_1rw1r_128x256_8/sky130_sram_1rw1r_128x256_8.lef \
    ./platforms/sky130ram/sky130_sram_1rw1r_44x64_8/sky130_sram_1rw1r_44x64_8.lef \
    ./results/sky130hd/rv64_l2_probe_block/base/rv64_l2_probe_block.lef \
    ./results/sky130hd/rv64_l2_grant_update_block/base/rv64_l2_grant_update_block.lef

export ADDITIONAL_LIBS = \
    ./platforms/sky130ram/sky130_sram_1rw1r_64x256_8/sky130_sram_1rw1r_64x256_8_TT_1p8V_25C.lib \
    ./platforms/sky130ram/sky130_sram_1rw1r_80x64_8/sky130_sram_1rw1r_80x64_8_TT_1p8V_25C.lib \
    ./platforms/sky130ram/sky130_sram_1rw1r_128x256_8/sky130_sram_1rw1r_128x256_8_TT_1p8V_25C.lib \
    ./platforms/sky130ram/sky130_sram_1rw1r_44x64_8/sky130_sram_1rw1r_44x64_8_TT_1p8V_25C.lib \
    ./results/sky130hd/rv64_l2_probe_block/base/rv64_l2_probe_block.lib \
    ./results/sky130hd/rv64_l2_grant_update_block/base/rv64_l2_grant_update_block.lib
export SYNTH_HIERARCHICAL = 1
export SYNTH_MEMORY_MAX_BITS = 4000000

export CORE_UTILIZATION = 20
export PLACE_DENSITY ?= 0.45

export TNS_END_PERCENT = 100

export EQUIVALENCE_CHECK ?= 1
export REMOVE_CELLS_FOR_EQY = sky130_fd_sc_hd__tapvpwrvgnd*
