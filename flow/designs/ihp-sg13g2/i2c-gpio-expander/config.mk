export DESIGN_NAME = I2cGpioExpanderTop
export DESIGN_NICKNAME = i2c-gpio-expander
export PLATFORM = ihp-sg13g2

export VERILOG_FILES = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/$(DESIGN_NAME).v \
                       $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/I2cGpioExpander.v
export SDC_FILE = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/constraint.sdc

export SEAL_GDS = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/sealring.gds.gz

export DIE_AREA = 0.0 0.0 1050.24 1050.84
export CORE_AREA = 351.36 351.54 699.84 699.3

export MAX_ROUTING_LAYER = TopMetal2

export TNS_END_PERCENT = 100
export PLACE_DENSITY = 0.75
export MACRO_PLACE_HALO = 20 20
export CORNERS = slow fast

export IO_NORTH_PINS = sg13g2_IOPad_io_gpio_3 \
sg13g2_IOPad_io_gpio_4 \
sg13g2_IOPad_io_gpio_5 \
sg13g2_IOPad_io_gpio_6 \
sg13g2_IOPad_io_gpio_7
export IO_EAST_PINS = sg13g2_IOPadVdd_inst \
sg13g2_IOPadVss_inst \
sg13g2_IOPad_io_address_0 \
sg13g2_IOPad_io_address_1 \
sg13g2_IOPad_io_address_2
export IO_SOUTH_PINS = sg13g2_IOPad_io_clock \
sg13g2_IOPad_io_reset \
sg13g2_IOPad_io_i2c_scl \
sg13g2_IOPad_io_i2c_sda \
sg13g2_IOPad_io_i2c_interrupt
export IO_WEST_PINS = sg13g2_IOPad_io_gpio_0 \
sg13g2_IOPad_io_gpio_1 \
sg13g2_IOPad_io_gpio_2 \
sg13g2_IOPadIOVss_inst \
sg13g2_IOPadIOVdd_inst
export FOOTPRINT_TCL = $(PLATFORM_DIR)/pad.tcl

export PDN_TCL = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/pdn.tcl

export BLOCKS = I2cDeviceCtrl

export LEC_CHECK = 0

