#!/bin/bash
# lint_soc_top_axi.sh - soc_top_axi.sv lint kontrolu
set -e
cd "$(dirname "$0")"

echo "=== soc_top_axi.sv Lint Kontrolu ==="
echo ""

verilator --lint-only --sv \
    -Wno-UNUSEDSIGNAL \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    -Wno-CASEINCOMPLETE \
    --top-module soc_top_axi \
    -I$HOME/cv32e40p/rtl \
    -I$HOME/cv32e40p/rtl/include \
    -I$HOME/cv32e40p/bhv \
    $HOME/cv32e40p/rtl/include/cv32e40p_pkg.sv \
    $HOME/cv32e40p/rtl/include/cv32e40p_apu_core_pkg.sv \
    $HOME/cv32e40p/rtl/include/cv32e40p_fpu_pkg.sv \
    $HOME/cv32e40p/bhv/cv32e40p_sim_clock_gate.sv \
    $HOME/cv32e40p/rtl/cv32e40p_core.sv \
    $HOME/cv32e40p/rtl/cv32e40p_if_stage.sv \
    $HOME/cv32e40p/rtl/cv32e40p_id_stage.sv \
    $HOME/cv32e40p/rtl/cv32e40p_ex_stage.sv \
    $HOME/cv32e40p/rtl/cv32e40p_load_store_unit.sv \
    $HOME/cv32e40p/rtl/cv32e40p_controller.sv \
    $HOME/cv32e40p/rtl/cv32e40p_cs_registers.sv \
    $HOME/cv32e40p/rtl/cv32e40p_decoder.sv \
    $HOME/cv32e40p/rtl/cv32e40p_alu.sv \
    $HOME/cv32e40p/rtl/cv32e40p_mult.sv \
    $HOME/cv32e40p/rtl/cv32e40p_register_file_ff.sv \
    $HOME/cv32e40p/rtl/cv32e40p_sleep_unit.sv \
    $HOME/cv32e40p/rtl/cv32e40p_int_controller.sv \
    $HOME/cv32e40p/rtl/cv32e40p_obi_interface.sv \
    $HOME/cv32e40p/rtl/cv32e40p_prefetch_buffer.sv \
    $HOME/cv32e40p/rtl/cv32e40p_prefetch_controller.sv \
    $HOME/cv32e40p/rtl/cv32e40p_alu_div.sv \
    $HOME/cv32e40p/rtl/cv32e40p_ff_one.sv \
    $HOME/cv32e40p/rtl/cv32e40p_popcnt.sv \
    $HOME/cv32e40p/rtl/cv32e40p_compressed_decoder.sv \
    rtl/obi_to_axi_lite.sv \
    rtl/ram_axi.sv \
    rtl/gpio_axi.sv \
    rtl/timer_axi.sv \
    rtl/uart_axi.sv \
    rtl/i2c_master_axi.sv \
    rtl/soc_top_axi.sv

if [ $? -eq 0 ]; then
    echo ""
    echo "=== LINT BASARILI: 0 ERROR ==="
fi
