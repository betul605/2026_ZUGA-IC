#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "=== GPIO AXI Build ==="
verilator --binary -j 0 \
    --top-module gpio_axi_tb \
    --timing \
    --Mdir obj_dir_gpio_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    tb/axi_lite_assertions.sv \
    rtl/gpio_axi.sv \
    tb/gpio_axi_tb.sv
echo ""
echo "=== GPIO AXI Run ==="
./obj_dir_gpio_axi/Vgpio_axi_tb
