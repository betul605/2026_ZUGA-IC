# Milestone 08: Comprehensive Test (test_full.S)

**Tarih:** 27 Nisan 2026
**Commit:** cfbfa5d

## Hedef

DTR raporu icin somut coverage metrikleri uretmek. Tek bir test
programinda tum modullere (UART, GPIO, Timer) erisim, hem read hem
write isleminin yapilmasi, conditional flow (beq/bne) ile self-check
yapilmasi.

Onceki testler her biri tek modul/yazmac odakliydi:
- hello.S: 3 UART yazma (smoke)
- test_gpio.S: 1 GPIO write/read + 2 UART
- test_timer.S: 2 Timer write + 1 Timer read + 2 UART

Yeni test_full.S: 4 modul, 5 yazmac, 17 bus islemi.

## Strateji

### Neden ayri test, mevcut testlerle integre etme?

Mevcut testler (hello, test_gpio, test_timer) kendi senaryolarinda
basit ve tek odakli kalir. Yeni test_full.S onlardan ayri tutuldu cunku:
- Onceki testleri bozmama (regression-safe)
- Comprehensive senaryoyu ayri raporlama
- Build.sh ile tek-test-yukle-koş yaklasimini koruyor

build.sh artik default olarak test_full.hex yukluyor. Diger testler
isteyen kullanici tarafindan manuel yuklenebilir (sed komutu ile).

### Kapsam

Tek bir self-checking program iceriginde:
1. UART'a "RUN\\n" yaz (smoke kontrol)
2. GPIO'ya 0x55 yaz, oku, beq ile karsilastir
3. GPIO'ya 0xAA yaz, oku, beq ile karsilastir (ikinci pattern)
4. Timer CLR + ENA, sayac calistirma, CNT oku, sifirsa fail
5. UART_CFG oku (read coverage genisletme)
6. Hepsi gec0erse "PASS\\n", herhangi biri kalirsa "FAIL\\n"

Bu yapi DTR raporunda "doğrulama metodolojisi" basliginin altinda
guzel bir akis diyagrami olur.

## Yapilanlar

### Yeni Dosya: sw/test_full.S (137 satir, 85 instruction)

Dosya yapisi:
- _start: pipeline isinma + base adres yukleme (lui x10/x11/x12)
- 6 numarali bolum: UART smoke, GPIO 0x55, GPIO 0xAA, Timer, UART_CFG, PASS/FAIL
- pass_path: "PASS\\n" yazdir, end'e dal
- fail_path: "FAIL\\n" yazdir
- end: jal x0, end (sonsuz dongu)

Kullanilan registerlar:
- x10: UART base (0x40002000)
- x11: GPIO base (0x40000000)
- x12: Timer base (0x40001000)
- x13: yazilan deger (0x55, 0xAA, 1)
- x14: okunan deger / karakter
- x15: UART_CFG yedek

### Build Akisi

test_full.S derleme:
- riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -nostartfiles -nostdlib
- riscv-none-elf-objcopy -O binary
- python3 ile word-by-word hex donusumu (4-byte little-endian)
- Sonuc: 85 word hex dosyasi

build.sh guncellendi: cp sw/test_full.hex hello.hex

## Sonuc

Build basarili. Simulasyon ciktisi (DWRITE filtreli):

[355000]  0x4000200c  data=0x52    'R'  (RUN basla)
[385000]  0x4000200c  data=0x55    'U'
[415000]  0x4000200c  data=0x4e    'N'
[445000]  0x4000200c  data=0x0a    '\\n'
[475000]  0x40000004  data=0x55    GPIO 0x55 yaz (sonra okundu, gec0ti)
[555000]  0x40000004  data=0xaa    GPIO 0xAA yaz (sonra okundu, gec0ti)
[635000]  0x40001008  data=0x01    TIM_CLR
[665000]  0x4000100c  data=0x01    TIM_ENA
[815000]  0x4000200c  data=0x50    'P'  (PASS basla!)
[845000]  0x4000200c  data=0x41    'A'
[875000]  0x4000200c  data=0x53    'S'
[905000]  0x4000200c  data=0x53    'S'
[935000]  0x4000200c  data=0x0a    '\\n'

