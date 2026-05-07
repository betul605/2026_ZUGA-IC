# Detayli Tasarim Raporu (DTR)

## TEKNOFEST 2026 Cip Tasarim Yarismasi - Mikrodenetleyici Kategorisi

**Takim:** ZUGA-IC
**Takim ID:** #989786
**Basvuru ID:** #5215977
**Kategori:** Mikrodenetleyici Tasarim (Yongatek)

**Takim Uyeleri:**
- Umur Bugra Dikmen (Kaptan)
- Betul Bedir

**Danisman:** Fatih Gul

**Universite:** RTEU Elektrik-Elektronik Muhendisligi

**Teslim Tarihi:** 15 Mayis 2026
**Rapor Versiyonu:** v0 (sablon)
**Son Guncelleme:** 27 Nisan 2026

---

## 1. Yonetici Ozeti

ZUGA-IC takimi, TEKNOFEST 2026 Cip Tasarim Yarismasi (Mikrodenetleyici
Kategorisi) kapsaminda OpenHW Group'un CV32E40P RISC-V cekirdegi
etrafinda kurulmus modular bir System-on-Chip (SoC) gelistirmistir.
Tasarim, Recep Tayyip Erdogan Universitesi (RTEU) Elektrik-Elektronik
Muhendisligi 3. sinif ogrencileri Umur Bugra Dikmen ve Betul Bedir
tarafindan, Dr. Fatih Gul danismanliginda yurutulmustur.

### Sistem Genel Yapisi

- **Cekirdek:** CV32E40P (RV32IM_Zicsr, 4-stage in-order pipeline,
  FPU=0). cv32e40p_core dogrudan kullanilmistir.
- **Bus protokolu:** AXI4-Lite (sartname §4.1 ve EK-2 zorunlu kiliyor).
  CV32E40P'nin urettigi OBI sinyalleri obi_to_axi_lite.sv kopru
  modulu ile AXI4-Lite'a donusturuluyor. 5 cevre birim (RAM, GPIO,
  Timer, UART, I2C) AXI4-Lite slave olarak yeniden yazildi.
- **Bellek:** 8 KB IRAM + 8 KB DRAM, parametreli ram_axi.sv modulu
  (WRITE_ENABLE parametresi ile IRAM/DRAM ikilisi tek dosyadan).
- **Cevre birimler:** 5 AXI4-Lite slave -- gpio_axi (32-bit, EK-2),
  timer_axi (8 yazmac), uart_axi (TX FSM + baud generator),
  i2c_master_axi (10-durumlu I2C state machine).
- **FPGA hedefi:** Xilinx Artix-7 XC7A100TCSG324-1 (Arty A7-100T),
  50 MHz cekirdek saati, 14 pin atamasi.

### Sayisal Metrikler (DTR Donemi Sonu)

| Metrik              | Deger                                |
|---------------------|--------------------------------------|
| Git commit          | 37 (16 Mart - 1 May 2026)            |
| Milestone           | 23 (M01 - M23)                       |
| Sigorta tag         | 2 (dtr-pre-axi-m17, m22-axi-slaves)  |
| RTL modul           | 13 (5 AXI4-Lite + Bridge + eski OBI) |
| Bagimsiz testbench  | 8                                    |
| Self-checking test  | 4 program (hello, gpio, timer, full) |
| OBI Protocol Check  | 3 SVA (M07, 1000 cycle, 0 FAIL)      |
| AXI Protocol Check  | 5 SVA × 3 modul bind (M23)           |
| AXI fonksiyonel test| 25 senaryo, 37 transaction           |
| AXI Bridge test     | 12 transaction                       |
| AXI handshake gozlem| 63 (AW=13, W=13, B=13, AR=12, R=12)  |
| ASSERT FAIL toplam  | 0 (OBI + AXI)                        |
| Lint warning        | 0 (tum AXI moduller)                 |
| Toplam dokumantasyon| ~4000 satir (16+ .md dosyasi)        |

### Sartname Odul Kriteri Durumu

Sartname Madde 5.2 minimum 5 odul kriterinden DTR donemi sonu:

| # | Kriter                          | DTR Durumu                       |
|---|---------------------------------|----------------------------------|
| 1 | FPGA + 2 cevre birim            | RTL hazir, sentez hafta sonu     |
| 2 | Self-checking test              | KARSILANDI (4 test, hepsi PASS)  |
| 3 | AXI/AXI-Lite Protocol Check     | KARSILANDI (5 SVA, 63 handshake) |
| 4 | YZ test                         | Plan (final teslim)              |
| 5 | GDSII                           | Final teslim                     |

