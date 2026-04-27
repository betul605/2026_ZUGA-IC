#!/bin/bash
# ============================================================================
# build_i2c.sh -- I2C Master bagimsiz build (Faz 1 testi)
#
# I2C Master modulunu kendi testbench'i ile build eder ve calistirir.
# Mevcut SoC build.sh'ten bagimsiz - regression riski yok.
# ============================================================================

set -e

cd ~/cv32_sim

echo "=== I2C Master bagimsiz build ==="

# obj_dir/i2c klasorunu temizle
rm -rf obj_dir_i2c
mkdir -p obj_dir_i2c

verilator --binary --sv \
    -Wno-fatal -Wno-PINMISSING -Wno-WIDTH \
    --top-module i2c_master_tb \
    --Mdir obj_dir_i2c \
    -o sim_i2c \
    rtl/i2c_master.sv \
    tb/i2c_master_tb.sv

echo "=== Build basarili. Calistirmak icin: ./obj_dir_i2c/sim_i2c ==="
