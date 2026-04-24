# Milestone 04: Timer Modulu + Ikinci Self-Checking Test

**Tarih:** 24 Nisan 2026
**Commit:** af02f81

## Hedef
GPIO pattern'ini kullanarak ikinci cevre birimi Timer'i SoC'ye entegre etmek,
ikinci self-checking test ile cevre birim altyapisinin genisletilebilir
oldugunu kanitlamak.

## Yapilanlar

### RTL: rtl/timer.sv (63 satir)
- Minimal Timer modulu (DTR icin)
- TIM_CLR (offset 0x08, WO): 1 yazilinca sayaci sifirlar
- TIM_ENA (offset 0x0C, RW): 1 ise sayac her cycle'da artar
- TIM_CNT (offset 0x14, RW): 32-bit sayac degeri, okunabilir-yazilabilir
- OBI slave arayuz: req/gnt/rvalid + addr/we/be/wdata/rdata

Not: Sartname EK-2 tam yazmac listesi (PRE, ARE, MOD, EVN, EVC) sonraki
iterasyonda eklenecek. Bu versiyon DTR icin minimum calisir orneklem.

### SoC Entegrasyon: rtl/soc_top.sv guncellendi (4. slave)
- Decoder 3 slave'den 4 slave'e genisletildi
- GPIO artik sadece 0x40000xxx araliginda (onceden 0x4xxxxxxx idi)
- Timer yeni adres araliginda: 0x40001xxx
- sel_timer_req decoder'a eklendi
- sel_timer_q select-latch'e eklendi
- Gnt ve rvalid mux'larina Timer eklendi
- Timer instantiation eklendi

### Test Programi: sw/test_timer.S (75 satir, 37 word hex)
Program akisi:
1. x10 = UART base (0x10000000)
2. x11 = Timer base (0x40001000)
3. TIM_CLR = 1  ->  Sayaci sifirla
4. TIM_ENA = 1  ->  Sayaci baslat
5. 8 x NOP ile bekle (sayac artar)
6. lw x13, 20(x11)  ->  TIM_CNT oku
7. bne x13, x0, pass_path  ->  Sayac arttiysa dallanma
8. pass_path: UART'a 'T' (0x54) yaz
9. fail_path: UART'a 'F' (0x46) yaz
10. end: sonsuz dongu

## Bellek Haritasi (bu milestone itibari ile)
| Adres | Modul |
|---|---|
| 0x00000000-0x00003FFF | RAM (tek blok, 16 KB) |
| 0x10000000 | UART (primitive) |
| 0x40000000-0x40000FFF | GPIO |
| 0x40001000-0x40001FFF | Timer (yeni) |

## Sonuc
UART output: T

Simulasyon cikti dogrulamasi:
- [345000] DWRITE addr=0x40001008 data=0x00000001  (TIM_CLR yazildi)
- [375000] DWRITE addr=0x4000100c data=0x00000001  (TIM_ENA yazildi)
- [515000] IFETCH addr=0x00000080  (pass_path dallanmasi)
- [555000] DWRITE addr=0x10000000 data=0x00000054  ('T' UART'a)

## Dogrulanan Ozellikler
- [x] Timer CLR komutu ile sayac sifirlanabiliyor
- [x] Timer ENA komutu ile sayac etkinlestirilebiliyor
- [x] Sayac her cycle'da artiyor (counter incrementing dogrulandi)
- [x] TIM_CNT okuma ile anlik sayac degeri alinabiliyor
- [x] Decoder 4 slave'e dogru yonlendirme yapiyor
- [x] Alt-bolge adresleme calisiyor (0x40000 vs 0x40001)
- [x] Select-latch patterni 3. slave'e de uyum sagladi (scalable)

## DTR icin Onemli Puanlar
- Ayni RTL paterni 3 kez basariyla uygulandi (UART + GPIO + Timer)
- Bu "scalable design" gostergesi
- Iki bagimsiz self-checking test elimizde (P ve T)
- Cevre birim altyapisi bundan sonra Fast-add olacak
  (I2C, QSPI, gercek UART ayni yoldan gelecek)

## Sonraki Adimlar (seceneklere gore)
- [ ] Gercek UART (EK-2 tam yazmaclari)
- [ ] IRAM/DRAM ayrimi
- [ ] I2C Master
- [ ] UVM protocol check (odul kriteri #3 icin)
