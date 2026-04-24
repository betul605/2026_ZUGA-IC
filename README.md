# ZUGA-IC

TEKNOFEST 2026 Cip Tasarim Yarismasi - Mikrodenetleyici Tasarim Kategorisi

CV32E40P RISC-V cekirdegi uzerine kurulu, yapay zeka hizlandiricisi hedefli
System-on-Chip prototipi.

## Takim

- Takim Adi: ZUGA-IC (ID 989786)
- Kaptan: Umur Bugra Dikmen
- Uye: Betul Bedir
- Danisman: Fatih Gul
- Universite: Recep Tayyip Erdogan Universitesi EEM

## Mevcut Durum (24 Nisan 2026)

- Cekirdek: CV32E40P, Verilator 5.020 simulasyonunda calisiyor
- Cevre birimleri: UART (primitive), GPIO, Timer
- Self-checking testler: GPIO (P), Timer (T)
- 4 milestone, 8 Git commit

## Bagimliliklar

- Verilator 5.020+
- xPack RISC-V GCC 13.2.0+
- Python 3, make, bash, git

## CV32E40P Kaynagi

Cekirdek ayri klonlanmali:

    git clone https://github.com/openhwgroup/cv32e40p ~/cv32e40p

## Calistirma

    ./build.sh
    ./obj_dir/sim_cv32 | head -30

Beklenen: data=0x00000054 satiri (T = Timer test PASS)

## Proje Yapisi

- rtl/     : Sentezlenebilir RTL (ram, uart, gpio, timer, soc_top)
- tb/      : Testbench
- sw/      : RISC-V test programlari
- docs/    : Dokumantasyon (milestone raporlari, durum raporlari)
- build.sh : Otomasyon scripti

## Bellek Haritasi

- 0x00000000 - 0x00003FFF : RAM
- 0x10000000              : UART
- 0x40000000 - 0x40000FFF : GPIO
- 0x40001000 - 0x40001FFF : Timer

## Teknik Kararlar

- cv32e40p_core secildi (top degil, FPU wrapper bagimliligi nedeniyle)
- FPU=0 (int8 AI hedefi)
- SystemVerilog sentetik alt kume (tip guvenligi + CV32E40P uyumu)
- Ozel OBI decoder (pulp-platform/axi yerine, basit olsun diye)
- OBI bus select latch: rvalid yolunda select sinyali latch'lenmeli

Detaylar: docs/milestone_XX.md ve docs/DTR_DURUM.md

## Referanslar

- CV32E40P: https://github.com/openhwgroup/cv32e40p
- RISC-V: https://riscv.org
- TEKNOFEST: https://www.teknofest.org

Son guncelleme: 24 Nisan 2026
DTR teslim: 15 Mayis 2026
