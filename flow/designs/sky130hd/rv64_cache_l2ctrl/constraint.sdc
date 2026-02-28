current_design rv64_l2_fsm

set clk_name core_clock
set clk_port_name clk
set clk_period 5.0
set clk_io_pct 0.1

set clk_port [get_ports $clk_port_name]

create_clock -name $clk_name -period $clk_period $clk_port

set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] $clk_port]
set non_clock_inputs [lsearch -inline -all -not -exact $non_clock_inputs [get_ports rst_n]]

set io_delay_max [expr $clk_period * $clk_io_pct]
set io_delay_min 0.0

set_input_delay  -max $io_delay_max -clock $clk_name $non_clock_inputs
set_input_delay  -min $io_delay_min -clock $clk_name $non_clock_inputs
set_output_delay -max $io_delay_max -clock $clk_name [all_outputs]
set_output_delay -min $io_delay_min -clock $clk_name [all_outputs]
set_input_delay  -max 0.0 -clock $clk_name [get_ports rst_n]
set_input_delay  -min 0.0 -clock $clk_name [get_ports rst_n]

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 $non_clock_inputs
set_load 0.005 [all_outputs]

set_false_path -from [get_ports rst_n]
set_clock_uncertainty 0.10 [get_clocks $clk_name]
