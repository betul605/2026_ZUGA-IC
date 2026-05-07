#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "=== Dual UART AXI Build ==="
verilator --binary -j 0 \
    --top-module uart_dual_axi_tb \
    --timing \
    --Mdir obj_dir_uart_dual_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    tb/axi_lite_assertions.sv \
    rtl/uart_axi.sv \
    tb/uart_dual_axi_tb.sv
echo ""
echo "=== Dual UART AXI Run ==="
./obj_dir_uart_dual_axi/Vuart_dual_axi_tb
