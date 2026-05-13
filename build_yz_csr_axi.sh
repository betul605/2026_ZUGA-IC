#!/bin/bash
# build_yz_csr_axi.sh -- YZ CSR (M65) Bagimsiz Build & Run
set -e
cd "$(dirname "$0")"

echo "=== YZ CSR Build ==="
verilator --binary -j 0 \
    --top-module yz_csr_axi_tb \
    --Mdir obj_dir_yz_csr \
    -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-INITIALDLY \
    rtl/yz_csr.sv \
    tb/yz_csr_axi_tb.sv

echo ""
echo "=== YZ CSR Run ==="
./obj_dir_yz_csr/Vyz_csr_axi_tb
