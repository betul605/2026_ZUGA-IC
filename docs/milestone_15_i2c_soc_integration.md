# Milestone 15: I2C SoC Entegrasyonu

**Tarih:** 28 Nisan 2026
**Commit:** 0203888
**Bagimli:** M14 (I2C Master Faz 1)

## Hedef

M14'te bagimsiz olarak yazilan ve dogrulanan I2C Master modulunu
(rtl/i2c_master.sv, 246 satir) SoC'ye 6. slave olarak entegre etmek.
Bellek haritasinda 0x40004000 adresine yerlestirmek. Mevcut UART/GPIO/
Timer testlerinde regression yapmamak. test_full.S programina I2C
blogu ekleyip DATA bus coverage'i artirmak.

## Strateji

### Iki Faz Yaklasim (Yarim Is Birakmama)

ONTR'de I2C Master vaat edilmisti. M14'te bagimsiz dogrulama yapildi
(22 SCL/SDA edge), ama o noktada SoC'ye dahil degildi -- yarim is.
M15 bu eksikligi kapatiyor: SoC entegrasyonu + test programi guncelleme
+ regression dogrulamasi.

Bu strateji DTR raporunda 'I2C iki fazli gelisim' olarak anlatilir:
1. Faz 1 (M14): RTL + bagimsiz testbench
2. Faz 2 (M15): SoC entegrasyonu + sistem testi

### Adres Haritasi Genisletme

Mevcut decoder addr[13] ve addr[12] biti ile 4 slave ayiriyordu:
- 0x40000xxx GPIO (addr[13]=0, addr[12]=0)
- 0x40001xxx Timer (addr[13]=0, addr[12]=1)
- 0x40002xxx UART (addr[13]=1, addr[12]=0)

I2C @ 0x40004000 icin addr[14] biti devreye girdi:
- 0x40004xxx I2C (addr[14]=1)
- Mevcut wire'lara addr[14]=0 sarti eklendi (cakisma onleme)

## Yapilanlar

### 1. rtl/soc_top.sv (10 yerde guncelleme)

Tek Python script ile atomik 10 degisiklik (10/10 OK, 0 hata):

1. Module port listesi: 4 yeni I2C cikis (i2c_scl_o/oe, i2c_sda_o/oe)
2. Decoder: sel_i2c_req wire eklendi, mevcut wire'lara addr[14]=0
3. sel_ram_req fallback'a sel_i2c_req eklendi
4. Logic sinyaller: i2c_req/gnt/rvalid/rdata
5. assign i2c_req = data_req & sel_i2c_req
6. data_gnt mux'a i2c_gnt eklendi
7. Select latch: sel_i2c_q (3 yerde: declaration, reset, latch)
8. data_rvalid mux'a i2c_rvalid eklendi
9. data_rdata mux'a i2c_rdata eklendi
10. I2C Master instance (UART'tan sonra, GPIO'dan once)

Boyut: 9598 -> 11023 byte (+1425, mantikli)

### 2. tb/tb_top.sv

soc_top'un yeni 4 portu icin local sinyaller declare edildi ve
instance'a baglandi:

- logic i2c_scl, i2c_scl_oe;
- logic i2c_sda, i2c_sda_oe;

### 3. rtl/fpga_top.sv

Module port listesine 2 yeni FPGA pin (i2c_scl, i2c_sda).
Open-drain mantigi (Verilator-uyumlu, tristate yok):

  assign i2c_scl = ~i2c_scl_oe_int;
  assign i2c_sda = ~i2c_sda_oe_int;

soc_top instance'ina 4 I2C portu baglandi.

### 4. constraints/arty_a7.xdc

I2C pinleri PMOD JD'ye atandi:
- i2c_scl -> D3 (JD1)
- i2c_sda -> D4 (JD0)

Not: Arty PMOD'da pull-up direnci yok; harici pull-up gerekir
(gerc0ek I2C cihazi baglandiginda).

### 5. build.sh

RTL dosya listesine i2c_master.sv eklendi (soc_top'tan once,
dependency sirasi).

### 6. sw/test_full.S

