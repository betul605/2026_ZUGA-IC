# ZUGA-IC FPGA Demo Prosedürü (Nexys Video, 25 MHz)

## Bağlantı
- PL2303 USB-TTL (3.3 V): yeşil TX -> JC pin4 (AB8, uart1_rx), beyaz RX -> JC pin1 (Y6, uart1_tx), siyah GND -> JC pin5. Kırmızı VCC BAĞLANMAZ.
- Linux'ta TTL = /dev/ttyUSB0 (JTAG FT2232 = ttyUSB0/1).

## Adımlar
1. Programla: `vivado -mode batch -source prog_only.tcl` (bit: build_fpga/zuga_ic.bit, kopyası demo/zuga_ic_25mhz.bit)
   - "No devices detected" -> `sudo pkill -f hw_server; sudo modprobe -r ftdi_sio` ve/veya PROG USB'yi çıkar-tak.
2. 4x LED blink sonrası LD0 yanar (ağırlık bekliyor): `python3 demo/load_weights.py /dev/ttyUSB0` -> `WOK`, LD7 yanar.
3. Harness (demo_program klasöründe):
   `python3 demo_harness.py run -c takim_icd.json --manifest public_dataset/manifest.csv --core-port /dev/ttyUSB0 --stream-port /dev/ttyUSB0 --core-baud 115200 --stream-baud 115200`
   Not: Her programlama / güç kesintisinden sonra 2. adım tekrar gerekir.

## Sonuçlar
- final_25mhz_99.36pct: golden agreement %99.36 (155/156), 0 timeout, robustness 10/10.
- before_fix_50mhz_93.59pct: kısıtsız 50 MHz türetilmiş saatte zamanlama ihlali logit3'ü bozuyordu (aynı girdide farklı değer).
  Düzeltme: sysclk/4 = 25 MHz + create_generated_clock kısıtı (WNS +7.8 ns), UART CPB 217. RTL datapath değişmedi; sim gerçek ağırlıklarla PASS.
- Kalan 1 uyuşmazlık (go_274c008f) offline RTL-sadık modelde de aynı: basitleştirilmiş requant (>>>8, [0,127]) vs TFLite kanal-başı ölçek sınır durumu.
