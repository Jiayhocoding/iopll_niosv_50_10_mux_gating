package require -exact qsys 26.1

# Add the one-bit Nios V control for the Clock Control IP.  The marker PIO
# already present in the source design is retained and renamed at the HDL API.
add_instance pio_mux_sel altera_avalon_pio 19.2.4
set_instance_parameter_value pio_mux_sel {bitClearingEdgeCapReg} {false}
set_instance_parameter_value pio_mux_sel {bitModifyingOutReg} {false}
set_instance_parameter_value pio_mux_sel {captureEdge} {0}
set_instance_parameter_value pio_mux_sel {direction} {Output}
set_instance_parameter_value pio_mux_sel {edgeType} {RISING}
set_instance_parameter_value pio_mux_sel {generateIRQ} {false}
set_instance_parameter_value pio_mux_sel {irqType} {LEVEL}
set_instance_parameter_value pio_mux_sel {resetValue} {0}
set_instance_parameter_value pio_mux_sel {simDoTestBenchWiring} {false}
set_instance_parameter_value pio_mux_sel {simDrivenValue} {0}
set_instance_parameter_value pio_mux_sel {width} {1}

add_connection clock_in.out_clk pio_mux_sel.clk
add_connection reset_in.out_reset pio_mux_sel.reset
add_connection intel_niosv_g.data_manager pio_mux_sel.s1
set_connection_parameter_value intel_niosv_g.data_manager/pio_mux_sel.s1 baseAddress {0x00090110}
set_connection_parameter_value intel_niosv_g.data_manager/pio_mux_sel.s1 arbitrationPriority {1}
set_connection_parameter_value intel_niosv_g.data_manager/pio_mux_sel.s1 defaultConnection {0}

set_interface_property mux_sel EXPORT_OF pio_mux_sel.external_connection
sync_sysinfo_parameters
save_system mux_gating_control_system.qsys
