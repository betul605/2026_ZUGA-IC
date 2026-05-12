#!/bin/bash
# build_uart_rx_axi.sh -- UART RX (M53) Bagimsiz Build & Run
# Cikti: obj_dir_uart_rx/Vuart_rx_axi_tb (binary)
set -e
cd "$(dirname "$0")"

echo "=== UART RX Build ==="
verilator --binary --timing -j 0 \
    --top-module uart_rx_axi_tb \
    --Mdir obj_dir_uart_rx \
    -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-INITIALDLY \
    rtl/uart_axi.sv \
    tb/uart_rx_axi_tb.sv

echo ""
echo "=== UART RX Run ==="
./obj_dir_uart_rx/Vuart_rx_axi_tb
