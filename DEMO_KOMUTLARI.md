# ZUGA-IC DEMO — Jüri Önünde Çalıştırma

Port: /dev/ttyUSB0 (PL2303 USB-TTL)
Kablo: yeşil -> PMOD JC pin4 (AB8, uart1_rx)
       beyaz -> PMOD JC pin1 (Y6,  uart1_tx)
       siyah -> PMOD JC pin5 (GND)
       kırmızı -> BAĞLANMAZ (5V, yakar)

## 1. Bitstream (LED'ler sönükse; yanıyorsa atla)
cd ~/Desktop/ZUGA-IC-final
vivado -mode batch -source prog_only.tcl 2>&1 | grep -E "PROGRAMLANDI|ERROR"
-> "==== KART PROGRAMLANDI ====", 8 LED 4x blink, LD0 yanık kalır

## 2. Kartta CPU_RESETN butonuna bas
-> 4x blink, LD0 yanık kalır (ağırlık bekliyor)

## 3. Ağırlıkları yükle
cd ~/Desktop/ZUGA-IC-final
python3 demo/load_weights.py /dev/ttyUSB0
-> kart: b'WOK\n'  ve LD7 yanar. LD7 yanmadan 4. adıma geçme.

## 4. Harness — 40 vektör (~1 dk, jüri ekranı)
cd ~/fpga_demo/demo_program
python3 demo_harness.py run -c takim_icd.json \
  --manifest public_dataset/manifest_demo40.csv \
  --core-port /dev/ttyUSB0 --stream-port /dev/ttyUSB0 \
  --core-baud 115200 --stream-baud 115200 --no-robustness
-> RESULT satırları akar, sonda Golden agreement: 100.00 %

## 5. Tam set (~3 dk, istenirse)
python3 demo_harness.py run -c takim_icd.json \
  --manifest public_dataset/manifest.csv \
  --core-port /dev/ttyUSB0 --stream-port /dev/ttyUSB0 \
  --core-baud 115200 --stream-baud 115200
-> Golden agreement: 99.36 % | mismatches: 1 | timeouts: 0 | robustness: 10/10

# LED ANLAMLARI
4x blink = reset, program başladı
LD0      = ağırlık bekliyor
LD7      = ağırlıklar yüklü, vektör bekliyor (çalışma hali)
LD6      = çıkarım sürüyor
kısa tek LED = sonuç (LD0 silence, LD1 unknown, LD2 yes, LD3 no)
0xAA (bir yanık bir sönük) = hızlandırıcı timeout

# HATA OLURSA
Port yok / isim farklı:   ls /dev/ttyUSB*
Permission denied:        sudo chmod 666 /dev/ttyUSB0
No devices detected:      sudo pkill -f hw_server; sudo modprobe -r ftdi_sio
                          PROG USB'yi çıkar-tak, adım 1'i tekrarla
Hep silence / timeout:    CPU_RESETN -> adım 3 -> adım 4
Hiçbir şey çalışmıyor:    cat demo/harness_results/full_20260918_99.36pct/report.md

# NOT
Harness paketi (demo_program) DDK'ye aittir, bu repoda yoktur.
Demo için ~/fpga_demo/demo_program altında bulunmalıdır.
