#!/bin/sh
set -eu
mkdir -p simulation/build
iverilog -g2012 -Wall \
    -o simulation/build/tb_iopll_runtime_diag \
    rtl/hvio_master.sv simulation/tb_iopll_runtime_diag.sv
vvp simulation/build/tb_iopll_runtime_diag
