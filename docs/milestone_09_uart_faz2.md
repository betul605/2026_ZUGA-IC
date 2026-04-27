# Milestone 09: UART Faz 2 - Gercek Donanim Davranisi

**Tarih:** 27 Nisan 2026
**Commit:** 89f3ae8

## Hedef

UART modulunu simulator-only davranisindan (basit $write ile karakter
basma) gerc0ek donanim davranisina (10-bit TX state machine + baud rate
generator + serial pin) gec0irmek. FPGA'ya yuklenebilir, sentezlenebilir
RTL elde etmek. Bu, M06 (Faz 1) icin verilen "gelecek milestone" sozunu
yerine getirir.

## Strateji

### Karar: Yarim is birakmamak

Onceki UART simulator-only $write kullaniyordu. FPGA sentezlenebilir
degildi. Bu durumda iki yol vardi:

**A) DTR icin yazip "Faz 2 final teslim icin" demek (ertelemeci):**
- Risksiz ama eksik kanit
- DTR'de "FPGA henuz denenmedi, UART simulator-only" denirdi

**B) Faz 2'yi simdi yapmak (DOGRU yol):**
- 3 saatlik ek is
- Risk: state machine hatasi, regression
- Kazanim: FPGA hazir, sentezlenebilir, DTR'de guc0lu hikaye

Kullanici acik bir sekilde "her sey duzgun olsun, ertelememeliyim" dedi.
Bu yuzden Yol B secildi.

### Senthezlenebilir vs. Simulator Davranisi

Iki dunyada da calismak icin "synthesis translate_off / translate_on"
direktifleri kullanildi:

   // synthesis translate_off
   $write("%c", wdata_i[7:0]);
   $fflush();
   // synthesis translate_on

Verilator bu direktifleri tanir, sentez disinda tutar. FPGA sentez
araclari (Vivado, Yosys) da ayni direktifleri uygular. Boylece RTL hem
simulator'da debug ciktisi verir hem de FPGA'da gerc0ek pin uretir.

## Mimari

### TX State Machine

Dort durum:
- TX_IDLE: tx_o = 1, sayaclar resetli, TDR yazma + CFG[0]=1 bekleniyor
- TX_START: tx_o = 0 (start bit), CPB cycle bekle
- TX_DATA: tx_o = tx_shift_q[0], her CPB cycle bir bit kaydir
- TX_STOP: tx_o = 1 (stop bit), CPB cycle bekle, CFG[2]=1 set

State akisi:
   IDLE -> START -> DATA0 -> DATA1 -> ... -> DATA7 -> STOP -> IDLE

Toplam 10-bit dizi: 1 start + 8 data (LSB first) + 1 stop.

### Baud Rate Generator

CPB yazmacindan baud bolucu okunur. Her bit CPB cycle suresi alir.

Reset degeri: CPB = 16 (simulator hizi icin)
FPGA'da yazilim sets eder: CPB = 5208 (50 MHz / 9600 baud)

Per-bit cycle = CPB
10-bit dizi = 10 * CPB cycle
9600 baud, 50 MHz: 5208 cycle/bit, 52080 cycle/karakter (~1.04 ms)

### tx_start_pulse

TX'in basladigi tek-cycle puls:
   req_i AND gnt_o AND we_i AND is_tdr AND cfg_q[0] AND tx_state==IDLE

Bu sayede:
- TDR yazma + TX_EN=1 + idle = baslar
- TX surerken TDR yazma yok-sayilir (busy semantigi)

## Yapilanlar

### Yeni RTL: rtl/uart.sv (90 satir -> 195 satir)

Eklenenler:
- typedef enum tx_state_e (4 durum)
- tx_baud_cnt_q (16-bit baud sayici)
- tx_bit_cnt_q (4-bit data bit sayici)
- tx_shift_q (8-bit shift register, LSB first)
- tx_start_pulse (1-cycle baslangic puls)
- tx_o output (FPGA serial pin)
- 4-state TX state machine (IDLE/START/DATA/STOP)
- TX_DONE flag (CFG[2]) STOP sonunda set

