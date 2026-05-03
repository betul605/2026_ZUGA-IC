#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "=== Timer AXI Build ==="
verilator --binary -j 0 \
    --top-module timer_axi_tb \
    --timing \
    --Mdir obj_dir_timer_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    tb/axi_lite_assertions.sv \
    rtl/timer_axi.sv \
    tb/timer_axi_tb.sv
echo ""
echo "=== Timer AXI Run ==="
./obj_dir_timer_axi/Vtimer_axi_tb
