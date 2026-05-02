#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "=== UART AXI Build ==="
verilator --binary -j 0 \
    --top-module uart_axi_tb \
    --timing \
    --Mdir obj_dir_uart_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    rtl/uart_axi.sv \
    tb/uart_axi_tb.sv
echo ""
echo "=== UART AXI Run ==="
./obj_dir_uart_axi/Vuart_axi_tb
