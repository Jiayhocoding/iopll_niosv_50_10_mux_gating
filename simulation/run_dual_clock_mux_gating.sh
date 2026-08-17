#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

for prepare_cycles in 0 1 2 4 8 16 32; do
  output="build/tb_dual_clock_mux_gating_${prepare_cycles}"
  iverilog -g2012 \
    -Ptb_dual_clock_mux_gating.PREPARE_CYCLES="${prepare_cycles}" \
    -o "${output}" \
    ../rtl/mux_gating_switch_controller.sv \
    ../ip/mux_clock_control/mux_clock_control/sim/mux_clock_control.v \
    ../ip/mux_clock_control/mux_clock_control/intelclkctrl_201/sim/*.v \
    tb_dual_clock_mux_gating.sv
  vvp "${output}"
done
