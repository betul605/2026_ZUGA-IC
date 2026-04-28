# ============================================================================
# arty_a7.xdc  --  Xilinx Artix-7 (Arty A7-100T) pin atamalari
#
# Hedef Kart: Digilent Arty A7-100T (XC7A100TCSG324-1)
# Schematic kaynak: Arty A7 Reference Manual / arty-a7-c1-master.xdc
#
# Bu dosya Vivado projesine "constraints" olarak eklenir.
# Sadece kullandigimiz pinler tanimlanmistir; geri kalan pinler bos.
# ============================================================================

# ----------------------------------------------------------------------------
# Sistem Saati (100 MHz osilator)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { sysclk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { sysclk }];

# ----------------------------------------------------------------------------
# Reset Push Button (CPU_RESETN, active low)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN D9   IOSTANDARD LVCMOS33 } [get_ports { cpu_resetn }];

# ----------------------------------------------------------------------------
# UART (USB-UART Bridge, FT2232HL)
# UART TX: FPGA'dan PC'ye veri (kullaniyoruz)
# UART RX: PC'den FPGA'ya veri (Faz 3'te eklenecek)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN D10  IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { uart_rx }];

# ----------------------------------------------------------------------------
# 4 LED (LD0-LD3)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN H5   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN J5   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN T9   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN T10  IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

# ----------------------------------------------------------------------------
# 4 Switch (SW0-SW3)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN A8   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
set_property -dict { PACKAGE_PIN C11  IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
set_property -dict { PACKAGE_PIN C10  IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
set_property -dict { PACKAGE_PIN A10  IOSTANDARD LVCMOS33 } [get_ports { sw[3] }];

# ----------------------------------------------------------------------------
# I2C Master (PMOD JD, harici pull-up direnci gerekir)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN D3   IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }];  # JD1
set_property -dict { PACKAGE_PIN D4   IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }];  # JD0

# ----------------------------------------------------------------------------
# Konfigurasyon Voltaj (Arty default 3.3V)
# ----------------------------------------------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
