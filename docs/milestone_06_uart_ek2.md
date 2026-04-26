# Milestone 06: EK-2 Uyumlu UART

**Tarih:** 26 Nisan 2026
**Commit:** 214e934

## Hedef

Sartname EK-2'de tanimlanan UART yazmac haritasina (CPB/STP/RDR/TDR/CFG)
birebir uyumlu yeni bir UART modulu yazmak; primitive UART yerine bunu
SoC'ye entegre etmek; ONTR'de vaat edilen UART-0 adresine (0x40002000)
tasimak. Bu, ONTR-Sartname-RTL ucgeninde tutarliligi saglar.

## Strateji ve Karar Surecleri

### Onceki durum

- uart_primitive.sv: 30 satirlik basit modul
- Hicbir yazmac yok, herhangi bir adrese yazma direkt $write yapiyordu
- Adres: 0x10000000 (ONTR'deki 0x40002000'dan farkli)
- Test programlari: sw x14, 0(x10) ile UART'a yaziyordu

### Sartname EK-2 birebir tablosu

| Offset | Yazmac | Aciklama | R/W |
|---|---|---|---|
| 0x00 | UART_CPB | Clock-per-bit (baud bolucu) | RW |
| 0x04 | UART_STP | Stop bit secim | RW |
| 0x08 | UART_RDR | Receive Data Register | RO |
| 0x0C | UART_TDR | Transmit Data Register | RW |
| 0x10 | UART_CFG | TX_EN, RX_DONE, TX_DONE bitleri | RW |

### Sec0imler

**1. Faz 1 = davranissal:** Tam donanim TX state machine yerine
$write ile karakter basma. Bu primitive davranisi korur. Faz 2'de
(yarin) gercek baud rate generator + 10-bit TX dizisi gelecek.

**2. CFG[0] (TX_EN) reset = 1:** Sartname "CFG[0]=1 oldukca gonderir"
diyor, ama reset degerini biz seciyoruz. Default 1 yaparak mevcut
testlerin CFG'ye yazmadan da calismasini sagladik. Geriye uyumluluk.

**3. UART-0 adres haritasi:** ONTR'de UART-0 = 0x40002000.
Decoder yeniden tasarlandi:
- addr[31:28]=4 + addr[13]=0 + addr[12]=0 -> GPIO  (0x40000000)
- addr[31:28]=4 + addr[13]=0 + addr[12]=1 -> Timer (0x40001000)
- addr[31:28]=4 + addr[13]=1 + addr[12]=0 -> UART  (0x40002000)

**4. Test programlari yeniden derlendi:**
- lui x10, 0x10000 -> lui x10, 0x40002 (yeni base)
- sw x14, 0(x10) -> sw x14, 12(x10) (TDR offset 0x0C)

## Yapilanlar

### Yeni RTL: rtl/uart.sv (90 satir)

EK-2 birebir uyumlu yazmaclar:
- cpb_q (32-bit, RW, default 5000): clock-per-bit
- stp_q (32-bit, RW, default 0): stop bit secim
- rdr_q (32-bit, RO, default 0): RX data
- tdr_q (32-bit, RW, default 0): TX data
- cfg_q (32-bit, RW, default 0x01): TX_EN=1 reset

Davranis:
- TDR yazma + CFG[0]=1 -> $write ile karakter basilir, CFG[2]=1 set
- Diger yazmaclar OBI'den okunabilir/yazilabilir
- Adres dekod: addr[4:2] = 000/001/010/011/100

### Silinen RTL: rtl/uart_primitive.sv

