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

Detaylar:
- docs/milestone_XX.md (M01-M10, her milestone icin ayri rapor)
- docs/DTR_RAPORU_v0.md (DTR sablonu, 680 satir)
- docs/MIMARI_DIYAGRAM.md (3 Mermaid diyagram, GitHub render)
- docs/OTR_DTR_KARSILASTIRMA.md (10 bolum, mimari kararlar)
- docs/SCREENSHOTS.md (simulasyon cikti kanitlari)

## Referanslar

- CV32E40P: https://github.com/openhwgroup/cv32e40p
- RISC-V: https://riscv.org
- TEKNOFEST: https://www.teknofest.org


## FPGA Sentez (Arty A7-100T)

Proje Xilinx Artix-7 XC7A100TCSG324-1 (Arty A7-100T) icin
sentezlenebilir hale getirilmistir (Milestone 09 + 10).

### Vivado Projesi Olusturma

1. Vivado 2023.x ac
2. Create New Project, RTL Project, "Do not specify sources" sec
3. Part: xc7a100tcsg324-1
4. Add Sources (Design Sources):
   - rtl/cv32e40p_*.sv (CV32E40P kaynak dosyalari)
   - rtl/ram.sv, rtl/gpio.sv, rtl/timer.sv, rtl/uart.sv, rtl/soc_top.sv
   - rtl/fpga_top.sv (TOP MODULE olarak isaretle)
5. Add Constraints:
   - constraints/arty_a7.xdc
6. Run Synthesis

### FPGA Pin Atamalari (Arty A7-100T)

| Sinyal       | Yon    | FPGA Pin | Aciklama                  |
|--------------|--------|----------|---------------------------|
| sysclk       | input  | E3       | 100 MHz osilator          |
| cpu_resetn   | input  | D9       | Reset push button (active low) |
| uart_tx      | output | D10      | USB-UART kopru (FPGA->PC) |
| led[3:0]     | output | H5,J5,T9,T10 | 4 LED                |
| sw[3:0]      | input  | A8,C11,C10,A10 | 4 Switch          |

### Clock Yapisi

- Arty 100 MHz sysclk -> /2 divider -> 50 MHz cekirdek saati
- ONTR'de vaat edilen 50 MHz hedefi tutturuldu
- Gelecek: MMCM ile gerc0ek clock generation

### UART Kullanimi

UART TX pini Arty USB-UART koprusune (FT2232HL) bagli. PC'de
seri port acilarak UART c0iktisi gorulebilir:

- Baud rate: 9600 (CPB = 5208 ile, 50 MHz / 9600)
- Format: 8N1 (8 data bit, no parity, 1 stop bit)
- Yazilim PuTTY, minicom, screen, vs.

Yazilim onyukleme komutu: CPB yazmacina 5208 yaz (default 16)
- LUI x10, 0x40002
- ADDI x11, x0, 5208 (veya 0x1458)
- SW x11, 0(x10)   # CPB = 5208

### Reset Davranisi

Push button (CPU_RESETN) basildiginda:
- Senkronizasyon: 2-flop senkronizatorden gec0er
- Debounce: 16-bit sayici (~1.3 ms @ 50 MHz) bekleyis
- rst_n_clean SoC'ye gec0er

Son guncelleme: 27 Nisan 2026 (Milestone 10: FPGA Top-Level)
DTR teslim: 15 Mayis 2026
