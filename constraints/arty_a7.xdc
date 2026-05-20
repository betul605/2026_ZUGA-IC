# ============================================================================
# arty_a7.xdc -- ZUGA-IC SoC Constraint Dosyasi
#
# Hedef Kart: Digilent Arty A7-100T (XC7A100TCSG324-1)
# Top Module: soc_top_axi
# Tarih: 14 May 2026
# Schematic kaynak: arty-a7-c1-master.xdc (Digilent)
#
# Port haritalandirma (RTL ile birebir uyumlu):
#   clk_i        -> 100 MHz osilator
#   rst_ni       -> CPU_RESETN buton
#   gpio_in_i    -> 4 buton + 4 switch + 8 PMOD JD pin = 16 bit
#   gpio_out_o   -> 4 on-board LED + 12 PMOD pin = 16 bit
#   uart0_tx_o   -> USB-UART (PC haberlesme)
#   uart1_tx_o   -> PMOD JA pin 1
#   i2c_*        -> PMOD JC pinleri (harici pull-up gerekir)
# ============================================================================

# ----------------------------------------------------------------------------
# Sistem Saati (100 MHz osilator, on-board)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { clk_i }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_i }];

# ----------------------------------------------------------------------------
# Reset Push Button (CPU_RESETN, active low)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN C2   IOSTANDARD LVCMOS33 } [get_ports { rst_ni }];

# ----------------------------------------------------------------------------
# UART 0 (USB-UART Bridge FT2232HL, PC haberlesme)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN D10  IOSTANDARD LVCMOS33 } [get_ports { uart0_tx_o }];

# ----------------------------------------------------------------------------
# UART 1 (PMOD JA pin 1, YZ stream icin)
# ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN G13  IOSTANDARD LVCMOS33 } [get_ports { uart1_tx_o }];

# ----------------------------------------------------------------------------
# GPIO Output (16 bit) - 4 LED + PMOD JB + PMOD JC pins
# ----------------------------------------------------------------------------
# On-board LEDs (LD0-LD3) - gpio_out_o[0..3]
set_property -dict { PACKAGE_PIN H5   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[0] }];
set_property -dict { PACKAGE_PIN J5   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[1] }];
set_property -dict { PACKAGE_PIN T9   IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[2] }];
set_property -dict { PACKAGE_PIN T10  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[3] }];
# PMOD JB pins (8 pin) - gpio_out_o[4..11]
set_property -dict { PACKAGE_PIN E15  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[4] }];
set_property -dict { PACKAGE_PIN E16  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[5] }];
set_property -dict { PACKAGE_PIN D15  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[6] }];
set_property -dict { PACKAGE_PIN C15  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[7] }];
set_property -dict { PACKAGE_PIN J17  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[8] }];
set_property -dict { PACKAGE_PIN J18  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[9] }];
set_property -dict { PACKAGE_PIN K15  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[10] }];
set_property -dict { PACKAGE_PIN J15  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[11] }];
# PMOD JC pins - gpio_out_o[12..15] (sadece 4 pin, geri kalanlar I2C icin)
set_property -dict { PACKAGE_PIN U12  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[12] }];
set_property -dict { PACKAGE_PIN V12  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[13] }];
set_property -dict { PACKAGE_PIN V10  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[14] }];
set_property -dict { PACKAGE_PIN V11  IOSTANDARD LVCMOS33 } [get_ports { gpio_out_o[15] }];

# ----------------------------------------------------------------------------
# GPIO Input (16 bit) - 4 Switch + 4 Button + PMOD JD pins
# ----------------------------------------------------------------------------
# On-board switches (SW0-SW3) - gpio_in_i[0..3]
set_property -dict { PACKAGE_PIN A8   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[0] }];
set_property -dict { PACKAGE_PIN C11  IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[1] }];
set_property -dict { PACKAGE_PIN C10  IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[2] }];
set_property -dict { PACKAGE_PIN A10  IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[3] }];
# On-board buttons (BTN0-BTN3) - gpio_in_i[4..7]
set_property -dict { PACKAGE_PIN D9   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[4] }];
set_property -dict { PACKAGE_PIN C9   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[5] }];
set_property -dict { PACKAGE_PIN B9   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[6] }];
set_property -dict { PACKAGE_PIN B8   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[7] }];
# PMOD JD pins (8 pin) - gpio_in_i[8..15]
set_property -dict { PACKAGE_PIN D4   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[8] }];
set_property -dict { PACKAGE_PIN D3   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[9] }];
set_property -dict { PACKAGE_PIN F4   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[10] }];
set_property -dict { PACKAGE_PIN F3   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[11] }];
set_property -dict { PACKAGE_PIN E2   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[12] }];
set_property -dict { PACKAGE_PIN D2   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[13] }];
set_property -dict { PACKAGE_PIN H2   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[14] }];
set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports { gpio_in_i[15] }];

# ----------------------------------------------------------------------------
# I2C Master (PMOD JA pins, harici pull-up gerekir!)
# Not: i2c_*_oe sinyalleri output-enable, harici tristate buffer kullanilir
# ----------------------------------------------------------------------------
# I2C SCL signals (PMOD JA pin 7, 8)
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports { i2c_scl_o }];
set_property -dict { PACKAGE_PIN T11  IOSTANDARD LVCMOS33 } [get_ports { i2c_scl_oe }];
# I2C SDA signals (PMOD JA pin 9, 10, plus input from same line)
set_property -dict { PACKAGE_PIN R12  IOSTANDARD LVCMOS33 } [get_ports { i2c_sda_o }];
set_property -dict { PACKAGE_PIN T14  IOSTANDARD LVCMOS33 } [get_ports { i2c_sda_oe }];
set_property -dict { PACKAGE_PIN T15  IOSTANDARD LVCMOS33 } [get_ports { i2c_sda_i }];

# ----------------------------------------------------------------------------
# Konfigurasyon Voltaj (Arty default 3.3V)
# ----------------------------------------------------------------------------
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# ----------------------------------------------------------------------------
# False Path declarations (asagidaki bireysel pinler asynchronous input)
# ----------------------------------------------------------------------------
# (Bos brakildi - sentez sirasinda otomatik analiz edilir)

