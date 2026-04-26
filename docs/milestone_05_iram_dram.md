# Milestone 05: IRAM / DRAM Ayrimi

**Tarih:** 24 Nisan 2026
**Commit:** 0bda9c7

## Hedef

ONTR'de vaat edilen ayri instruction RAM (IRAM) ve data RAM (DRAM)
ayrimini RTL'e tasimak. Tek 16 KB blok yerine iki bagimsiz 8 KB
RAM instance'i kullanmak.

## Mimari Yaklasim: "Minimal Split"

Iki olasi yol vardi:

- Yol A (secilen): Mevcut RAM korunur, yanina yeni DRAM instance
  eklenir. Decoder'a tek slave eklenir. Linker script degismez,
  mevcut testler etkilenmez.

- Yol B (sonraki iterasyon icin): ONTR'nin tam haritasi
  (IRAM 0x10000, DRAM 0x20000, Boot ROM 0x00000). Tum hex
  dosyalari yeniden uretilmeli, regression riski yuksek.

Yol A secildi: regression-safe, hizli (30 dk), DTR icin yeterli.
Tam ONTR uyumlulugu DTR sonrasi bootloader entegrasyonu ile
yapilacak.

## Yapilanlar

### Decoder genisletildi (4 -> 5 slave)

sel_dram_req = (data_addr[31:24] == 8'h00) AND (data_addr[17] == 1'b1)

addr[17] biti IRAM/DRAM ayrimini saglar:
- 0 : IRAM araligi (0x00000000 - 0x0001FFFF)
- 1 : DRAM araligi (0x00020000 - 0x0003FFFF)

### Yeni sinyaller eklendi

- dram_req, dram_gnt, dram_rvalid, dram_rdata
- Gnt mux'a DRAM yolu eklendi
- Select-latch'e sel_dram_q eklendi (OBI rvalid timing)

### RAM instance'lari yeniden duzenlendi

u_ram -> u_iram (yeniden adlandirildi):
- SIZE_WORDS: 4096 -> 2048 (16 KB -> 8 KB)
- MEM_FILE: hello.hex (degismedi)
- Port A: instruction (degismedi)
- Port B: data fallback

u_dram (yeni instance):
- SIZE_WORDS: 2048 (8 KB)
- MEM_FILE: bos (initial sifir)
- Port A: tie-off
- Port B: data port (sel_dram_req ile yonlendiriliyor)

### Bellek Haritasi (bu milestone itibari ile)

| Adres Araligi | Modul | Boyut |
|---|---|---|
| 0x00000000-0x00001FFF | IRAM | 8 KB |
| 0x00020000-0x00021FFF | DRAM | 8 KB |
| 0x10000000 | UART | - |
| 0x40000000-0x40000FFF | GPIO | 4 KB |
| 0x40001000-0x40001FFF | Timer | 4 KB |

## Sonuc

- Build basarili (Verilator hicbir hata vermedi)
- Timer self-check testi hala geciyor: 'T' basiliyor
- IRAM uzerinde lineer instruction fetch dogrulandi
- Decoder 5 slave'i dogru yonlendiriyor
- DRAM henuz kullanilmiyor ama yapi kurulu

Simulasyon cikti dogrulamasi:
- IFETCH 0x00, 0x04, ... lineer akis (IRAM)
- DWRITE addr=0x40001008 (Timer CLR)
- DWRITE addr=0x4000100c (Timer ENA)
- DWRITE addr=0x10000000 data=0x00000054 ('T' UART)

## Dogrulanan Ozellikler

- IRAM, instruction port (Port A) uzerinden fetch yapabiliyor
- DRAM yeni adres araliginda decode ediliyor (0x00020000)
- 5 slave decoder, dogru yonlendirme yapiyor
- Select-latch patterni 4. slave'e de uyum sagladi
- Mevcut Timer testi bozulmadi (regression-free)
- Parametreli ram.sv yeniden kullanildi (kod tekrari yok)

## Mimari Notlar

ram.sv zaten parametreli yazilmisti (SIZE_WORDS ve MEM_FILE).
Yeni bir modul yazmaya gerek kalmadi. "Design for reuse" ornegi.

DRAM instance'inda instruction port (Port A) tie-off edildi.
Verilator bu yapidan rahatsiz olmadi.

addr[17] secimi ONTR'deki bit 16'dan farkli. Sebep: linker script
ve mevcut hex dosyalarini etkilememek icin IRAM 0x00000000'da
kalmali. Bit 17, ucuz bir decode ve yeterli bolge ayrimi saglar.

## Sonraki Adimlar

- Gercek UART (EK-2 yazmaclari)
- I2C Master (basit)
- UVM protocol check (sartname odul kriteri #3)
- YZ hizlandirici iskelet (sartname odul kriteri #4)
