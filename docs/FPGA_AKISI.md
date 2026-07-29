# ZUGA-IC — FPGA Akışı (Nexys Video / XC7A200T)

Şartname §4.3 (FPGA çıktıları) için tam Vivado akışı. **YZ hızlandırıcı dahil** SoC
(`soc_top_axi`) Nexys Video üzerinde sentezlenir, yerleştirilir, yönlendirilir; STA +
utilization raporları ve bitstream üretilir.

## Dosyalar
- `rtl/fpga_top_axi.sv` — `soc_top_axi`'yi (CV32E40P + AXI4-Lite + YZ) saran FPGA top:
  100→50 MHz saat bölücü, reset debounce, 8 LED/8 switch, iki UART, I2C open-drain.
- `constraints/nexys_video.xdc` — Nexys Video pin kısıtları.
- `build_fpga.tcl` — Vivado non-project akış (sentez→impl→rapor→bitstream).

## Çalıştırma (Windows/Vivado — repo kökünde)
```
git pull                       # GitHub'dan güncel RTL
vivado -mode batch -source build_fpga.tcl
```
Çıktılar `build_fpga/` altında: `zuga_ic.bit`, `timing_*.rpt` (STA), `utilization_*.rpt`,
`post_route.dcp`, `drc.rpt`. Bunlar **repoya commit edilir** (§4.3 zorunlu çıktılar).

## Bitstream'i karta yükleme
```
vivado -mode batch -source - <<'EOF'
open_hw_manager; connect_hw_server; open_hw_target
set d [lindex [get_hw_devices] 0]
set_property PROGRAM.FILE build_fpga/zuga_ic.bit $d
program_hw_devices $d
EOF
```
(veya Vivado Hardware Manager GUI ile `zuga_ic.bit` programla.)

## ÖNEMLİ — pin doğrulama
`nexys_video.xdc` içindeki çekirdek pinler (sysclk R4, LED LVCMOS25, switch, UART AA19)
standarttır. `# DOGRULA` ile işaretli pinleri (cpu_resetn, PMOD'a giden uart1_tx ve I2C)
kendi **Digilent Nexys-Video-Master.xdc**'nizle karşılaştırın — DTR'de bu kartla
çalışıldığından o dosya elinizde mevcut. (DTR'de not edilen "I2C pinleri farklı bankada"
sorunu bu yüzden burada da PMOD'a alınmış ve LVCMOS33 verilmiştir.)

## Demo (Demo %10 + §5.2 #1)
- FPGA DONE LED'i + programlanınca çekirdek boot eder.
- UART-0'dan (AA19) çıkan mesaj bir seri terminalde (115200 8N1) okunur.
- GPIO: switch → LED davranışı gözlenir.
- YZ akışı: CPU, 0x50xx_xxxx pencerelerinden veri/ağırlık yükleyip START verir; bir
  C demosu (yol haritasında) sonucu UART'tan yazar (donanımlı C demosu adımı).

## Beklenen zamanlama
Tasarım 50 MHz'de (20 ns) hedeflenir; tek saat alanı (CDC yok). `timing_route.rpt`
içindeki WNS pozitif olmalı (zamanlama kapandı). Betik sonunda WNS yazdırılır.
