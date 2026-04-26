#!/bin/bash
# ============================================================================
# build.sh — Modüler SoC build scripti
# ============================================================================

set -e  # Hata varsa dur

cd ~/cv32_sim

# Program dosyasını çalışma dizinine kopyala (Verilator $readmemh için)
cp sw/test_timer.hex ./hello.hex

# Önceki build'i temizle
rm -rf obj_dir

# Verilator derleme
verilator --binary --sv \
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
  $HOME/cv32e40p/rtl/cv32e40p_aligner.sv \
  $HOME/cv32e40p/rtl/cv32e40p_compressed_decoder.sv \
  $HOME/cv32e40p/rtl/cv32e40p_hwloop_regs.sv \
  $HOME/cv32e40p/rtl/cv32e40p_ff_one.sv \
  $HOME/cv32e40p/rtl/cv32e40p_popcnt.sv \
  $HOME/cv32e40p/rtl/cv32e40p_fifo.sv \
  $HOME/cv32e40p/rtl/cv32e40p_alu_div.sv \
  $HOME/cv32e40p/rtl/cv32e40p_apu_disp.sv \
  rtl/ram.sv \
  rtl/uart.sv \
  rtl/gpio.sv \
  rtl/timer.sv \
  rtl/soc_top.sv \
  tb/tb_top.sv \
  --top-module tb_top \
  -Wno-UNOPTFLAT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
  -Wno-TIMESCALEMOD -Wno-BLKANDNBLK -Wno-COMBDLY \
  -Wno-CASEINCOMPLETE -Wno-DECLFILENAME -Wno-PINCONNECTEMPTY \
  -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-GENUNNAMED \
  -Wno-VARHIDDEN -Wno-BLKSEQ \
  -o sim_cv32

echo ""
echo "=== Build basarili. Calistirmak icin: ./obj_dir/sim_cv32 ==="d
