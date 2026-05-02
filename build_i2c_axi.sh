#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "=== I2C AXI Build ==="
verilator --binary -j 0 \
    --top-module i2c_master_axi_tb \
    --timing \
    --Mdir obj_dir_i2c_axi \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    rtl/i2c_master_axi.sv \
    tb/i2c_master_axi_tb.sv
echo ""
echo "=== I2C AXI Run ==="
./obj_dir_i2c_axi/Vi2c_master_axi_tb