Timer testinden sonra, pass_path'tan once 17 satirlik I2C blogu
eklendi. lui x16, 0x40004 ile I2C base, sonra PRER/CTR/TXR/CMR'a
yazma. CV32E40P RV32I formatinda (sadece lui+addi+sw, no pseudo).

Boyut: 3570 -> 4227 byte

## Toolchain Dogrulamasi (Kritik Adim)

test_full.S'i yeniden derlemeden once toolchain'in calistigi dogrulandi.
Yontem: hello.S'i yeniden derle, MD5'i orijinal hello.hex ile karsilastir.

Komut zinciri:

  riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -static
      -Wl,-Ttext=0x00 -o hello_test.elf hello.S
  riscv-none-elf-objcopy -O binary hello_test.elf hello_test.bin
  od -An -v -t x4 -w4 hello_test.bin | tr -d ' ' | grep -v '^$' >
      hello_test.hex

Onemli flag: 'od -v' (verbose, tekrarlanan satirlari ozetlemez).
Verilator $readmemh formati her satira tam 32-bit hex ister.

Sonuc:

  hello.hex      MD5: 94d58f06a291924207d67281f0170639
  hello_test.hex MD5: 94d58f06a291924207d67281f0170639
  diff: bos cikti (dosyalar bit bit ayni)

Yorum: Toolchain 13.2.0-2 dogru calisiyor. test_full.S icin ayni
zinciri kullanilabilir.

## Test Programi Yeniden Derleme

test_full.S 17 yeni satirlik I2C blogu ile 4227 byte oldu (ekleme
657 byte). Yeniden derleme:

  Eski test_full.hex: 85 word, MD5: 4e6daf0fd4966d7c1a142572ba9c06db
  Yeni test_full.hex: 100 word, MD5: 32f16606f80c1a945ed14b2f8b77e576

15 yeni word eklendi:
- 4 lui/addi/sw (PRER/CTR/TXR/CMR yazma) = 12 word
- 3 nop = 3 word

Yedek dosyalar (.gitignore tarafindan ignore edilir):
- sw/test_full.S.bak (orijinal kaynak)
- sw/test_full.hex.bak (orijinal hex)

## Simulasyon Sonuclari

Build basarili (Verilator hatasiz). sim_cv32 calistirildi:

### DWRITE Aktivitesi (toplam 17 yazma)

| Cycle  | Adres       | Data    | Modul        |
|--------|-------------|---------|--------------|
| 355000 | 0x4000200c  | 0x52    | UART 'R'     |
| 385000 | 0x4000200c  | 0x55    | UART 'U'     |
| 415000 | 0x4000200c  | 0x4E    | UART 'N'     |
| 445000 | 0x4000200c  | 0x0A    | UART '\n'    |
| 475000 | 0x40000004  | 0x55    | GPIO 0x55    |
| 555000 | 0x40000004  | 0xAA    | GPIO 0xAA    |
| 635000 | 0x40001008  | 0x01    | TIM_CLR      |
| 665000 | 0x4000100c  | 0x01    | TIM_ENA      |
| 825000 | 0x40004000  | 0x04    | I2C PRER     |
| 855000 | 0x40004004  | 0x01    | I2C CTR      |
| 885000 | 0x40004008  | 0xA5    | I2C TXR      |
| 915000 | 0x40004010  | 0x90    | I2C CMR      |
| 965000 | 0x4000200c  | 0x50    | UART 'P'     |
| 995000 | 0x4000200c  | 0x41    | UART 'A'     |
|1025000 | 0x4000200c  | 0x53    | UART 'S'     |
|1055000 | 0x4000200c  | 0x53    | UART 'S'     |
|1085000 | 0x4000200c  | 0x0A    | UART '\n'    |

### Coverage

| Metrik         | Eski (M08) | Yeni (M15) | Artis |
|----------------|------------|------------|-------|
| DATA okuma     | 4          | 4          | 0     |
| DATA yazma     | 13         | 17         | +4    |
| DATA toplam    | 17         | 21         | +4    |
| INSTR fetch    | 999        | 999        | 0     |
| ASSERT FAIL    | 0          | 0          | 0     |

