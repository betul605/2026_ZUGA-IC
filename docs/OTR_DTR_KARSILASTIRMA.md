# ONTR-DTR Karsilastirma Tablosu

**Takim:** ZUGA-IC | TEKNOFEST 2026 Cip Tasarim Yarismasi
**Versiyon:** v1 (27 Nis 2026)

Bu doküman ONTR'de (16 Mart 2026 teslimi) verilen mimari/teknik
kararlar ile DTR donemde (16 Mart - 15 May) gerc0eklestirilen
durum arasindaki farklari detayli olarak listeler. DTR Raporu
Bolum 2 (ONTR'den Bu Yana Yapilan Degisiklikler) icin kaynak
dokumandir.

Her satirda:
- ONTR'de soylenen
- DTR'de yapilan
- Eger fark varsa: rasyonel
- Final teslim icin plan

---

## 1. Mimari Kararlar

### 1.1 Cekirdek Sec0imi

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| RISC-V cekirdek | CV32E40P | cv32e40p_core (top yerine) | Ayni |
| Pipeline | 4-stage in-order | 4-stage in-order (M01) | Ayni |
| FPU | 0 | 0 (APU tie-off) | 0 |
| Compressed (RV32IC) | Vaat | Hayir (-march=rv32i) | Eklenebilir |
| Multiplier (RV32M) | Vaat | Vaat (default open) | Test edilecek |

**Rasyonel (cv32e40p_top -> _core):** _top FPU wrapper bagimliligi
(fpnew_pkg) ek karmaşıklık. _core dogrudan kullanildi, FPU=0
hedefi icin yeterli.

**Rasyonel (RV32IC kapatildi):** Compressed instruction decode'da
takildiginda hex format hatalari yasandi (M01 surec). 16-bit
instruction'lar 4-byte hizalanmiyor; basit hex format gerekiyor.
RV32I yeterli, gelecek faz icin _C eklenebilir.

### 1.2 RTL Dili

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Donanim aciklamali | Verilog | SystemVerilog 2017 | SV |
| typedef enum | - | Var (M07, M09) | Var |
| parameter | - | Var (M07, M09, fpga_top) | Var |
| bind | - | Var (M07) | Var |

**Rasyonel:** CV32E40P kendisi SV ile yazilmis. Tutarlilik icin
biz de SV. Bonuslari:
- typedef enum: state machine'ler icin (M09 TX state machine)
- parameter: bus_name (M07), SIZE_WORDS (ram.sv), CPB
- bind: RTL'i degistirmeden assertion ekleme (M07)

DTR'de "ONTR'de Verilog dedik ama SV2017 sentetik alt kume kullandik"
denir; sebebi tip guvenligi ve CV32E40P uyumlulugu.

### 1.3 Bus Protokolu

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Master bus | AXI4-Lite | OBI direkt | AXI4-Lite wrapper + OBI |
| Slave protocol | AXI4-Lite | OBI | OBI (hep) |
| Decoder | - | 5-slave OBI decoder | 5+ slave |
| Protocol Check | UVM agent | OBI assertion bind (M07) | UVM agent |

**Rasyonel:** CV32E40P core dogrudan OBI uretiyor. AXI4-Lite
wrapper yazmak ek 200-300 satir RTL. AXI4-Lite cevaplama mantigi
karmasik (10 sinyal vs OBI 5 sinyal).

DTR donemi icin OBI yeterli kanit; final teslim icin AXI4-Lite
wrapper eklenecek (metodoloji ayni: assertion'lar, decoder, vs.)

### 1.4 Bellek Haritasi

| Adres | ONTR Plan | DTR Durum | Boyut |
|-------|-----------|-----------|-------|
| 0x00000000 | Boot ROM | IRAM (program) | 256B / 8KB |
| 0x00010000 | IRAM | yok | -/- |
| 0x00020000 | DRAM | DRAM | 8KB |
| 0x40000000 | GPIO | GPIO | 4KB |
| 0x40001000 | Timer | Timer | 4KB |
| 0x40002000 | UART-0 | UART-0 (M06) | 20B |
| 0x40003000 | UART-1 | yok | 20B (final) |
| 0x40004000 | I2C | yok | (final) |
| 0x40005000 | QSPI | yok | (final) |
| 0x50000000 | YZ Hizlandirici | yok | 30KB (final) |

**Rasyonel (IRAM 0x00 vs 0x10000):** Linker script default
0x00'da basliyor. Tum hex dosyalari 0x00'dan itibaren program
icerir. Boot ROM eklemek icin tum testlerin yeniden derlenmesi
gerek; DTR donemi icin gereksiz risk.

Final teslim icin: Boot ROM 0x00 (256 byte, "MOV PC, IRAM_START"),
IRAM 0x10000, ONTR plan.

---

## 2. Cevre Birimler

### 2.1 GPIO

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Pin sayisi | 32 pin | 16 pin (M03) | 32 pin |
| IDR/ODR | Vaat | Var (M03) | Var |
| Interrupt | Vaat | yok | Var |
| Self-check test | - | 'P' (M03) + comprehensive (M08) | + |

**Rasyonel (16 pin):** 3 sinif EEM ders projesi olarak baslayan
proje, 16 pin yeterli kanit. Final teslim icin 32 pin'e cikarilacak
(parametre genisletme, basit).

### 2.2 Timer

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Sayici genisligi | 32-bit | 32-bit (M04) | 32-bit |
| CLR/ENA/CNT | Vaat | Var (M04) | Var |
| Interrupt | Vaat | yok | Var |
| Compare register | - | yok | Var |
| Self-check test | - | 'T' (M04) + comprehensive (M08) | + |

**Rasyonel:** Temel sayici davranissi calisiyor. Interrupt ve
compare register final teslim icin.

### 2.3 UART (Asimetrik Seri)

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| UART sayisi | 2 (UART-0, UART-1) | 1 (UART-0, M06) | 2 |
| Adres | UART-0: 0x40002000 | 0x40002000 (M06) | + UART-1: 0x40003000 |
| Yazmaclar | CPB/STP/RDR/TDR/CFG | EK-2 birebir (M06) | Ayni |
| TX state machine | Vaat | Var (M09 Faz 2) | Var |
| Baud rate | <=1 Mbps | CPB-based (M09) | Ayni |
| RX (alici) | Vaat | yok | Var |
| Sentezlenebilir | Vaat | Evet (M09) | Evet |
| Self-check test | - | 'Hi'/'P'/'T'/'PASS' | + |

**Rasyonel (1 UART):** UART-1 (YZ veri akisi icin) henuz yok.
Modul kopyalanip iki instance yapilabilir. DTR icin UART-0
yeterli kanit.

**Rasyonel (RX yok):** TX onceligi hizli demoy yardimci. RX final
teslim icin (PuTTY input okuma).

### 2.4 I2C Master

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Modul varligi | Vaat | Yok | Var |
| Adres | 0x40004000 | - | 0x40004000 |
| Standart | 100 kHz | - | 100 kHz |

**Rasyonel:** Yeterli zaman olmadi. Final teslim icin yazilacak.
Standart I2C iskelet ~150-200 satir, 1 hafta'lik is.

### 2.5 QSPI Master

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Modul varligi | Vaat | Yok | Var |
| Adres | 0x40005000 | - | 0x40005000 |
| Standart | Single/Dual/Quad | - | Single ilk |

**Rasyonel:** I2C ile ayni durum. Final teslim icin.

### 2.6 JTAG (Bonus)

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Bonus | +3 puan | Yok | Eklenebilir |

**Rasyonel:** ONTR'de bonus olarak isaretliydi. Onceligi dusuk.

### 2.7 YZ Hizlandirici

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Mimari | Tiny Conv (TFLite Micro Speech) | Plan | Tam |
| MAC birimi | Paylasimli | yok | Var |
| SRAM (ping-pong) | 30 KB | yok | 30 KB |
| Quantization | int8 | - | int8 |
| Doğruluk hedefi | %10 | - | %10 |
| Hizlanma hedefi | >5x CPU | - | >5x |
| CSR adres | 0x50000000 | - | 0x50000000 |

**Rasyonel:** YZ hizlandirici DTR icin zorunlu degil (sartname
final teslim). DTR donem son haftalarinda iskelet eklenebilir
(MAC + FSM + CSR), tam Conv1D + Depthwise + FC final teslim.

---

## 3. Doğrulama Yaklasimi

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Test framework | UVM + SV | Self-check test + SVA assertion | UVM agent |
| Test dili | UVM SV | Assembly (.S, RV32I) | + UVM SV |
| Coverage | Kavramsal | DATA + INSTR sayaclari (M07/M08) | Code + functional |
| Self-checking | Kavramsal | 4 test (M03/M04/M06/M08) | + sequence |
| Protocol Check | "AXI Protocol Check" | OBI assertion bind (M07) | + AXI |
| FAIL sayisi | - | 0 (1000 cycle) | 0 |

**Rasyonel:** Tam UVM 3-4 saatlik ogrenme egrisi + Verilator
sinirli destek. SVA assertion + behavioral assert(condition) ile
ayni isi yapan, daha pragmatik yontem sec0ildi (M07).

DTR icin yeterli kanit (3 protocol kurali, 0 FAIL, coverage var);
final teslim icin tam UVM agent eklenebilir.

---

## 4. FPGA ve Sentez

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Hedef kart | Arty A7-100T | Arty A7-100T (M10) | Arty A7-100T |
| Vivado | 2023.x | 2023.x (kullanicida kurulu) | Ayni |
| Saat hizi | 50 MHz | 50 MHz (/2 divider, M10) | 50 MHz (MMCM) |
| Top-level wrapper | - | fpga_top.sv (M10) | + MMCM |
| XDC constraints | - | arty_a7.xdc (12 pin, M10) | + RX UART |
| Sentez | - | Hafta sonu (3-4 May) | Tam demo |
| Bitstream | - | (sentez sonrasi) | Var |
| Demo | - | yok | UART PuTTY |

**Rasyonel:** ONTR'de Arty A7-100T sec0ilmisti, DTR'de bu karara
sadik kalindi. RTL sentezlenebilir hale getirildi (M09 + M10).
Hafta sonu Umur Bugra ile fiziksel sentez denenecek.

---

## 5. Yazilim ve Build

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| Toolchain | RISC-V GCC | xpack-riscv-none-elf-gcc 13.2.0-2 | Ayni |
| Simulator | Verilator/Icarus | Verilator 5.020 | + Vivado sim |
| Build script | Otomasyon | build.sh (parameterize) | + makefile |
| Test dili | C/Assembly | RV32I Assembly | + C |
| Hex format | $readmemh | Python word-by-word | Ayni |

**Rasyonel:** Verilator hizli, bagimsiz, ucretsiz. Build.sh tek
komutla derliyor + simulator ureti yor + testleri ko sturuyor.
Sartname jüri "tek komutla build" istedi - karsilandi.

---

## 6. Git ve Repository

| Madde | ONTR | DTR | Final |
|-------|------|-----|-------|
| GitHub | yongatek-teknofest | github.com/betul605/ZUGA-IC | Ayni |
| Commit sayisi | 0 | 24 (27 Nis itibariyle) | 30+ |
| Milestone dokumani | Yok | 10 milestone (.md) | + |
| README | Yok | Var (130 satir, FPGA dahil) | + |
| .gitignore | Yok | Var (gec0ici dosyalar) | + |
| Branch | main | main | main + dev |
| SSH altyapi | - | Var (zuga_ic_key) | Ayni |

**Rasyonel:** Onceden token kullanildi, sonra SSH'a gec0ildi
(daha hizli, daha guvenli). Her milestone ayri commit + dokumanı.

---

## 7. Takvim

| Tarih | ONTR Plan | DTR Gerc0ek | Yorum |
|-------|-----------|-------------|-------|
| 16 Mart | ONTR teslim | ONTR teslim edildi | OK |
| Mart - Nis | RTL gelistirme | M01-M07 (22-26 Nis) | Hizli |
| Nis sonu | UART tam | M09 (27 Nis, 1 hafta erken) | OK |
| Mayis basi | FPGA sentez | Hafta sonu (3-4 May) | OK |
| 9-15 May | DTR rapor yazimi | Plan: hafta 3 | OK |
| 15 May 17:00 | DTR teslim | Hedef | + |

**Rasyonel:** ONTR sonrasi 6 hafta donem. Ilk 5 hafta RTL +
test + sentez hazirligi. Son hafta DTR rapor yazimi. Tahmin
edildigi gibi gidiyor.

---

## 8. Sartname Odul Kriterleri Durumu

Sartname Madde 4.2.2.2 minimum 5 odul kriteri:

| # | Kriter | ONTR Plan | DTR Durum | Final Hedef |
|---|--------|-----------|-----------|-------------|
| 1 | FPGA + 2 cevre birim | Vaat | RTL hazir, sentez 3-4 May | Tam demo |
| 2 | Self-checking test | Vaat | 4 test (M03/04/06/08) | + |
| 3 | AXI/Protocol Check | UVM | OBI assertion (M07) | + AXI |
| 4 | YZ test | Tiny Conv | Plan | Tam |
| 5 | GDSII | Sky130 | Yok | Tam |

DTR donemi sonu: 3/5 kriter karsilanmaya basladi. #1 hafta sonu
ile %50 -> %80'e cikar. #4 ve #5 final teslim icin.

---

## 9. Risk Analizi (DTR Donemi Icin)

| Risk | Olasilik | Etki | Azaltma |
|------|----------|------|---------|
| Vivado sentez basarisiz | Orta | Yuksek | Hafta sonu deneme + debug |
| YZ MAC iskelet zaman almaz | Dusuk | Orta | Opsiyonel; "plan" olarak goster |
| DTR rapor son haftaya birikir | Dusuk | Yuksek | Sablon (M11) hazir, malzeme hazir |
| Bracketed paste ekran karistirir | Yuksek | Dusuk | Python chr(96) yontemi |

---

## 10. Sonuc

ONTR'den DTR'ye gec0iste yapilan farklar:
- Bus protokolu: AXI4-Lite -> OBI direkt (basitlik)
- RTL dili: Verilog -> SV2017 sentetik (CV32E40P uyum)
- Bellek haritasi: Boot ROM 0x00 -> IRAM 0x00 (linker basitligi)
- Doğrulama: UVM -> SVA assertion (Verilator sinir)
- Cevre birim: Tum cevre birimler -> 3 (GPIO, Timer, UART)

Bu farkların **hepsinin teknik gerekc0esi var** ve final teslim
icin **plan mevcut**. DTR raporunda her bir fark "ONTR'den DTR'ye
yapilan akilli sec0imler" olarak savunulabilir.

ZUGA-IC takimi DTR donemi sonu:
- 24 git commit, 12 milestone
- 5 RTL modul, 4 self-checking test
- 3 OBI protocol assertion, 0 FAIL
- FPGA sentez hazir
- DTR raporu sablonu (680 satir) + 3 mimari diyagram

