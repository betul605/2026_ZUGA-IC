# ============================================================================
# nexys_video.xdc -- ZUGA-IC SoC (fpga_top_axi) icin Nexys Video kisitlari
# Kart: Digilent Nexys Video, FPGA: Xilinx Artix-7 XC7A200T-1SBG484C
#
# NOT: Paket pin numaralari Digilent "Nexys-Video-Master.xdc" ile TEYIT edilmeli.
#      Cekirdek pinler (sysclk/LED/switch/UART) standart degerlerdir; PMOD'a giden
#      uart1/I2C pinleri "# DOGRULA" ile isaretli - kendi Nexys Video XDC'nizle esleyin.
#      (DTR'de bu kartla calisildigindan Digilent master XDC elinizde mevcut.)
# ============================================================================

## 100 MHz sistem saati
set_property -dict { PACKAGE_PIN R4  IOSTANDARD LVCMOS33 } [get_ports sysclk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports sysclk]
# Tasarim 50 MHz'de calisir (sysclk/2); generated clock otomatik cikarilir.

## CPU Reset (kirmizi buton, aktif-dusuk)
set_property -dict { PACKAGE_PIN G4  IOSTANDARD LVCMOS15 } [get_ports cpu_resetn]   ;# DOGRULA

## UART-0 -> USB-UART kopru (FPGA -> host)  (uart_rx_out)
set_property -dict { PACKAGE_PIN AA19 IOSTANDARD LVCMOS33 } [get_ports uart_tx]

## UART-1 -> PMOD JC pin 1 (YZ stream / debug)
set_property -dict { PACKAGE_PIN Y6  IOSTANDARD LVCMOS33 } [get_ports uart1_tx]     ;# DOGRULA (PMOD JC1)

## 8 LED  (LVCMOS25 bankasi - DTR ile tutarli)
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS25 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS25 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS25 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS25 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS25 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS25 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS25 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN Y13 IOSTANDARD LVCMOS25 } [get_ports {led[7]}]

## 8 Slide switch
set_property -dict { PACKAGE_PIN E22 IOSTANDARD LVCMOS12 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN F21 IOSTANDARD LVCMOS12 } [get_ports {sw[1]}]
set_property -dict { PACKAGE_PIN G21 IOSTANDARD LVCMOS12 } [get_ports {sw[2]}]
set_property -dict { PACKAGE_PIN G22 IOSTANDARD LVCMOS12 } [get_ports {sw[3]}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS12 } [get_ports {sw[4]}]
set_property -dict { PACKAGE_PIN J16 IOSTANDARD LVCMOS12 } [get_ports {sw[5]}]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS12 } [get_ports {sw[6]}]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS12 } [get_ports {sw[7]}]

## I2C Master -> PMOD JC (acik-drenaj, harici pull-up gerekli)
set_property -dict { PACKAGE_PIN AA6 IOSTANDARD LVCMOS33 } [get_ports i2c_scl]       ;# DOGRULA (PMOD JC2)
set_property -dict { PACKAGE_PIN AA8 IOSTANDARD LVCMOS33 } [get_ports i2c_sda]       ;# DOGRULA (PMOD JC3)

## Bitstream ayarlari
set_property CFGBVS VCCO        [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