Yorum: I2C blogu 4 yeni DWRITE ekledi (PRER/CTR/TXR/CMR), regression
yok. UART RUN/PASS dizisi hala gec0iyor, GPIO 0x55/0xAA pattern hala
dogru, Timer hala calisiyor.

### I2C Transaction Tetiklendi

CMR yazma (0x40004010 = 0x90) cycle 915000'de gerc0eklesti. Bu I2C
Master state machine'i I2C_IDLE'dan I2C_START'a gec0irdi. M14'te
bagimsiz testbench'te dogrulandigi gibi, START + 8 data bit (MSB
first 0xA5 = 10100101) + ACK slot + STOP urertilecekti.

Ana SoC simulasyonunda I2C edge gozlemcisi yok (tb_top'ta UART tx_o
izleyicisi var ama I2C scl_oe/sda_oe icin yok). Faz 3'te eklenebilir.
M14 bagimsiz testbench bu kanit icin yeterli.

## Sartname / DTR Etkisi

### Cevre Birim Sayisi (Madde 4.2.2.2 #1)

Sartname minimum odul kriteri #1: 'FPGA + 2 cevre birim'.

DTR donemi sonu cevre birim sayisi:

| # | Modul    | Adres        | Test               |
|---|----------|--------------|--------------------|
| 1 | GPIO     | 0x40000000   | 'P' (M03) + 0x55/0xAA pattern |
| 2 | Timer    | 0x40001000   | 'T' (M04) + sayac kontrol |
| 3 | UART     | 0x40002000   | RUN/PASS yazma + tx_o pin |
| 4 | I2C      | 0x40004000   | PRER/CTR/TXR/CMR yazma |

4 cevre birim ile sartname kriterinin **2 kati** karsilanmis durumda.

### Coverage Metrikleri (Madde 4.2.2.2 #2)

Self-checking test 4 program (hello, gpio, timer, full). M15'ten
sonra test_full.S 4 yeni I2C islemi ekledi:

- DATA writes 13 -> 17 (1.31x artis)
- DATA total 17 -> 21 (1.24x artis)
- 4 modul -> 4 modul (kapsam ayni, derinlik artti)

Toplam M01'den M15'e DATA aktivitesi:
- hello: 3 islem
- test_gpio: 5 islem
- test_timer: 5 islem
- test_full (M08): 17 islem
- test_full (M15): **21 islem** (M08'e gore +4)

### DTR Anlatim Hikayesi

DTR raporunda M14 + M15 birlikte 'I2C iki fazli gelisim' olarak
anlatilir:

  'I2C Master modulu iki fazli gelistirildi. Faz 1 (M14): 246 satir
   sentezlenebilir SystemVerilog -- 6 EK yazmac (PRER/CTR/TXR/RXR/
   CMR/SR), 5-state machine (IDLE/START/BIT/STOP/DONE), prescaler-
   based clock generation. Bagimsiz testbench ile 22 SCL/SDA edge
   gozlendi: START + 8 data bit (MSB first 0xA5) + ACK slot + STOP.

   Faz 2 (M15): SoC'ye 6. slave olarak entegre edildi (0x40004000
   adres). soc_top.sv'de 10 yerde guncelleme (decoder + select latch
   + gnt/rvalid/rdata mux + instance + 4 yeni dis port). fpga_top.sv
   ve constraints/arty_a7.xdc'de I2C pinleri (D3/D4 PMOD JD)
   eklendi. Open-drain mantigi Verilator-uyumlu sekilde yazildi
   (tristate yerine NOT mantik).

   Test programi (test_full.S) guncellendi: I2C blogu eklendi.
   Toolchain (xpack-riscv-none-elf-gcc 13.2.0-2) dogrulandi (hello.S
   MD5 birebir tutuyor). Yeniden derleme sonrasi DATA writes 13 -> 17
   oldu, mevcut UART/GPIO/Timer testleri regression vermedi, PASS
   yazildi, 0 ASSERT FAIL.'

## Mukayese: M14 vs M15