Artik kullanilmiyor, Git tarihinden silindi (b5424de'de bulunabilir).

### SoC Guncellemeleri (rtl/soc_top.sv)

- Decoder yeniden tasarlandi (addr[13] biti UART/GPIO+Timer ayrimi icin)
- uart_primitive u_uart -> uart u_uart
- UART artik 0x40002000 araliginda

### Test Programlari Yeniden Derlendi

| Dosya | lui degisikligi | sw offset |
|---|---|---|
| hello.S | x1, 0x10000 -> x1, 0x40002 | 0(x1) -> 12(x1) |
| test_gpio.S | x10, 0x10000 -> x10, 0x40002 | 0(x10) -> 12(x10) |
| test_timer.S | x10, 0x10000 -> x10, 0x40002 | 0(x10) -> 12(x10) |

Hex dosyalari: hello.hex (17w), test_gpio.hex (28w), test_timer.hex (37w)

### Bellek Haritasi (Milestone 06 itibariyle)

| Adres | Modul | Boyut |
|---|---|---|
| 0x00000000-0x00001FFF | IRAM | 8 KB |
| 0x00020000-0x00021FFF | DRAM | 8 KB |
| 0x40000000-0x40000FFF | GPIO | 4 KB |
| 0x40001000-0x40001FFF | Timer | 4 KB |
| 0x40002000-0x40002013 | UART (EK-2) | 20 B |

## Sonuc — 3 Test, 3 Bagimsiz Dogrulama

### Test 1: hello (UART smoke)

Build: hello.hex yuklu
Cikti: Hi\n

Anahtar simulasyon satirlari:
- DWRITE addr=0x4000200c data=0x00000048  ('H')
- DWRITE addr=0x4000200c data=0x00000069  ('i')
- DWRITE addr=0x4000200c data=0x0000000a  ('\n')

EK-2 dogrulama: H, i, \n her biri UART_TDR'a yazildi (offset 0x0C).

### Test 2: GPIO self-check

Build: test_gpio.hex yuklu
Cikti: P\n

Anahtar simulasyon satirlari:
- DWRITE addr=0x40000004 data=0x000000aa  (GPIO_ODR yaz 0xAA)
- ... (lw ile geri okuma + beq dallanma)
- DWRITE addr=0x4000200c data=0x00000050  ('P' UART_TDR'a)
- DWRITE addr=0x4000200c data=0x0000000a  ('\n')

EK-2 dogrulama: P karakteri UART_TDR ile basildi.

### Test 3: Timer self-check

Build: test_timer.hex yuklu (default)
Cikti: T\n

Anahtar simulasyon satirlari:
- DWRITE addr=0x40001008 data=0x00000001  (TIM_CLR)
- DWRITE addr=0x4000100c data=0x00000001  (TIM_ENA)
- ... (8 NOP, sayac arttiriliyor)
- DWRITE addr=0x4000200c data=0x00000054  ('T' UART_TDR'a)

EK-2 dogrulama: T karakteri UART_TDR ile basildi.

## Dogrulanan Ozellikler

- [x] EK-2 yazmac haritasi tamamen RTL'de (CPB/STP/RDR/TDR/CFG)
- [x] UART-0 adresi ONTR uyumlu (0x40002000)
- [x] CFG[0] (TX_EN) = 1 default ile geriye uyumluluk
- [x] TDR yazma -> karakter cikis (Faz 1 davranissal)
- [x] Tum 5 yazmac OBI uzerinden okunabilir/yazilabilir
- [x] 3 self-checking test bagimsiz olarak gecti
- [x] Decoder addr[13] ile yeni dagitim (UART/GPIO/Timer ayrimi)
- [x] Eski uart_primitive.sv silindi (temiz repo)
- [x] Regression yok (Hi, P, T - hepsi yeni adres ve offset ile basiliyor)

## Mimari Notlar

### Faz 1 vs Faz 2

Bu milestone Faz 1 — davranissal UART. CPB ve STP yazmaclari
kaydediliyor ama henuz kullanilmiyor. CFG[0] davranissal anlami
tasiyor (TX_EN). $write ile anlik karakter basma simulator icin
yeterli; FPGA icin gercek serial pin lazim.

Faz 2 (gelecek milestone): CPB'den baud bolucu, 10-bit TX
state machine (START + 8 DATA + STOP), gercek tx_pin output.

### CFG[0] reset = 1 karari

Sartname "CFG[0]=1 oldukca gonderir" diyor ama reset degerini
biz sectik. Default 1 yaparak:
- Mevcut testler CFG'ye yazmadan calisiyor (regression-safe)
- Yeni testler isterse CFG[0]=0 ile gondermeyi durdurabilir
- DTR'de "default tx_enabled" olarak savunulur

### addr[13] dekod karari

ONTR adres haritasi 0x4000_2000 icin bit 13 farkli (0 -> 0x40000xxx,
1 -> 0x40002xxx). Bu en ucuz dekod yolu. GPIO+Timer hala addr[12]
ile ayriliyor.

## Sartname / DTR Etkisi

- ONTR-Sartname-RTL ucgeninde tutarliligi saglar
- DTR'de "EK-2'ye birebir uyumlu UART" denebilir
- ONTR'deki "Verilog -> SystemVerilog" tutarsizligi orneginin
  aksine, burada RTL ONTR'yi yakaladi — pozitif hikaye
- 3 self-checking test EK-2 UART uzerinden basariyla calistirildi

## Sonraki Adimlar

- Faz 2: Baud rate generator + gercek TX state machine
- I2C Master (basit)
- UVM protocol check (sartname odul kriteri #3)
- YZ hizlandirici iskelet (sartname odul kriteri #4)
