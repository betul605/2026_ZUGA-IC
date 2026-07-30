# ============================================================================
# nexys_video.xdc -- ZUGA-IC SoC (fpga_top_axi) icin Nexys Video kisitlari
# Kart: Digilent Nexys Video, FPGA: Xilinx Artix-7 XC7A200T-1SBG484C
#
# Tum pin/IOSTANDARD degerleri Digilent resmi "Nexys-Video-Master.xdc" ile
# birebir dogrulanmistir. LED bankasi 2.5V (LVCMOS25), UART/PMOD-JA bank 14 (3.3V),
# PMOD-JC bank 34 (3.3V), pushbutton'lar bank (1.2V, LVCMOS12), reset 1.5V.
# ============================================================================

## 100 MHz sistem saati (bank 14, LVCMOS33)
set_property -dict { PACKAGE_PIN R4  IOSTANDARD LVCMOS33 } [get_ports sysclk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports sysclk]
# Tasarim 50 MHz'de calisir (sysclk/2); generated clock otomatik cikarilir.

## CPU Reset (kirmizi buton, aktif-dusuk) - LVCMOS15
set_property -dict { PACKAGE_PIN G4  IOSTANDARD LVCMOS15 } [get_ports cpu_resetn]

## UART-0 -> USB-UART kopru (FPGA -> host)  [master: uart_rx_out, bank 14 LVCMOS33]
set_property -dict { PACKAGE_PIN AA19 IOSTANDARD LVCMOS33 } [get_ports uart_tx]

## UART-1 -> PMOD JC pin 1 (jc[0], bank 34 LVCMOS33)
set_property -dict { PACKAGE_PIN Y6  IOSTANDARD LVCMOS33 } [get_ports uart1_tx]

## 8 LED  (LVCMOS25 - LED bankasi)
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS25 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS25 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS25 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS25 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS25 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS25 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS25 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN Y13 IOSTANDARD LVCMOS25 } [get_ports {led[7]}]

## 5 Pushbutton (btnc/btnu/btnd/btnl/btnr) - LVCMOS12
##   btn[0]=BTNC  btn[1]=BTNU  btn[2]=BTND  btn[3]=BTNL  btn[4]=BTNR
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS12 } [get_ports {btn[0]}]
set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS12 } [get_ports {btn[1]}]
set_property -dict { PACKAGE_PIN D22 IOSTANDARD LVCMOS12 } [get_ports {btn[2]}]
set_property -dict { PACKAGE_PIN C22 IOSTANDARD LVCMOS12 } [get_ports {btn[3]}]
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS12 } [get_ports {btn[4]}]

## I2C Master -> PMOD JC (acik-drenaj, harici pull-up gerekli; bank 34 LVCMOS33)
##   jc[1]=AA6 (SCL), jc[2]=AA8 (SDA)
set_property -dict { PACKAGE_PIN AA6 IOSTANDARD LVCMOS33 } [get_ports i2c_scl]
set_property -dict { PACKAGE_PIN AA8 IOSTANDARD LVCMOS33 } [get_ports i2c_sda]

## Bitstream ayarlari
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