| Aspect              | M14 (Bagimsiz)        | M15 (SoC Entegre)        |
|---------------------|-----------------------|--------------------------|
| RTL satir           | 246                   | 246 (degismedi)          |
| Testbench           | i2c_master_tb.sv (124)| tb_top.sv (genisletildi) |
| Build script        | build_i2c.sh          | build.sh (RTL listede)   |
| Adres alanı         | 0x00000000 (tb)       | 0x40004000 (SoC)         |
| Tetikleyici         | obi_write task        | sw/test_full.S kodu      |
| SCL/SDA gozlemi     | 22 edge               | M14 dogrulamasi yeterli  |
| DATA writes         | 4 (PRER/CTR/TXR/CMR)  | 4 (ayni, SoC uzerinden)  |
| Regression riski    | Yok (bagimsiz)        | Test edildi, yok         |
| FPGA hazirligi      | Yok (sentez disinda)  | Var (D3/D4 pin atamasi)  |

## Mimari Notlar

### Open-Drain Verilator Uyumluluk

Gerc0ek I2C tristate gerektirir (sda = 1'bz when idle, slave veya
pull-up tarafindan high cekilir). Verilator tristate desteğini
sinirli sunuyor. Mantiksal aliyim:

  i2c_master.sv'de:
    sda_oe = 1 -> SDA cek (low)
    sda_oe = 0 -> SDA serbest (high-Z dis dunyada)

  fpga_top.sv'de:
    assign i2c_sda = ~i2c_sda_oe_int;
    (oe=1 -> 0, oe=0 -> 1; pull-up varsayim)

Bu Vivado sentezde de calisir. Gerc0ek HW'de harici pull-up direnci
(2.2k - 10k) gerekir. Faz 3'te tristate (inout) eklenebilir, MMCM
ile birlikte.

### Adres Decoder Genisletme

Decoder kararsizligi olmamasi icin tum mevcut wire'lara addr[14]=0
sarti eklendi. Yoksa I2C @ 0x40004000 adresine yazma yapildiginda
iki slave (UART veya GPIO + I2C) ayni anda secilir, multi-driver
hatasi olur.

Mantik:
  GPIO  : addr[14]=0, addr[13]=0, addr[12]=0
  Timer : addr[14]=0, addr[13]=0, addr[12]=1
  UART  : addr[14]=0, addr[13]=1, addr[12]=0
  I2C   : addr[14]=1 (digerlerinden bagimsiz)

## Dogrulanan Ozellikler

- [x] soc_top.sv 10 yerde tutarli guncelleme (Python ile, 10/10 OK)
- [x] tb_top.sv I2C local sinyaller + instance baglanti
- [x] fpga_top.sv I2C pinler + open-drain mantigi
- [x] arty_a7.xdc D3/D4 pin atamasi (PMOD JD)
- [x] build.sh i2c_master.sv RTL listede
- [x] sw/test_full.S I2C blogu eklendi (17 satir)
- [x] Toolchain MD5 dogrulamasi (hello.hex 94d58f06...)
- [x] sw/test_full.hex yeniden derleme (85 -> 100 word)
- [x] Build basarili (Verilator hatasiz)
- [x] Sim PASS (RUN, GPIO, Timer, I2C, PASS dizisi)
- [x] Regression yok (eski testler hala calisir)
- [x] DATA coverage 17 -> 21 (1.24x artis)
- [x] 0 ASSERT FAIL (1000 cycle simulasyon)

## Sonraki Adimlar

- [ ] Hafta sonu (3-4 May): Umur Bugra ile FPGA Vivado sentez
       (Yol A: sadece sentez, kaynak kullanim raporu)
- [ ] Faz 3 (final teslim icin): tristate (inout) I2C portlari
- [ ] Faz 3: MMCM clock manager (su an /2 divider)
- [ ] Faz 3: I2C ACK kontrolu + RD operasyonu (su an WR only)
- [ ] Faz 3: tb_top'a I2C scl_oe/sda_oe edge gozlemcisi
- [ ] DTR rapor yazimi (9-15 May, sablon hazir)