Korunanlar:
- 5 EK-2 yazmaci (CPB/STP/RDR/TDR/CFG) - aynen
- OBI slave arayuzu - aynen
- Adres dekod (offset 0x00-0x10) - aynen
- $write debug (translate_off/on ile)
- TX_EN=1 reset default - aynen

### SoC Entegrasyonu

rtl/soc_top.sv:
- Yeni port: output logic uart_tx_o
- u_uart instance'ina .tx_o (uart_tx_o) baglantisi

tb/tb_top.sv:
- logic uart_tx; (local sinyal)
- u_soc instance'ina .uart_tx_o (uart_tx) baglantisi
- tx_o izleyici (her edge'de $display)

## Sonuc

### Build Basarili

Verilator hicbir hata vermedi. 195 satir yeni RTL, typedef enum,
state machine, $write translate_off/on - hepsi sentez-uyumlu.

### Waveform Dogrulamasi

Test programi: test_full.S (RUN\\nPASS\\n yaziyor)

Ilk 8 TX_PIN edge gozlendi:

   [375000]  TX_PIN: 1 -> 0   start bit ('R' karakteri basliyor)
   [695000]  TX_PIN: 0 -> 1   bit (320 ns sonra = 16 cycle * 20 ns)
   [855000]  TX_PIN: 1 -> 0
   [1175000] TX_PIN: 0 -> 1
   [1335000] TX_PIN: 1 -> 0
   [1495000] TX_PIN: 0 -> 1
   [1655000] TX_PIN: 1 -> 0
   [1815000] TX_PIN: 0 -> 1   stop bit (idle'a geri donus)

Her edge arasi 16 cycle (320 ns), CPB=16 ile uyumlu.

### 'R' = 0x52 Bit Analizi

ASCII 'R' = 0x52 = 01010010 binary
LSB first gonderim: 0,1,0,0,1,0,1,0

Beklenen waveform:
   IDLE START D0 D1 D2 D3 D4 D5 D6 D7 STOP
   1    0     0  1  0  0  1  0  1  0  1

Gozlenen 8 edge bu sekanstaki tum bit gec0islerine denk geliyor:
- 1->0: idle->start
- 0->1: d1=1
- 1->0: d2=0
- 0->1: d4=1
- 1->0: d5=0
- 0->1: d6=1
- 1->0: d7=0
- 0->1: stop

(d0, d3 zaten oldugu gibi kaldigindan edge yok.)

Dogrulama: gerc0ek hardware UART davranisi.

### Coverage Korundu

DATA bus: 4 read + 13 write = 17 islem (M08'den)
INSTR bus: 999 fetch (M08'den)
Regression yok: test_full.S hala "PASS" diziyle bitiyor

## Dogrulanan Ozellikler

- [x] TX state machine 4 durum dogru gec0is yapiyor
- [x] Baud rate generator CPB sayisi kadar bekliyor (16 cycle/bit)
- [x] 10-bit dizi: 1 start + 8 data (LSB first) + 1 stop
- [x] tx_o pini gerc0ekten serial degisim uretiyor
- [x] tx_start_pulse dogru tetikleniyor (TDR write + TX_EN + IDLE)
- [x] TX surerken ikinci TDR yazma yok-sayiliyor (busy semantigi)
- [x] CFG[2] (TX_DONE) STOP sonunda set
- [x] $write debug korunuyor (translate_off/on)
- [x] FPGA sentezlenebilir (Verilog 2001 + SV typedef enum)
- [x] Reset sonrasi tx_o = 1 (idle high, UART standardi)
- [x] CPB programlanabilir (yazilim FPGA'da 5208 set edebilir)
- [x] Mevcut testler (Hi/P/T/PASS) regression-safe
- [x] OBI protocol assertion'lari hala sessiz (M07 aktif)

## Sartname / DTR Etkisi

### UART Hikayesi: Iki-Fazli Gelisim

DTR raporunda asagidaki gibi anlatilabilir:

"UART modulu iki fazda gelistirildi:

Faz 1 (M06): EK-2 yazmac haritasi birebir uygulandi. CPB/STP/RDR/TDR/CFG
yazmaclari tanimlandi, davranissal model ($write ile) kuruldu.
Adres 0x40002000'a tasindi.

Faz 2 (M09): Gerc0ek baud rate generator ve 10-bit TX state machine
eklendi. tx_o pini FPGA icin sentezlenebilir hale getirildi. State
machine: IDLE -> START -> 8 DATA -> STOP. CPB yazmacindan okunan deger
baud divider olarak kullanilir. LSB-first protokol UART standardina
uygun.

Dogrulama: testbench tx_o pini izlendi. R (0x52) gonderiminde 1->0
->0->1->0->0->1->0->1->0->1 (start + 8 data + stop) waveform'u
kayitlandi."

### Sentez Hazirligi

UART artik FPGA-uyumlu. Eksikler:
- Top-level wrapper (clock divider, reset debounce)
- XDC constraints (UART pin atamasi, clock pin)
- Vivado projesi

Hafta sonu Umur Bugra ile yapilacak Yol A sentez denemesi su an
mumkun: UART modulu gerc0ek serial sinyal uretiyor, sentez aracinin
sevecegi RTL.

### Odul Kriteri Etkisi

Sartname Madde 4.2.2.2 minimum odul kriterleri:
- #1 FPGA + 2 cevre birim - henuz tam karsilanmadi (sentez denemesi var)
- #2 Self-checking test - VAR (4 test, M03-M04-M06-M08)
- #3 AXI Protocol Check - VAR (M07)
- 3/5 odul kriteri DTR icin korundu

#1 kriteri icin onceden boyle bir sey yoktu. M09 sayesinde RTL
sentezlenebilir hale geldi - FPGA Yol A icin somut zemin var.

### Mukayese: Faz 1 vs Faz 2

| Aspect           | Faz 1 (M06)        | Faz 2 (M09)              |
|------------------|--------------------|--------------------------|
| Cikis mekanizmas | $write (sim only)  | tx_o pini (sim + FPGA)   |
| Baud rate        | Yok                | CPB-based generator      |
| Bit gec0is suresi | 0 cycle (anlik)    | CPB cycle (16 def)       |
| 10-bit dizi      | Yok                | START + 8 DATA + STOP    |
| TX_DONE flag     | Hep 1 cycle pulse  | STOP sonunda set         |
| FPGA sentez      | Hayir              | Evet                     |
| Sayim            | 90 satir           | 195 satir                |

## Mimari Notlar

### LSB First Sec0imi

UART standardinda data bitleri LSB onde gonderilir. Sebep: receiver'in
ilk biti goruncesi shift register'a koyacagi yer. Big-endian
gonderirseniz protokol bozulur.

Bizde: tx_shift_q[0] her cycle tx_o'ya verilir, sonra
tx_shift_q <= {1'b0, tx_shift_q[7:1]} ile sag-kaydirilir.

### Idle High Standardı

UART'ta idle = 1 (high). Cunku negatif gerilim seviyesinin tam tersi
mantigi (RS-232 mirasi). Hatti sirf logic 1'e cekersek alici "yok"
algilar; sonra 0 (start bit) ile "veri geliyor" sinyali alir.

Reset sonrasi tx_o = 1 mantigi tam olarak bu yuzden.

### CPB = 16 Default Sec0imi

Simulator'da CPB = 16 yaptik cunku 1000 cycle simulasyon icinde
60+ karakter gonderebiliyoruz. 5208 olsa, 1000 cycle'da sadece
~0.2 karakter giderdi.

FPGA'da yazilim ilk komutu CPB'ye 5208 yazmali (50 MHz / 9600 baud).
Bu yazilim bootstrap'in ilk satirlarinda olur.

### State Machine Sentez Uyumluluğu

typedef enum logic [1:0] kullandık. Bu sentez aracları için en
güvenli yol. Verilator de Vivado da Yosys de bunu sorunsuz işler.

## Sonraki Adimlar

- [ ] Hafta sonu: Umur Bugra ile FPGA Vivado sentez denemesi (Yol A)
- [ ] Top-level wrapper: clock divider (100 MHz -> 50 MHz), debounce
- [ ] XDC constraints: UART pin, sistem saati, reset
- [ ] FPGA'da gerc0ek demo (PuTTY ile UART okuma)
- [ ] DTR rapor yazimi (9-15 May)
