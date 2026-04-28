#!/bin/bash
# build_axi.sh -- OBI to AXI4-Lite Bridge Bagimsiz Build & Run
#
# Kullanim: ./build_axi.sh
# Cikti: obj_dir_axi/Vobi_to_axi_lite_tb (binary) + simulation log

set -e

cd "$(dirname "$0")"

echo "=== AXI Bridge Build ==="
verilator --binary -j 0 \
    --top-module obi_to_axi_lite_tb \
    --timing \
    --Mdir obj_dir_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    rtl/obi_to_axi_lite.sv \
    tb/obi_to_axi_lite_tb.sv

echo ""
echo "=== AXI Bridge Run ==="
./obj_dir_axi/Vobi_to_axi_lite_tb
