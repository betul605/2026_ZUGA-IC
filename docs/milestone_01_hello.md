# Milestone 01: İlk Çalışan SoC — "Hi"

Tarih: 22 Nisan 2026

## Durum
CV32E40P RISC-V çekirdeği, Verilator simülasyonunda basit bir "Hi\n"
mesajını memory-mapped UART üzerinden başarıyla bastı.

## Altyapı
- Verilator 5.020
- xPack RISC-V GCC 13.2.0
- CV32E40P (cv32e40p_core, FPU=0)

## Bellek haritası (geçici — smoke test için)
- Instruction RAM: 0x00000000 - 0x00003FFF (16 KB modellenmiş)
- Data memory-mapped UART: 0x10000000

## Test programı
rv32i assembly, hello.S:
  lui x1, 0x10000         # UART adresi
  addi x2, x0, 72         # 'H'
  sw x2, 0(x1)
  addi x2, x0, 105        # 'i'
  sw x2, 0(x1)
  addi x2, x0, 10         # '\n'
  sw x2, 0(x1)
  jal x0, loop_end

## Sonuç
UART output: Hi
(ve sonra sonsuz döngü — beklenen davranış)

## Çözülen teknik problem
OBI protokolünde instruction_rdata'nın gnt ile aynı cycle yerine
bir cycle gecikmeli dönmesi gerekiyor. İlk testbench'te combinational
bağlı olduğu için çekirdek yanlış komutlar fetch ediyordu. Adres
latch'lenerek düzeltildi.

## Sonraki adım
- SoC yapısını modüler hale getir (ram.sv, uart.sv ayrılsın)
- OBI-AXI Bridge tasarla
- İlk AXI4-Lite slave: GPIO