Tum testler basarili: PASS yazildi (FAIL'e dallanma yok).

### Coverage Karsilastirma Tablosu

| Test     | DATA Read | DATA Write | DATA Total | INSTR |
|----------|-----------|------------|------------|-------|
| hello    | 0         | 3          | 3          | ~10   |
| test_gpio| 1         | 4          | 5          | ~30   |
| test_timer| 1        | 4          | 5          | ~50   |
| test_full| 4         | 13         | 17         | 999   |

3.4x DATA bus aktivite artisi (5 -> 17 islem).

### Kapsanan Modul / Yazmac Matrisi

| Modul | Yazmac | Read | Write |
|-------|--------|------|-------|
| UART  | TDR    | -    | 9     |
| UART  | CFG    | 1    | -     |
| GPIO  | ODR    | 2    | 2     |
| Timer | CLR    | -    | 1     |
| Timer | ENA    | -    | 1     |
| Timer | CNT    | 1    | -     |
| Toplam|        | 4    | 13    |

3 modul, 6 farkli yazmac, hem read hem write. Bu DTR raporunda
"doğrulama matrisi" tablosu olarak kullanilabilir.

## Dogrulanan Ozellikler

- [x] Bus decoder 3 farkli modulu dogru yonlendiriyor
- [x] UART_TDR (offset 0x0C) yazma akisi calisir
- [x] UART_CFG (offset 0x10) okuma akisi calisir (read coverage)
- [x] GPIO_ODR (offset 0x04) hem write hem read dogru
- [x] Timer CLR (offset 0x08) ve ENA (offset 0x0C) yazma calisir
- [x] Timer CNT (offset 0x14) okuma calisir, sayac gercekten artar
- [x] Conditional flow (beq, bne) dogru calisiyor
- [x] Self-checking PASS/FAIL ayrimi calisiyor
- [x] Tum 3 onceki test (Hi, P, T) regression-safe (manuel build ile)
- [x] OBI protocol assertion'lari sessiz kaldi (M07 hala aktif)

## Sartname / DTR Etkisi

### Doğrulama Metodolojisi Olarak

DTR raporunda "doğrulama yaklasimimiz" basliginda asagidaki anlatilabilir:

"Sistem 4 farkli test programi ile doğrulanmistir:
- Smoke testi (hello.S)
- Modul-bazli testler (test_gpio.S, test_timer.S)
- Comprehensive sistem testi (test_full.S)

Comprehensive test 17 bus islemi ile 3 cevre birim modulunu kapsar
ve hem read hem write islemini hem conditional flow'u dogrular.
PASS/FAIL ciktisi sayesinde otomatik dogrulama saglanir."

### Coverage Metrikleri

DTR'de "doğrulama metrikleri" basliginda direkt sunum icin:

| Metrik | Deger |
|--------|-------|
| Bagimsiz test programi sayisi | 4 |
| Modul kapsami | 3/3 (UART, GPIO, Timer) |
| Yazmac kapsami | 6 yazmac |
| DATA bus okuma sayisi | 4 |
| DATA bus yazma sayisi | 13 |
| INSTR bus fetch sayisi | 999 |
| Toplam DATA bus aktivitesi | 17 islem |
| OBI protocol assertion FAIL sayisi | 0 |
| Self-checking PASS oranı | 100% |

### Onceki Milestone'larla Sinerji

- M02 (Modular SoC) ile: Decoder dogru calisiyor (3 modul yonlendirme)
- M04 (Timer) ile: Sayac gerc0ekten artiyor
- M06 (EK-2 UART) ile: TDR/CFG yazmaclari calisir
- M07 (SVA Protocol Check) ile: Tum bu islemlerde 0 ASSERT FAIL

### Odul Kriteri Etkisi

Sartname Madde 4.2.2.2 minimum odul kriterleri:
- #2 Self-checking test: ARTIK 4 TEST (onceden 3, kalite arttı)
- #3 AXI Protocol Check: M07 ile karsilanmiş (degisiklik yok)
- 3/5 odul kriteri DTR icin karsilanmaya devam ediyor

## Mimari Notlar

### Tek Test, Coklu Modul

test_full.S tek bir program akisi icinde 3 modul kullanir. Bu DTR'de
"sistem-seviyesi doğrulama" olarak sunulabilir; UVM testbench'sinde
de benzer bir akis olur (sequence ile sirayla agentlere komut gonderme).

### Build.sh Default Test

build.sh artik test_full.hex'i default olarak yukluyor. Diger testler
(hello, test_gpio, test_timer) regression icin manuel sed komutu ile
secilebilir. Ileride build.sh parametreli yapilabilir
(./build.sh test_gpio gibi).

### Conditional Flow Dogrulamasi

beq ve bne komutlari programi pass_path veya fail_path'e dallar.
Bu CV32E40P core'unun branch unit'inin calistigini da dogrular.
Onceki testlerde sadece lineer akis vardi; bu test ilk kez branch
kullaniyor.

## Sonraki Adimlar

- [ ] Hafta sonu: Umur Bugra ile FPGA Vivado sentez denemesi (Yol A)
- [ ] UART Faz 2: Gerc0ek baud rate generator + 10-bit TX state machine
- [ ] DTR rapor yazimi (9-15 May)
- [ ] YZ hizlandirici (final teslim icin, DTR sonrasi)
