# ============================================================================
# compile_user_design.tcl  -- ZUGA-IC tasarim dosyalarini Vivado projesine ekler
#
# DIKKAT: Tum yollar "teknotest" klasorune gore RELATIVE'dir (absolute YASAK).
# Dizin yerlesimi (repo kokunde):
#   2026_ZUGA-IC/
#   ├── rtl/                 (mevcut tasarim)        -> ../../rtl
#   ├── cv32e40p/            (cekirdek IP)           -> ../../cv32e40p
#   └── dtr_demo/
#       ├── rtl/             (demo override RTL)     -> ../rtl
#       └── teknotest/       (BU KLASOR; cwd burasi)
# ============================================================================

# --- CV32E40P paketleri (once derlenmeli) + cekirdek RTL ---
add_files [glob ../../cv32e40p/rtl/include/*.sv]
add_files [glob ../../cv32e40p/rtl/*.sv]
add_files ../../cv32e40p/bhv/cv32e40p_sim_clock_gate.sv

# --- ZUGA-IC cevre birimleri (mevcut, degistirilmemis repo dosyalari) ---
add_files ../../rtl/obi_to_axi_lite.sv
add_files ../../rtl/ram_axi.sv
add_files ../../rtl/gpio_axi.sv
add_files ../../rtl/timer_axi.sv
add_files ../../rtl/uart_axi.sv
add_files ../../rtl/i2c_master_axi.sv

# --- TEKNOTEST demo'ya ozel RTL ---
#   uart_tek_axi.sv : EK-2/helloworld.c uyumlu UART (CFG[0] yazimi TX baslatir)
#   soc_top_axi.sv  : override (uart0_rx_i portu + u_uart0=uart_tek_axi +
#                     bootloader.hex yuklemesi `ifndef TEKNOTEST_SIM ile korumali)
add_files ../rtl/uart_tek_axi.sv
add_files ../rtl/soc_top_axi.sv

# --- Wrapper (testbench DUT'u) ---
add_files ./user_files/teknotest_wrapper.sv

# --- TEKNOTEST_SIM define: soc_top_axi'nin kendi bootloader.hex yuklemesini kapatir ---
set_property verilog_define {TEKNOTEST_SIM} [list [get_filesets sources_1] [get_filesets sim_1]]

# --- Simulasyon top modulu ---
set_property top teknotest_tb [get_filesets sim_1]
