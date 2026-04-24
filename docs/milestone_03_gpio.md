# Milestone 03: GPIO Modulu + Ilk Self-Checking Test

**Tarih:** 24 Nisan 2026
**Commit:** 1aa0ab5

## Hedef
Sartname EK-2 uyumlu ilk cevre birim modulunu (GPIO) SoC'ye entegre etmek
ve ilk self-checking testi uygulamak.

## Yapilanlar

### RTL: rtl/gpio.sv (76 satir)
- Sartname EK-2 uyumlu GPIO modulu
- 16 giris pini (GPIO_IDR, RO, offset 0x00)
- 16 cikis pini (GPIO_ODR, RW, offset 0x04)
- Byte-enable ile yazma destegi
- OBI slave arayuz: req/gnt/rvalid + addr/we/be/wdata/rdata
- Reset ile ODR sifirlanir

### SoC Entegrasyon: rtl/soc_top.sv guncellendi
- Decoder 2 slave'den 3 slave'e genisletildi (UART + GPIO + RAM)
- GPIO icin sel_gpio_req sinyali eklendi
- Select-latch patterni GPIO'ya uygulandi (sel_gpio_q)
- Modul port listesine gpio_in_i ve gpio_out_o eklendi

### Testbench: tb/tb_top.sv guncellendi
- GPIO test pinleri eklendi (gpio_in = 16'h1234, gpio_out gozlemleniyor)
- Debug trace'leri korundu

### Test Programi: sw/test_gpio.S (63 satir, 28 word hex)
Program akisi:
1. x10 = UART base (0x10000000)
2. x11 = GPIO base (0x40000000)
3. x12 = 0xAA (test deseni)
4. sw x12, 4(x11)  ->  GPIO_ODR = 0xAA
5. lw x13, 4(x11)  ->  Geri oku
6. beq x12, x13, pass_path  ->  Esitse dallanma
7. pass_path: UART'a 'P' (0x50) yaz
8. fail_path: UART'a 'F' (0x46) yaz
9. end: sonsuz dongu

## Bellek Haritasi (bu milestone itibari ile)
| Adres | Modul |
|---|---|
| 0x00000000-0x00003FFF | RAM (tek blok, 16 KB) |
| 0x10000000 | UART (primitive) |
| 0x40000000-0x40000FFF | GPIO (yeni) |

## Sonuc
UART output: P

Simulasyon cikti dogrulamasi:
- [345000] DWRITE addr=0x40000004 data=0x000000aa  (GPIO ODR yazildi)
- [405000] IFETCH addr=0x00000058  (pass_path dallanmasi)
- [445000] DWRITE addr=0x10000000 data=0x00000050  ('P' UART'a)

## Dogrulanan Ozellikler
- [x] GPIO ODR yazilabiliyor
- [x] GPIO ODR okunabiliyor (yazilan deger korunuyor)
- [x] Decoder dogru slave'e yonlendiriyor (0x40000000 -> GPIO)
- [x] Select-latch patterni ikinci slave'e genisletilebildi
- [x] RISC-V programi beq ile dogru dallanma yapiyor
- [x] UART basari/basarisizlik raporlayabiliyor

## Sartname Odul Kriteri
Kriter #2 (Self-checking test) ile ilgili:
- Bu test self-checking: simulator kendisi 'P' veya 'F' basar
- Juri RTL log'una bakmak zorunda degil
- Write/read dogrulama + dallanma + sonuc bildirimi

## DTR'ye Katki
- Ikinci cevre birim modul pattern ornegi
- Ilk self-checking test ornegi
- Assembly test programi sablonu (UART rapor mekanizmasi)
- Decoder genisletme pratigi (3 slave)

## Sonraki Adim
Timer modulu (ayni pattern) + ikinci self-check test
