#**************************************************************
# This .sdc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
# CLOCK
create_clock -period "50MHz" [get_ports CLOCK0_50]


#**************************************************************
# Create Generated Clock
#**************************************************************
# Agilex 5 IOPLL clocks are created by the generated IP SDC.


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

# The request PIO is synchronous to CLOCK0_50 and only drives the RTL state
# machine. Clock Control IP handles the gate-enable and mux clock crossings.

# Clock Control IP consumes these asynchronous control requests with its own
# negative-latch/root-gate and glitch-free switchover circuitry. Conventional
# synchronous setup/hold timing from the 50 MHz controller to those internal
# clock-domain registers is not applicable; functional safety is enforced by
# the controller sequence and the dedicated IP resources.
set_false_path \
    -from [get_registers {*u_mux_gating_switch_controller|mux_select_10mhz*}] \
    -to   [get_registers {*u_mux_clock_control|*clksel_inst|ena_r0*}]
set_false_path \
    -from [get_registers {*u_mux_gating_switch_controller|gate_50_enable*}] \
    -to   [get_registers {*u_mux_gating_gate_50|*clkena_inst*en_reg*}]
set_false_path \
    -from [get_registers {*u_mux_gating_switch_controller|gate_10_enable*}] \
    -to   [get_registers {*u_mux_gating_gate_10|*clkena_inst*en_reg*}]



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************
