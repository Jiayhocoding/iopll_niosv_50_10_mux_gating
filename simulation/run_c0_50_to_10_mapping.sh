#!/bin/sh
set -eu

mkdir -p simulation/build
iverilog -g2012 -Wall \
    -o simulation/build/tb_c0_50_to_10_mapping \
    rtl/nios_iopll_bridge.sv rtl/hvio_master.sv \
    simulation/tb_c0_50_to_10_mapping.sv
vvp simulation/build/tb_c0_50_to_10_mapping