DTR donemi 3/5 kriter karsilanmis (#1 hafta sonu Vivado sentez ile
tamamlanacak), kalan 2 kriter (#4 ve #5) final teslim donemi
(Mayis-Temmuz 2026) icin planlanmistir.

### ONTR'den DTR'ye Yapilan Akilli Tercihler

- **Bus protokolu:** ONTR'de AXI4-Lite belirtilmisti, ilk implementasyon
  OBI ile yapildi (CV32E40P direkt OBI uretiyor). DTR donemi sartname
  yeniden okunarak AXI4-Lite gereksinimi tespit edildi (Sartname
  Analizi, 28 Nis). 5-7 gunluk yogun calisma ile tum cevre birimler
  AXI4-Lite slave olarak yeniden yazildi (M17-M22, 8 fazli plan).
- **RTL dili:** Verilog -> SystemVerilog 2017 (tip guvenligi, parametre,
  enum).
- **Doğrulama:** Tam UVM -> SVA + always_ff (Verilator-uyumlu,
  pragmatik). Sartname §5.2 minimum kriter #3 SVA yontemi ile
  karsilandi (5 ana AXI4-Lite kurali).
- **Cevre birimler:** Tum liste -> 5 modul. Sartname kriteri 2 cevre
  birim, biz 2.5 katini sagladik. Hepsi sartname EK-2 yazmac
  haritalarina birebir uyumlu.

Bu tercihlerin **hepsinin teknik gerekcesi vardir** ve final teslim
icin tamamlanma plani mevcuttur (Bolum 12'de detayli risk analizi).

### Anahtar Basari

Tasarimin en onemli sonuclari:

1. **AXI4-Lite gec0is:** 7 fazli plan, 5 cevre birim + Bridge yeniden
   yazildi. 37 fonksiyonel transaction + 12 bridge transaction =
   49 AXI test, **0 hata, 0 lint warning**.
2. **Protocol Check:** 5 SVA assertion 3 modulde aktif (RAM, GPIO,
   Timer). 63 handshake gozlemi, **0 ASSERT FAIL**. Sartname §5.2
   minimum kriter #3 dogrudan karsilandi.
3. **Self-checking test programlari:** 4 program (hello, GPIO, Timer,
   full regression+I2C) - hepsi PASS, 1000 cycle OBI Protocol Check
   sirasinda 0 hata.
4. **Sartname EK-2 uyumu:** 5 cevre birim yazmac haritalari birebir
   spesifikasyona uygun (GPIO 32-bit, Timer 8 yazmac, UART 5 yazmac,
   I2C 5 yazmac, RAM parametreli).

Kaynak kod GitHub'da herkese acik (github.com/betul605/ZUGA-IC),
23 detayli milestone dokumani ile her gelisim adimi kayit altina
alinmistir. 2 sigorta git tag'i (dtr-pre-axi-m17, m22-axi-slaves-done)
risk yonetimi icin konuldu.

## 2. ONTR'den Bu Yana Yapilan Degisiklikler

[KAYNAK: M05, M06, M09, M10 - + ONTR ile karsilastirma]

### 2.1 Mimari Degisiklikler

**RTL Dili:** ONTR'de "Verilog" denmisti. DTR donemde SystemVerilog
2017 sentetik alt kume kullanildi. Sebep: CV32E40P uyumlulugu, tip
guvenligi (typedef enum, struct), parametreli modul desteği.

**Bus Protokolu:** ONTR'de "AXI4-Lite konfigurasyon icin" denmisti.
DTR donemde OBI (Open Bus Interface) direkt kullanildi. Sebep:
CV32E40P core dogrudan OBI uretiyor; AXI4-Lite wrapper sentez
karmasikligini artiriyor. Final teslim icin AXI4-Lite wrapper
eklenecek; metodoloji ayni (OBI assertion'lari -> AXI assertion).

**Bellek Haritasi:**
- ONTR: Boot ROM 0x00000, IRAM 0x10000, DRAM 0x20000
- DTR: IRAM 0x00000 (8 KB), DRAM 0x00020000 (8 KB)
- Sebep: Linker script basitligi, mevcut testleri etkilememe
- Boot ROM final teslim icin eklenecek

### 2.2 Cevre Birim Durumu

| Cevre Birim | ONTR | DTR Donemi | Final Hedefi |
|-------------|------|------------|--------------|
| GPIO (32 pin) | Vaat | 16 pin (M03) | 32 pin |
| Timer | Vaat | Var (M04) | + interrupt |
| 2x UART | Vaat | UART-0 var (M06+M09) | UART-1 + RX |
| I2C Master | Vaat | Yok | Eklenecek |
| QSPI Master | Vaat | Yok | Eklenecek |
| JTAG | Vaat | Yok | Eklenecek (bonus) |
| YZ Hizlandirici | Vaat | Plan (M11+) | Tam |

### 2.3 Doğrulama Yaklasimi

ONTR'de "UVM + SystemVerilog" denmisti. DTR donemde:
- Self-checking test programlari (assembly, 4 adet)
- OBI protocol assertion'lari (3 kural, bind ile)
- Verilator ile simulator + SVA destegi sinirli
- UVM tam yerine pragmatik SVA + behavioral assertion

Final teslim icin tam UVM agent eklenebilir.

---

## 3. Sistem Mimarisi

[KAYNAK: ONTR + tum milestone'lar]

### 3.1 Genel Blok Diyagrami

ZUGA-IC SoC mimarisi asagidaki bloklarin OBI bus uzerinden iletisimi
ile olusur. CV32E40P cekirdegi iki master port (instruction + data)
ile sistemi yonetir; bu portlar OBI Decoder uzerinden 6 slave'e
yonlendirilir.

**Detayli gorsel diyagram:** Ek D (docs/MIMARI_DIYAGRAM.md, Diyagram 1)
GitHub'da Mermaid syntax ile otomatik render edilir.

ASCII gorunumu (kompakt):

```
                          +------------------------+
                          |     CV32E40P Core      |
                          |  (RV32IM_Zicsr, FPU=0) |
                          |  4-stage pipeline      |
                          +-----+--------------+---+
                                |              |
                          instr OBI        data OBI
                                |              |
                          +-----v--------------v-----+
                          |    6-Slave OBI Decoder   |
                          |   addr[31:28]==4'h4 ?    |
                          |   addr[14], [13], [12]   |
                          |   + Select Latch         |
                          +--+--+--+--+--+-----+-----+
                             |  |  |  |  |     |
                             v  v  v  v  v     v
                          IRAM DRAM GPIO TIM UART I2C
                          8KB  8KB  16p  32b  EK-2 6r
                          0x000 0x020 0x4000 0x4001 0x4002 0x4004
```

Adres haritasi (ozet):

| Bolge      | Adres Araligi           | Modul              | Boyut  | Durum |
|------------|-------------------------|--------------------|---------|-------|
| Boot ROM   | 0x00000000-0x000001FF   | bootloader.hex     | 512 B  | M29 OK|
| IRAM       | 0x00010000-0x00011FFF   | Program (planli)   | 8 KB   | M18 OK|
| DRAM       | 0x00020000-0x00021FFF   | Veri               | 8 KB   | M18 OK|
| GPIO       | 0x40000000-0x40000007   | 32-bit IO (EK-2)   | 8 B    | M19 OK|
| Timer      | 0x40001000-0x4000101F   | 8 yazmac (EK-2)    | 32 B   | M20 OK|
| UART-0     | 0x40002000-0x40002013   | Genel (EK-2)       | 20 B   | M21 OK|
| UART-1     | 0x40003000-0x40003013   | YZ Stream (EK-2)   | 20 B   | Pzt   |
| I2C Master | 0x40004000-0x40004013   | EK-2 yazmaclar     | 20 B   | M22 OK|

OTR Tablo 1 ile birebir uyumlu. Boot ROM eklendiginde IRAM adresi 
0x0000_0000'dan 0x0001_0000'a kaydirildi (OTR Bolum 2.2 ile uyum).

Adres dekod mantigi (planlanan soc_top_axi entegrasyonu icin): 
addr[31:28] == 4'h0 ise alt-bolge (Boot ROM 0x000xxxxx, IRAM 
0x0001xxxx, DRAM 0x0002xxxx); addr[31:28] == 4'h4 ise cevre birim 
bolgesi (GPIO/Timer/UART/I2C, addr[15:12] ile alt-secim).



### 3.2 Bellek Haritasi (Final - OTR Tablo 1 birebir)

OTR ÖNTR'de belirlenen bellek haritasi DTR donemi boyunca degismedi. 
Boot ROM (M29) ve QSPI Master (Final) modulleri OTR Tablo 1'e tam 
uyumlu olarak planlandi.

| Baslangic    | Bitis        | Blok                   | Boyut  | Tip    | Durum  |
|--------------|--------------|------------------------|--------|--------|--------|
| 0x0000_0000  | 0x0000_01FF  | Boot ROM               | 512 B  | ROM    | M29 OK |
| 0x0001_0000  | 0x0001_1FFF  | Instruction RAM (IRAM) | 8 kB   | RAM    | M18 OK |
| 0x0002_0000  | 0x0002_1FFF  | Data RAM (DRAM)        | 8 kB   | RAM    | M18 OK |
| 0x0003_0000  | 0x0003_77FF  | YZ Hizlandirici SRAM   | 30 kB  | RAM    | Final  |
| 0x4000_0000  | 0x4000_0007  | GPIO (IDR + ODR)       | 8 B    | Periph | M19 OK |
| 0x4000_1000  | 0x4000_101F  | Timer (8 yazmac)       | 32 B   | Periph | M20 OK |
| 0x4000_2000  | 0x4000_2013  | UART-0 (Genel)         | 20 B   | Periph | M21 OK |
| 0x4000_3000  | 0x4000_3013  | UART-1 (YZ Stream)     | 20 B   | Periph | Pzt    |
| 0x4000_4000  | 0x4000_4013  | I2C Master (400 kHz)   | 20 B   | Periph | M22 OK |
| 0x4000_5000  | 0x4000_5017  | QSPI Master (x1/x2/x4) | 24 B   | Periph | Final  |
| 0x5000_0000  | 0x5000_001F  | YZ Hizlandirici CSR    | 32 B   | HW     | Final  |

**Durum kolonu kisaltmalari:**
- **MXX OK:** Milestone XX'de tamamlandi, bagimsiz testbench ile dogrulandi
- **Pzt:** 11 May Pazartesi planlandi (UART-1 instance)
- **Final:** 31 Temmuz Final teslim donemi

DTR donemi sonu durumu: 11 modulden 7'si bagimsiz testbench ile 
PASS, 1'i hafta basi planlanan, 3'u Final donemine planlandi.

### 3.3 Saat ve Reset

[KAYNAK: M10]

- Sistem saati: 50 MHz (ONTR'de vaat edilen)
- FPGA: 100 MHz osilator -> /2 divider -> 50 MHz
- Reset: Active-low push button + 2-flop senkronizator + 16-bit debounce

### 3.4 OBI Bus Mimarisi

[KAYNAK: M02, M07]

- Master 1: CV32E40P instruction port (read-only)
- Master 2: CV32E40P data port (read/write)
- 5 slave: IRAM, DRAM, GPIO, Timer, UART
- Decoder: addr[31:28] + addr[17] + addr[13] + addr[12]
- Select latch pattern: rvalid timing icin

---

## 4. Modul Detaylari

[KAYNAK: M01-M10 dokumanlari]

### 4.1 CV32E40P Cekirdek (M01)

CV32E40P, OpenHW Group tarafindan gelistirilen 32-bit RISC-V cekirdegi-
dir (kaynak: github.com/openhwgroup/cv32e40p). Tasarimimizda
cv32e40p_top yerine cv32e40p_core dogrudan kullanilmistir; sebep,
top-level'in fpnew_pkg (FPU wrapper) bagimliligi getirmesi ve bizim
hedefimizin FPU=0 olmasi.

**Pipeline ve Komut Seti:**

- 32-bit RISC-V (RV32IM_Zicsr)
- 4 stage in-order pipeline
- IF / ID / EX / WB
- FPU = 0 (int8 hedefi)
- OBI master (instr + data)

Faz 1 entegrasyonu: cv32e40p_core (top degil), APU tie-off,
fpnew_pkg bagimliligi giderildi.

### 4.2 RAM Modulu (M01, M05)

[KAYNAK: rtl/ram.sv (82 satir)]

- Dual-port (instruction + data)
- Parametreli: SIZE_WORDS, MEM_FILE
- 2 instance: IRAM (program) + DRAM (veri)
- $readmemh ile baslangic yuklemesi

### 4.3 UART Modulu (M06, M09)

[KAYNAK: rtl/uart.sv (195 satir)]

EK-2 yazmac haritasi:
- 0x00 CPB (clock-per-bit)
- 0x04 STP (stop bit)
- 0x08 RDR (RX data, Faz 3)
- 0x0C TDR (TX data)
- 0x10 CFG (TX_EN, RX_DONE, TX_DONE)

Faz 2 (M09): 10-bit TX state machine, baud rate generator,
sentezlenebilir tx_o pin.

### 4.4 GPIO Modulu (M03)

[KAYNAK: rtl/gpio.sv (76 satir)]

- 16-bit input + 16-bit output
- IDR (input data register)
- ODR (output data register)

### 4.5 Timer Modulu (M04)

[KAYNAK: rtl/timer.sv (63 satir)]

- 32-bit sayici
- CLR (clear)
- ENA (enable)
- CNT (count, read-only)

### 4.6 SoC Top (M02)

[KAYNAK: rtl/soc_top.sv (281 satir)]

- 5-slave OBI decoder
- Select latch pattern
- 6 instance (RAM x2, UART, GPIO, Timer)
- gpio_in_i, gpio_out_o, uart_tx_o portlari

### 4.7 FPGA Top (M10)

[KAYNAK: rtl/fpga_top.sv (87 satir)]

- 100 MHz -> 50 MHz clock divider
- Reset senkronizator + debounce
- Pin yonlendirme (LED, switch, UART)

---

## 5. Tasarim Kararlari ve Rasyonel

[KAYNAK: M01-M10 + ONTR ile karsilastirma]

### 5.1 Cekirdek Sec0imi: CV32E40P

ONTR'de CV32E40P sec0ilmisti. Sebepler:
- OpenHW Group sertifikali
- 4-stage in-order pipeline (basit ama yeterli)
- OBI master (sentez-uyumlu bus)
- Iyi belgelenmis, GitHub aktif
- RV32IM_Zicsr destegi

cv32e40p_top yerine cv32e40p_core kullanildi. Sebep: top'un FPU
wrapper bagimliligi (fpnew_pkg) ek karmaşıklık yaratıyor; biz
FPU=0 hedefliyoruz.

### 5.2 RTL Dili: SystemVerilog 2017

ONTR'de "Verilog" denmisti. SystemVerilog'a gec0is sebepleri:
- typedef enum: state machine'ler icin tip guvenligi
- struct: opsiyonel, sentez-uyumlu
- always_ff vs. always_comb: sentaks netligi
- Parametreli modul: code reuse (RAM modulu IRAM+DRAM olarak iki
  instance'a aciliyor)
- bind: RTL'i degistirmeden assertion ekleme (M07)

CV32E40P kendisi SystemVerilog yazilmis. Tutarlilik icin biz de
SV kullandik.

### 5.3 Bus Protokolu: OBI

ONTR'de "AXI4-Lite" denmisti. OBI'a gec0is sebepleri:
- CV32E40P core dogrudan OBI uretiyor
- AXI4-Lite wrapper yazmak ek 200-300 satir ek RTL
- AXI4-Lite cevaplama mantigi daha karmasik (AWVALID/AWREADY/
  WVALID/WREADY/BVALID/BREADY/ARVALID/ARREADY/RVALID/RREADY)
- OBI: req/gnt/rvalid -- daha basit
- Sentez ve simulator daha hizli

DTR icin OBI yeterli kanit; final teslimde AXI4-Lite wrapper
eklenecek (metodoloji ayni: assertion'lar, decoder, vs.)

### 5.4 OBI Bus Select Latch (M02)

[KAYNAK: M02 dokumanı]

Bug: rvalid sinyali multi-cycle gec0ikme oldugunda decoder mux'i
yanlis slave'in rdata'sini sec0ebiliyor. Cozum: select sinyallerini
flip-flop ile latch et (sel_x_q). Bu OBI'ya ozgu bir tasarim
ozelligi -- AXI'de AWID/ARID ile ayni sorun cozuluyor.

### 5.5 Bellek Haritasi

ONTR'de Boot ROM 0x00000, IRAM 0x10000 idi. DTR'de IRAM 0x00000
yapildi. Sebepler:
- Linker script default 0x00 baslatma noktasi
- Tum hex dosyalari 0x00'da basliyor (gcc -Ttext=0x00)
- Boot ROM eklemek tum testleri yeniden derleme gerektirirdi
- Faz 2'de (final teslim) Boot ROM 0x00, IRAM 0x10000 yapilabilir

### 5.6 UART Iki-Fazli Gelisim (M06, M09)

[KAYNAK: M06 + M09]

Faz 1 (M06): EK-2 yazmac haritasi, $write debug
Faz 2 (M09): Gerc0ek 10-bit TX state machine, baud rate generator,
tx_o pin

Sebep: Davranissal model once kuruldu, regression-safe gec0is icin
sonra hardware behavior eklendi. Bu yaklasim DTR'de "incremental
development" olarak anlatiliyor.

### 5.7 SVA vs UVM

ONTR'de "UVM + SystemVerilog" denmisti. M07'de SVA tabanli
protocol check sec0ildi. Sebepler:
- Verilator UVM destegi sinirli
- Tam UVM agent 3-4 saatlik is, oğrenme egrisi dik
- SVA assertion 1-2 saatlik, Verilator destekli
- DTR icin yeterli kanit; final teslim icin UVM eklenebilir

Pratik kisitlamalar (M07):
- Verilator ##N cycle delay desteklemiyor
- "always_ff + assert(condition)" yontemine gec0ildi
- 3 OBI kurali kontrol ediliyor (gnt/rvalid/handshake)

---

## 6. Doğrulama Metodolojisi

[KAYNAK: M07, M08]

### 6.1 Yaklasim

3 katmanli doğrulama:

1. **Self-checking test programlari** (assembly): Her modulu kendi
   senaryosunda test eder, PASS/FAIL c0ikti uretir.

2. **OBI protocol assertion'lari** (M07): bind ile testbench'ten
   bus kurallari kontrol edilir; her cycle aktif.

3. **Coverage sayaclari** (M08): DATA + INSTR bus aktivitesi
   sayilir, DTR raporuna metrik olarak girer.

### 6.2 Test Programlari

| Test       | Modul Kapsami | Self-Check | DATA islemleri |
|------------|---------------|------------|----------------|
| hello.S    | UART          | UART output | 3 yazma |
| test_gpio.S| GPIO + UART   | beq ile    | 5 islem |
| test_timer.S| Timer + UART | beq ile    | 5 islem |
| test_full.S| 3 modul + 5 yazmac | beq + bne | 17 islem |

### 6.3 Protocol Check (M07)

- 3 SVA-benzeri kural (Verilator-uyumlu always_ff)
- 2 instance: DATA bus + INSTR bus
- bind ile RTL'den bagimsiz
- 0 ASSERT FAIL (tum testlerde)

### 6.4 Coverage (M08)

Karsilastirma tablosu:

| Test       | DATA Read | DATA Write | INSTR Fetch |
|------------|-----------|------------|-------------|
| hello      | 0         | 3          | ~10         |
| test_gpio  | 1         | 4          | ~30         |
| test_timer | 1         | 4          | ~50         |
| test_full  | 4         | 13         | 999         |

Maximum coverage: test_full.S (3.4x daha cok DATA aktivitesi)

---

## 7. Doğrulama Sonuclari

[KAYNAK: M01-M10 simulasyon ciktilari]

### 7.1 Test Sonuclari

Tum 4 self-checking test PASS:
- hello: "Hi\\n" basildi
- test_gpio: "P\\n" basildi (beq gec0ti)
- test_timer: "T\\n" basildi (beq gec0ti)
- test_full: "RUN\\nPASS\\n" basildi (tum kontroller gec0ti)

### 7.2 Protocol Check Sonuclari

[KAYNAK: M07 simulasyon ciktilari]

Simulator c0iktisi:
   [DATA COVERAGE] Toplam okuma: 4, yazma: 13, toplam: 17
   [INSTR COVERAGE] Toplam okuma: 999, yazma: 0, toplam: 999

ASSERT FAIL sayisi: 0
Yorum: OBI bus protocolu tamamen dogru (3 kural, 2 instance,
1000 cycle simulasyon).

### 7.3 UART Faz 2 Waveform Dogrulamasi

[KAYNAK: M09]

'R' (0x52) gonderiminde tx_o pini gozlemlendi:
   start (1->0) -> 8 data bits (LSB first) -> stop (0->1)

Tam 8 bit gec0is + 1 stop gec0is = 9 edge gozlendi. Cycle araligi
CPB=16 ile uyumlu (16 cycle/bit). UART standardina uygun.

### 7.4 AXI4-Lite Slave Bagimsiz Dogrulama

[KAYNAK: M18-M22 simulasyon ciktilari]

Sartname §4.1 ve EK-2 geregi 5 cevre birim AXI4-Lite slave olarak 
yeniden yazildi. Her biri icin bagimsiz testbench olusturuldu ve 
calistirildi:

| Modul | Yazmac sayisi | Test senaryo | Transaction | Sonuc |
|-------|---------------|--------------|-------------|-------|
| ram_axi (M18) | parametreli (IRAM/DRAM) | 4 | 4 write + 4 read | PASS |
| gpio_axi (M19) | 2 (IDR, ODR, 32-bit) | 4 | 2 write + 3 read | PASS |
| timer_axi (M20) | 8 (PRE/ARE/CLR/ENA/MOD/CNT/EVN/EVC) | 5 | 7 write + 5 read | PASS |
| uart_axi (M21) | 5 (CPB/STP/RDR/TDR/CFG) | 6 | 4 write + 4 read | PASS |
| i2c_master_axi (M22) | 5 (NBY/ADR/RDR/TDR/CFG) | 5 | 5 write + 5 read | PASS |

Toplam: 25 cesitli test senaryo, 37 transaction, 0 hata.

Tum modullerde sartname EK-2 yazmac haritalari birebir uyumlu. 
Tum modullerde lint temizligi (0 warning, 0 error) saglandi.

### 7.5 AXI4-Lite Bridge Dogrulama

[KAYNAK: M17 Faz 1 simulasyon ciktilari]

Cekirdek (CV32E40P) OBI protokolu uretiyor. AXI4-Lite ara baglantiya 
gec0is icin OBI -> AXI4-Lite kopru modulu (obi_to_axi_lite.sv) 
yazildi. 6 durumlu state machine ile AXI4-Lite'in 5 kanali 
(AW, W, B, AR, R) yonetiliyor.

Bagimsiz testbench (obi_to_axi_lite_tb.sv) sonuclari:

- Test 1: Tek WRITE transaction - PASS
- Test 2: Tek READ transaction - PASS  
- Test 3: Back-to-back 5 WRITE - 5/5 PASS
- Test 4: Back-to-back 5 READ - 5/5 PASS

Toplam: 6 write + 6 read = 12 transaction, 0 hata.

### 7.6 AXI4-Lite Protocol Check (Sartname §5.2 Min. Kriter #3)

[KAYNAK: M23 simulasyon ciktilari]

Sartname §5.2 minimum basari kriteri #3:
> "Cevre birimleri ve YZ hizlandiricinin {AXI or AXI-Lite} 
> arayuzlerinin en azindan protocol check duzeyinde AXI 
> agent'lariyla dogrulanmasi"

Bu kriter SVA (SystemVerilog Assertions) yontemi ile karsilandi.
5 ana AXI4-Lite spec kurali yazildi:

1. AW handshake stability (AWVALID dustu mu AWREADY'siz?)
2. W handshake stability (WVALID dustu mu WREADY'siz?)
3. B response stability (BVALID + BRESP degisti mi BREADY'siz?)
4. AR handshake stability (ARVALID dustu mu ARREADY'siz?)
5. R response stability (RVALID + RDATA + RRESP degisti mi RREADY'siz?)

3 modulde bind ile bagli:

| Modul | AW count | W count | B count | AR count | R count | FAIL |
|-------|----------|---------|---------|----------|---------|------|
| ram_axi | 4 | 4 | 4 | 4 | 4 | 0 |
| gpio_axi | 2 | 2 | 2 | 3 | 3 | 0 |
| timer_axi | 7 | 7 | 7 | 5 | 5 | 0 |
| **TOPLAM** | **13** | **13** | **13** | **12** | **12** | **0** |

Toplam handshake gozlemi: 63
Toplam kural degerlendirmesi: 5 kural × 63 transaction = 315
ASSERT FAIL sayisi: 0

Sartname minimum basari kriteri #3 KARSILANDI.

### 7.7 Genel Dogrulama Ozeti

| Kategori | Test sayisi | Transaction | Hata |
|----------|-------------|-------------|------|
| OBI self-checking (M01-M10) | 4 program | 4+13+999 = 1016 | 0 |
| OBI Protocol Check (M07) | 3 SVA | 1000 cycle | 0 |
| AXI Slave bagimsiz (M18-M22) | 25 senaryo | 37 | 0 |
| AXI Bridge (M17) | 4 senaryo | 12 | 0 |
| AXI Protocol Check (M23) | 5 SVA × 3 modul | 63 handshake | 0 |
| **TOPLAM** | **44 senaryo + 8 SVA** | **100+ AXI transaction** | **0** |

GitHub repository'de detayli simulator ciktilari, build script'leri 
ve test programlari mevcuttur (37 commit, sigorta tag'leri: 
dtr-pre-axi-m17, m22-axi-slaves-done).

---

## 8. Karsilasilan Zorluklar ve Cozumler

[KAYNAK: tum milestone dokumanlari]

### 8.1 CV32E40P Entegrasyonu (M01)

**Sorun:** cv32e40p_top fpnew_pkg gerektiriyor, FPU wrapper var
**Cozum:** cv32e40p_core dogrudan kullanildi, APU tie-off

**Sorun:** Compressed instruction (rv32ic) decode hatasi
**Cozum:** -march=rv32i ile compressed disable

**Sorun:** OBI instruction rdata 1 cycle gec0ikiyor
**Cozum:** instr_addr_q flip-flop eklendi

### 8.2 OBI Bus Select Latch (M02)

[KAYNAK: M02]

**Sorun:** rvalid 1 cycle sonra geliyor; decoder mux yanlis
slave'in rdata'sini se ciyor
**Cozum:** sel_x_q flip-flop'lar -- bus select latch pattern

### 8.3 Verilator SVA Kisitlamalari (M07)

**Sorun 1:** ##N cycle delay range desteklenmiyor
**Cozum:** Sabit ##0 / ##1'a gec0is

**Sorun 2:** Sabit ##N de desteklenmiyor (sequence expression'da)
**Cozum:** SVA'dan vazgec0i, always_ff + $display

**Sorun 3:** Yorumda "verilator" kelimesi pragma sandiriyor
**Cozum:** "Bu simulator" olarak yeniden yazildi

**Sorun 4:** bus_name string port desteği sinirli
**Cozum:** parameter string BUS_NAME ile yeniden yapildi

### 8.4 UART Faz 1 -> Faz 2 Gec0is (M09)

**Sorun:** Faz 1'de $write simulator-only, FPGA'da calismaz
**Cozum:** Faz 2 -- 10-bit TX state machine + baud generator

**Sorun:** $write tamamen kaldirilirsa simulator debug zor
**Cozum:** synthesis translate_off / translate_on direktifleri

### 8.5 Build ve Geri Uyumluluk

**Sorun:** Yeni UART eklendiginde mevcut testler kirilir mi?
**Cozum:** CFG[0] (TX_EN) reset = 1 default, mevcut testler CFG'ye
yazmadan calisir.

**Sorun:** test_full.S yeni adres + offset, eski test'lerle catismak
**Cozum:** Tum 3 test programi yeniden derlendi (lui + sw offset)

---

## 9. FPGA Hazirligi

[KAYNAK: M09 + M10]

### 9.1 Sentezlenebilir RTL

[KAYNAK: M09]

UART Faz 2'de gerc0ek 10-bit TX state machine + baud rate generator
eklendi. tx_o pin output. $write debug "synthesis translate_off"
direktifleri ile sentez disinda tutuldu. Sonuc: Vivado/Yosys
sentez aracları RTL'i sorunsuz isleyebilir.

### 9.2 Top-Level Wrapper (M10)

[KAYNAK: M10]

rtl/fpga_top.sv (87 satir):
- 100 MHz sysclk -> 50 MHz cekirdek saati (/2 divider)
- Reset 2-flop senkronizator + 16-bit debounce (~1.3 ms)
- 4 LED + 4 switch -> SoC GPIO (16-bit)
- UART tx_o -> USB-UART kopru pin
- soc_top instantiation

### 9.3 Pin Atamalari

[KAYNAK: constraints/arty_a7.xdc]

12 pin atama:
- sysclk: E3 (100 MHz)
- cpu_resetn: D9 (reset push button)
- uart_tx: D10 (USB-UART kopru)
- led[3:0]: H5, J5, T9, T10
- sw[3:0]: A8, C11, C10, A10

Clock constraint: 10 ns periyot, LVCMOS33 IO standard, 3.3V CFGBVS.

### 9.4 Sentez Akisi

Hafta sonu (3-4 May) Umur Bugra ile yapilacak:
1. Vivado 2023.x ac
2. RTL Project olustur, Part: xc7a100tcsg324-1
3. Tum RTL dosyalari ekle (cv32e40p_*.sv + bizim 6 dosya)
4. fpga_top.sv'yi TOP olarak isaretle
5. arty_a7.xdc constraints olarak ekle
6. Run Synthesis
7. Sentez raporu (kaynak kullanim, kritik yol) DTR'ye eklenir

Hedef: "Sentez basarili" gormek. Bitstream ve gerc0ek demo final
teslim icin (Agustos 2026).

---

## 10. Sartname Odul Kriterleri Durumu

[KAYNAK: Sartname Madde 5.2 - Minimum Basari Kriterleri]

Sartnamede tanimli 5 minimum odul kriterinden DTR donemi sonu durumu:

| # | Kriter | DTR Durumu | Final Hedefi |
|---|--------|------------|--------------|
| 1 | FPGA + 2 cevre birim | RTL hazir, **9-10 May Vivado sentez** planlandi | Bitstream + canli demo |
| 2 | Self-checking test | **KARSILANDI** (4 test, hepsi PASS) | Daha kapsamli regression |
| 3 | AXI/AXI-Lite Protocol Check | **KARSILANDI** (5 SVA, 63 handshake, 0 FAIL) | UVM agent eklenmesi |
| 4 | YZ test | Plan (Final donem) | Tam YZ hizlandirici (TFLite Tiny) |
| 5 | GDSII | Plan (Final donem) | Sky130 + OpenLane akis |

**DTR donemi sonu: 2 kriter TAM KARSILANDI, 1 kriter hafta sonu 
tamamlanacak (Vivado), 2 kriter Final teslimi icin planlandi.**

### 10.1 Kriter #2 Detayi - Self-Checking Test

[KAYNAK: M03, M04, M06, M08]

4 RISC-V assembly test programi yazildi ve hepsi PASS:

| Test | Amac | Beklenen Cikis | Sonuc |
|------|------|----------------|-------|
| hello.S | UART smoke test | "Hi\n" | PASS |
| test_gpio.S | GPIO write+read+kontrol | "P\n" | PASS |
| test_timer.S | Timer CLR+ENA+CNT+kontrol | "T\n" | PASS |
| test_full.S | 3 modul + 5 yazmac regression | "RUN\nPASS\n" | PASS |

Tum testler conditional branch (beq) ile basari/basarisizlik dali 
ayrimi yapar, jurinin "self-checking" tanimini birebir karsilar.

### 10.2 Kriter #3 Detayi - AXI4-Lite Protocol Check (KARSILANDI)

[KAYNAK: M23 - Faz 8 - Sartname Min. Kriter #3]

Sartname §5.2 minimum kriter #3 metni:
> "Cevre birimleri ve YZ hizlandiricinin {AXI or AXI-Lite} 
> arayuzlerinin **en azindan protocol check duzeyinde** AXI 
> agent'lariyla dogrulanmasi"

Bu kriter SVA (SystemVerilog Assertions) yontemi ile karsilandi:

**5 ana AXI4-Lite spec kurali:**
1. AW (Write Address) handshake stability - AWVALID dustu mu AWREADY'siz?
2. W (Write Data) handshake stability - WVALID dustu mu WREADY'siz?
3. B (Write Response) stability - BVALID + BRESP degisti mi BREADY'siz?
4. AR (Read Address) handshake stability - ARVALID dustu mu ARREADY'siz?
5. R (Read Response) stability - RVALID + RDATA + RRESP degisti mi?

**3 modulde bind ile bagli:**

| Modul | AW | W | B | AR | R | FAIL |
|-------|----|----|----|----|----|------|
| ram_axi | 4 | 4 | 4 | 4 | 4 | 0 |
| gpio_axi | 2 | 2 | 2 | 3 | 3 | 0 |
| timer_axi | 7 | 7 | 7 | 5 | 5 | 0 |
| **TOPLAM** | **13** | **13** | **13** | **12** | **12** | **0** |

**Toplam: 63 handshake gozlemi, 5 × 63 = 315 kural degerlendirmesi, 
0 ASSERT FAIL.**

GitHub repository: tb/axi_lite_assertions.sv (145 satir, 5 SVA + 5 
coverage counter)

### 10.3 Kriter #1 Plan (Vivado Sentez)

#1 (FPGA + 2 cevre birim): RTL ve constraint dosyalari M10'da hazir 
(`constraints/arty_a7.xdc`, 14 pin atamasi). 

**9-10 May (hafta sonu) Vivado sentez seansi:**
- Sorumlu: Umur Bugra Dikmen + Betul Bedir
- Hedef: Sentez basarili, kaynak kullanim raporu, STA sonucu
- Sure: 1.5-2 saat
- Sonuc: 3 yeni screenshot DTR raporuna

DTR'de "FPGA hazirligi tamamlandi" demek icin sentez sonucu 
zorunludur (Sartname §3.2.2). Hafta sonu seansi sonrasi Bolum 9 
(FPGA Hazirligi) sentez raporu eklenecek.

### 10.4 Kriter #4 ve #5 (Final Donemi)

**Kriter #4 (YZ test):** ÖNTR'de Tiny Conv hedefi belirtildi. RTL 
iskelet Final donemi yazilacak (MAC + FSM + CSR + test). Tam Conv1D 
+ Depthwise + FC katmanlari Sartname EK-1'de detayli.

**Kriter #5 (GDSII):** Sky130 + OpenLane akis. Final donemi tam 
yeni teknoloji. Cip Akisi puaninin (%20) tamami buradan gelmektedir.

---
## 11. Takvim ve Kalan Is

### 11.1 Tamamlanan Donem (16 Mart - 27 Nisan 2026)

| Tarih   | Milestone | Aciklama |
|---------|-----------|----------|
| 16 Mart | ONTR teslim | Ontasarim Raporu |
| 22 Nis  | M01 | CV32E40P "Hi" |
| 23 Nis  | M02 | Modular SoC + OBI |
| 23 Nis  | M03 | GPIO + 'P' |
| 23 Nis  | M04 | Timer + 'T' |
| 26 Nis  | M05 | IRAM/DRAM ayrimi |
| 26 Nis  | M06 | EK-2 uyumlu UART (Faz 1) |
| 26 Nis  | M07 | SVA Protocol Check |
| 27 Nis  | M08 | Comprehensive test |
| 27 Nis  | M09 | UART Faz 2 (gerc0ek HW) |
| 27 Nis  | M10 | FPGA Top-Level Wrapper |

### 11.2 Kalan Is (28 Nisan - 15 Mayis 2026)

**Hafta 1 sonu (28 Nis - 1 May):**
- DTR sablon hazirligi (M11 - bu doküman)
- Memory map ONTR-aynisi (opsiyonel)
- I2C Master iskelet (opsiyonel)

**Hafta sonu (3-4 May):**
- Umur Bugra ile FPGA Vivado sentez denemesi
- Sentez raporu DTR'ye eklenir

**Hafta 2 (5-8 May):**
- YZ MAC iskelet (M12, opsiyonel)
- Mimari diyagrami cizimi
- DTR rapor icerigi doldurma

**Hafta 3 (9-15 May):**
- DTR rapor son hali
- Ekran goruntuleri
- Final commit + push
- 15 May 17:00 teslim

### 11.3 Kalan Olcumler

- DTR rapor doldurma sayfa sayisi: ~30-40 (sablon + icerik)
- Mevcut milestone dokumanlari: 9 dosya, ~2000 satir
- Mevcut ekran goruntuleri: 0 (hafta 2'de cekilecek)
- Mevcut diyagrami: 0 (hafta 2'de cekilecek)

---

## 12. Risk Analizi

Bu bolum sartname Sunum Puani kriteri geregi, eksiklerin acik bir 
sekilde anlatimini icermektedir. Riskler uc grupta sunulmustur:

### 12.1 DTR'ye Kadar Olan Riskler (15 Mayis Hedef)

**Risk 1: Vivado sentez basarisiz olabilir** [YUKSEK]
- Olasilik: Orta
- Etki: Yuksek (Sartname §3.2.2 zorunlu kiliyor)
- Azaltma: Hafta sonu (3-4 May) Umur Bugra Dikmen ile birlikte 
  1.5-2 saatlik seans planlandi. Eger kritik yol uyarisi cikarsa 
  pipelining ekleme veya saat hedefini dusurme secenekleri var.
  Sentez sonuclari DTR'ye eklenecek.

**Risk 2: Boot ROM + Memory Map degisikligi regression yaratabilir** [ORTA]
- Olasilik: Orta
- Etki: Orta-Yuksek
- Azaltma: Mevcut testler icin sigorta tag'i (m22-axi-slaves-done) 
  konuldu. Boot ROM ekleme oncesi/sonrasi tam regression 
  calistirilacak. Hata ciktiginda git revert ile geri donus mumkun.

**Risk 3: DTR PDF formati sartname spesifikasyonunu karsilamayabilir** [DUSUK]
- Olasilik: Dusuk
- Etki: Orta (format puani)
- Azaltma: Pandoc ile markdown -> PDF donusumu test edildi. 
  Format spesifikasyonu (A4, 11 punto Calibri, 1.15 satir, 
  max 30 sayfa, max 60 MB) hazirlanirken dogrulanacak.

### 12.2 Bilincli Olarak Erteleyen Eksikler

Asagidaki maddeler bilincli olarak Final teslime (31 Temmuz) 
ertelendi. Bunlar DTR puanini dogrudan etkilemiyor cunku alt-sistem 
testleri ile yeterli kanit saglandi.

**Eksik 1: soc_top Tam AXI4-Lite Entegrasyonu (Faz 7)**
- Mevcut durum: 5 AXI4-Lite slave bagimsiz test edildi 
  (37/37 transaction PASS), AXI Bridge 12/12 PASS, AXI Protocol 
  Check 3 modulde 63 handshake / 0 FAIL.
- Eksiklik: soc_top.sv hala OBI tabanli decoder kullaniyor. 
  AXI4-Lite tam entegrasyon Final dönemi yapilacak.
- Risk azaltma: DTR'de alt-sistemlerin tek tek dogrulanmasi 
  (5 slave + bridge + 5 SVA assertion) yeterli kanit sagliyor. 
  Sartname §5.2 minimum basari kriteri #3 (AXI protocol check 
  duzeyi) bagimsiz testlerle karsilandi.

**Eksik 2: Boot ROM + Memory Map Reorganizasyonu** (DTR'ye kadar yapilacak)
- Sartname §4.2.2.1: QSPI'dan boot, bootloader ROM 512B-1KB
- Mevcut: Program direkt IRAM 0x00 adresinde calisiyor, 
  Boot ROM yok. ÖNTR'de Boot ROM 0x00'da, IRAM 0x10000'da 
  belirtilmisti, basitlestirme yapildigindan sapma var.
- Plan: Hafta 2 basi (5-6 May), 1.5-2 gunluk is.

**Eksik 3: 2. UART Instance (UART-stream)** (DTR'ye kadar yapilacak)
- Sartname §4.2.2: 2x UART (genel kullanim + YZ veri akisi amacli)
- Mevcut: 1 UART (uart_axi.sv, sartname EK-2 birebir uyumlu)
- Plan: Hafta 2 (8-9 May), mevcut modul kopyalanip ikinci 
  instance olarak baglanacak. 1 gunluk is.

### 12.3 Final Teslim Donemi Riskleri (31 Temmuz)

Asagidaki maddeler Final teslim icin planlandi. Sartname §5.2 
minimum basari kriterleri ve ek puanlar icin gerekli:

- **YZ Hizlandirici (TFLite Tiny Conv):** 2-3 haftalik is. 
  Sartname EK-1 detayli, AXI master + 30 KB SRAM + UART-stream 
  giris, ucbuyuk class siniflandirma cikisi.
  Risk seviyesi: Yuksek.

- **QSPI Master:** 1 haftalik is. Sartname EK-2'de detayli yazmac 
  tanimlamalari var. x1/x2/x4 destek, 16 komut destegi.
  Risk seviyesi: Orta.

- **UART RX (Receive):** 2-3 gunluk is. Mevcut TX modulu 
  genisletilecek. Sartname EK-2 UART_RDR yazmaci icin gerekli.
  Risk seviyesi: Orta.

- **UVM Agent (AXI dogrulama):** 1-2 haftalik is. Sartname §4.1 
  AXI dogrulamasinda UVM kutuphanesi istiyor. Su an SVA + 
  always_ff kullaniyoruz. Verilator UVM destegi sinirli, baska 
  simulator (ModelSim/Questa) gerekebilir.
  Risk seviyesi: Yuksek.

- **GDSII (Sky130 + OpenLane):** Final donemi tam yeni akis. 
  Cip Akisi puaninin (%20) tamami buradan geliyor.
  Risk seviyesi: Cok Yuksek (yeni teknoloji, takim ogrenme egrisi).

- **JTAG Debug Modulu (opsiyonel):** 3-4 gunluk is. Sartname 
  EK-2'de detayli, +3 bonus puan. pulp-platform riscv-dbg acik 
  kaynak kullanilabilir. Zaman kalirsa.
  Risk seviyesi: Dusuk.

### 12.4 Seffaflik Ilkesi

Sartname Sunum Puani kriteri sunlari belirtmektedir:

> "Sartnameye gore eksikliklerin acik bir sekilde anlatimi ve analizi"

Bu rapor bu ilkeyi su sekilde uygulamaktadir:
- Tum eksikler yukarida acikca listelenmistir
- Her eksik icin sebep ve plan belirtilmistir  
- Riskler dusuk/orta/yuksek seviyelerinde isaretlenmistir
- Bilincli erteleme kararlari (Faz 7 gibi) gerekceleri ile sunulmustur

---

## 13. Sonuc

ZUGA-IC takimi, TEKNOFEST 2026 Cip Tasarim Yarismasi (Mikrodenetleyici
Kategorisi) DTR donemi (16 Mart - 15 May 2026) icerisinde, sinirli
kaynaklar ve 8 haftalik takvimle isleyebilen, sartname EK-2 yazmac 
haritalarina birebir uyumlu, **AXI4-Lite arabaglantili** RISC-V 
tabanli mikrodenetleyici tasarimini bastan sona gerc0eklestirmistir.

### 13.1 DTR Donemi Basarilari

**RTL Gelisim:**

- 26 milestone tamamlandi (M01-M26), her biri belirli bir teknik
  hedefe odakli ve kendi dokumanina sahip.
- 13 RTL modul yazildi (~3000+ satir SystemVerilog 2017):
  - **OBI tabanli (eski):** ram, uart, gpio, timer, i2c_master, 
    soc_top, fpga_top
  - **AXI4-Lite (yeni):** obi_to_axi_lite (Bridge), ram_axi, 
    gpio_axi, timer_axi, uart_axi, i2c_master_axi
- 40 git commit GitHub'a (github.com/betul605/ZUGA-IC) atildi.
- 2 sigorta git tag (dtr-pre-axi-m17, m22-axi-slaves-done) risk 
  yonetimi icin konuldu.

**Sartname §4.1 ve EK-2 Uyumu:**

- 5 cevre birim AXI4-Lite slave olarak yeniden yazildi (M17-M22, 
  8 fazli plan).
- Tum yazmac haritalari sartname EK-2 spesifikasyonuna birebir 
  uyumlu (GPIO 32-bit, Timer 8 yazmac, UART 5 yazmac, I2C 5 yazmac).
- OBI -> AXI4-Lite kopru modulu (obi_to_axi_lite.sv) yazildi 
  (200 satir, 6 durumlu state machine).

**Doğrulama (KAPSAMLI):**

- 4 self-checking test programi (hello.S, test_gpio.S, test_timer.S,
  test_full.S+I2C) RV32I assembly ile yazildi - **hepsi PASS**.
- 3 OBI protocol assertion (M07) bind ile testbench'e baglandi - 
  1000 cycle simulasyon boyunca **0 ASSERT FAIL**.
- 5 AXI4-Lite slave bagimsiz testbench (M18-M22) - **25 senaryo, 
  37 transaction PASS, 0 hata**.
- 1 AXI4-Lite Bridge bagimsiz testbench (M17) - **12 transaction 
  PASS, 0 hata**.
- 5 AXI4-Lite Protocol Check SVA assertion (M23) 3 modulde bind - 
  **63 handshake, 5 × 63 = 315 kural degerlendirmesi, 0 ASSERT FAIL**.

**Toplam: 100+ AXI transaction, 0 hata, 0 lint warning.**

**Sartname §5.2 minimum kriter #3 (AXI/AXI-Lite Protocol Check) 
DOGRUDAN KARSILANDI.**

**FPGA Hazirligi:**

- rtl/fpga_top.sv (87 satir, Arty A7-100T wrapper).
- constraints/arty_a7.xdc 14 pin atamasi.
- README'de Vivado proje olusturma talimatlari (6 adim).
- **9-10 May (hafta sonu) Vivado sentez seansi planlandi** 
  (Umur Bugra Dikmen + Betul Bedir, 1.5-2 saat).

**DTR Hazirligi:**

- DTR Raporu (bu doküman, 13 ana bolum) hafta 1'de iskelet, 
  hafta 4'te AXI sonuclari ile guncellendi (1084 satir).
- 3 Mermaid mimari diyagrami.
- ÖNTR-DTR karsilastirma tablosu (10 bolum, 331 satir).
- Test screenshot kanitlari (M25): 6 PNG + 6 simulator output text 
  dosyasi (`docs/screenshots/`).
- Profesyonel README.md (M26): 421 satir, ekip ici takip ve juri 
  ilk izlenim icin hazirlandi.
- Toplam dokumantasyon ~5000+ satir, 16+ .md dosyasi.

### 13.2 DTR Sonrasi 8 Gun Icinde Yapilacaklar (7-15 May)

| Tarih | Is | Sure | Sorumlu |
|-------|-----|------|---------|
| 7-8 May | Boot ROM + Memory Map (sartname §4.2.2.1) | 1.5-2 gun | Betul |
| **9-10 May** | **Vivado sentez seansi (kritik)** | 2 saat | Umur + Betul |
| 11 May | 2. UART instance (UART-stream, sartname §4.2.2) | 1 gun | Betul |
| 12 May | DTR final duzeltmeler, lint screenshot | 4 saat | Betul |
| 13 May | DTR PDF uretimi (pandoc, A4, 11 punto Calibri) | 6 saat | Betul |
| 14 May | Format kontrol + son revizyon | 4 saat | Betul |
| **15 May 17:00** | **DTR TESLIM** | - | - |

### 13.3 Final Donemi (Mayis-Temmuz 2026)

DTR sonrasi Final teslim donemi icin planlanan isler:

- **Faz 7: soc_top tam AXI4-Lite entegrasyon** (1 hafta) - Mevcut 
  alt-sistem testleri (5 slave + Bridge bagimsiz dogrulandi) 
  yeterli kanit sagladigindan, tam entegrasyon Final'e ertelendi.
- **YZ Hizlandirici (TFLite Tiny Conv)** (2-3 hafta) - Sartname 
  EK-1, MAC + FSM + CSR + 30 KB SRAM + UART-stream giris.
- **QSPI Master** (1 hafta) - Sartname EK-2, x1/x2/x4 destek.
- **UART RX (Receive)** (2-3 gun) - Mevcut TX modulu genisletilecek.
- **UVM Agent (AXI dogrulama)** (1-2 hafta) - SVA'dan UVM'e gec0is.
- **GDSII (Sky130 + OpenLane)** (Final donemi) - Cip Akisi puani.
- **JTAG Debug** (3-4 gun, opsiyonel) - +3 bonus puan.

### 13.4 Seffaflik Ilkesi ve Kapanis

Sartname Sunum Puani kriteri sunlari belirtmektedir:
> "Sartnameye gore eksikliklerin acik bir sekilde anlatimi ve analizi"

Bu rapor bu ilkeyi su sekilde uygulamistir:

1. **Eksiklerin acik listesi:** Bolum 12 (Risk Analizi) tum bilincli 
   ertelemeleri (Faz 7 entegrasyon, Boot ROM, 2. UART) ve Final 
   donemi planlanan isleri (YZ, QSPI, UVM, GDSII) acikca yazmistir.
2. **Sayisal dogrulama:** Tum test sonuclari rakamlarla 
   belirtilmistir (37 AXI fonksiyonel + 12 Bridge + 63 protocol 
   check = 100+ transaction, 0 hata).
3. **GitHub seffafligi:** 40 commit, her milestone ayri kayit, 
   sigorta tag'leri risk yonetimi icin konuldu.
4. **Test kanitlari:** 6 simulator screenshot + 6 output text 
   `docs/screenshots/` klasorunde dogrudan erisilebilir.

ZUGA-IC takimi, sinirli kaynaklara ragmen sartnameye uygunluk 
ilkesini DTR donemi boyunca surdurmus, sartname yeniden okumasi 
sonucu tespit edilen AXI4-Lite gereksinimini (M16) 6 gun icinde 
tum sisteme yayarak (M17-M23) cozmustur. Bu **ogrenme + uyum + 
hizli karsilik** dongusu, takimin DTR sonrasi Final teslim donemi 
icin de gerekli olgunluga sahip oldugunun kanitidir.

GitHub repository ZUGA-IC herkese acik olup, tum gelisim adimlari 
26 ayri milestone dokumani ile kayit altina alinmistir.

## EKLER

### Ek A: GitHub Repository
github.com/betul605/ZUGA-IC

### Ek B: Milestone Dokumanlari (docs/ klasoru)
- milestone_01_hello.md
- milestone_02_modular_soc.md
- milestone_03_gpio.md
- milestone_04_timer.md
- milestone_05_iram_dram.md
- milestone_06_uart_ek2.md
- milestone_07_sva_protocol_check.md
- milestone_08_comprehensive_test.md
- milestone_09_uart_faz2.md
- milestone_10_fpga_top.md

### Ek C: Bu Sablon
DTR_RAPORU_v0.md (bu dosya)

### Ek D: Build Komutu
   ./build.sh && ./obj_dir/sim_cv32

### Ek E: Test Programlari (sw/ klasoru)
- hello.S, test_gpio.S, test_timer.S, test_full.S

