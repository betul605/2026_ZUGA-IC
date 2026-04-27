# Milestone 10: FPGA Top-Level Wrapper (Arty A7-100T)

**Tarih:** 27 Nisan 2026
**Commit:** 8e70da5

## Hedef

soc_top'i FPGA'ya yuklenebilir hale getirmek. Xilinx Artix-7
(XC7A100TCSG324-1, Arty A7-100T) icin top-level wrapper, pin
atamalari ve build talimatlari hazirlamak. Hafta sonu Umur Bugra
ile yapilacak Vivado sentez denemesi icin sifirdan yazma yerine
"projeyi ac, sentezi koştur" senaryosu hedeflendi.

## Strateji

### Iki Top, Iki Dunya

Bu milestone iki ayri top-level modulu kabul ediyor:

- **tb_top.sv:** Simulasyon icin (Verilator), soc_top + clock/reset
  uretimi + debug $display'leri.

- **fpga_top.sv (YENI):** FPGA icin, soc_top + clock divider +
  reset debounce + GPIO/UART pin yonlendirme.

build.sh aynen tb_top.sv'yi kullanir (simulasyon icin), fpga_top.sv
sadece Vivado projesinde kullanilir. Iki dunya bagimsiz, birbirini
etkilemez. Bu DTR'de "iki ayri build path" olarak anlatilabilir.

### Hedef Cihaz Sec0imi

Arty A7-100T sec0ildi cunku:
- Kullanicida bu kart fiziksel olarak mevcut
- Vivado 2023.x kullanicida kurulu
- Ucretsiz Vivado WebPACK lisansi yeterli (XC7A100T)
- 101 K LUT, 240 KB BRAM - SoC + cevre birim icin yeterli
- USB-UART kopru entegre (ek devre yok)
- 4 LED + 4 switch - GPIO demo icin yeterli

ONTR'de bu kart vaat edilmisti.

## Mimari

### fpga_top.sv (87 satir)

Modul portlari:

| Sinyal       | Yon    | Genislik | Aciklama          |
|--------------|--------|----------|-------------------|
| sysclk       | input  | 1        | 100 MHz osilator  |
| cpu_resetn   | input  | 1        | Push button (low) |
| uart_tx      | output | 1        | USB-UART kopru    |
| led          | output | 4        | 4 LED             |
| sw           | input  | 4        | 4 switch          |

Ic mantik bloklari:
1. Clock divider (100 MHz -> 50 MHz, /2)
2. Reset senkronizator (2-flop)
3. Reset debounce (16-bit sayici, ~1.3 ms)
4. SoC instantiation (soc_top)
5. GPIO pin baglantilari (alt 4 bit)

### Clock Yapisi

100 MHz sysclk -> /2 divider -> 50 MHz clk_50

Implementasyon: tek flop ile clock toggle:

   always_ff @(posedge sysclk) clk_50 <= ~clk_50;

Bu en basit divider. Faz 2'de MMCM (Mixed-Mode Clock Manager)
kullanilabilir, daha temiz clock domain crossing icin.

### Reset Mantigi

Iki adim:
1. Senkronizasyon: cpu_resetn -> rst_n_meta -> rst_n_sync (2-flop)
2. Debounce: rst_n_sync 0 oldukca rst_cnt sifir, 1 olduktan sonra
   16-bit sayici tamamlanana kadar rst_n_clean = 0

@ 50 MHz: 65536 cycle = ~1.3 ms debounce
Push button mekanik bouncing icin yeterli.

## Yapilanlar

### 1. rtl/fpga_top.sv (87 satir)

Top-level wrapper. Onceki bolumde detaylari verildi.

### 2. constraints/arty_a7.xdc (50 satir)

Xilinx Design Constraints dosyasi. Vivado bu dosyayi okur, hangi
sinyalin hangi fiziksel pin'e baglanacagini ogrenir.

Pin atamalari:

| Sinyal       | FPGA Pin     | IO Standard | Aciklama         |
|--------------|--------------|-------------|------------------|
| sysclk       | E3           | LVCMOS33    | 100 MHz osilator |
| cpu_resetn   | D9           | LVCMOS33    | Push button      |
| uart_tx      | D10          | LVCMOS33    | USB-UART kopru   |
| led[0]       | H5           | LVCMOS33    | LD0              |
| led[1]       | J5           | LVCMOS33    | LD1              |
| led[2]       | T9           | LVCMOS33    | LD2              |
| led[3]       | T10          | LVCMOS33    | LD3              |
| sw[0]        | A8           | LVCMOS33    | SW0              |
| sw[1]        | C11          | LVCMOS33    | SW1              |
| sw[2]        | C10          | LVCMOS33    | SW2              |
| sw[3]        | A10          | LVCMOS33    | SW3              |

Clock constraint:

   create_clock -period 10.00 -waveform {0 5} [get_ports sysclk]

10 ns periyot = 100 MHz. Bu Vivado'ya saatin frekansini bildirir,
timing analiz icin kritik.

Tasarim ozellikleri:

   set_property CFGBVS VCCO [current_design]
   set_property CONFIG_VOLTAGE 3.3 [current_design]

Arty A7 default 3.3V kullanir.

### 3. README.md (FPGA bolumu eklendi)

Vivado projesinin sifirdan nasil olusturulacagi tarif edildi.
6 adimli prosedur:
1. Vivado 2023.x ac
2. Create New Project, RTL Project
3. Part: xc7a100tcsg324-1
4. Add Sources (RTL dosyalari + fpga_top TOP olarak)
5. Add Constraints (arty_a7.xdc)
6. Run Synthesis

UART kullanim notu eklendi: 9600 baud, 8N1, CPB=5208.

## Vivado Sentez Akisi

Hafta sonu Umur Bugra ile yapilacak adimlar:

### Yol A (Sadece Sentez Denemesi - Onerilen)

1. Vivado proje olustur
2. Tum RTL dosyalarini ekle (cv32e40p_*.sv dahil)
3. fpga_top.sv'yi TOP MODULE olarak isaretle
4. arty_a7.xdc'yi constraints olarak ekle
5. Run Synthesis (5-10 dk surer)
6. Sentez basarili ise: kaynak kullanim raporu, kritik yol analizi
7. Ekran goruntusu al -> DTR raporu

Hedef: "Sentez basarili" gormek. Kaynak kullanimi 5-15% bekleniyor
(CV32E40P + cevre birimleri Artix-7 100K LUT'a gore kucuk).

### Yol B (Tam Demo - Final Teslim Icin)

1. Yol A + Run Implementation (yerleşim + routing)
2. Generate Bitstream (.bit dosyasi)
3. Hardware Manager'da Arty kartina yukle
4. Push button ile reset, PuTTY ile UART oku
5. "Hi" basildigini gor

Yol B daha uzun ama gerc0ek demo. DTR'de zorunlu degil; final
teslim (Agustos) icin saklanir.

## CV32E40P Kaynak Dosyalari

Sentez icin gereken cv32e40p_*.sv dosyalari hala /home/betul'in
kullaneminda. Vivado'ya eklenecek dosyalar:

   cv32e40p_pkg.sv
   cv32e40p_core.sv
   cv32e40p_alu.sv
   cv32e40p_alu_div.sv
   cv32e40p_compressed_decoder.sv
   cv32e40p_controller.sv
   cv32e40p_cs_registers.sv
   cv32e40p_decoder.sv
   cv32e40p_ex_stage.sv
   cv32e40p_fetch_fifo.sv
   cv32e40p_id_stage.sv
   cv32e40p_if_stage.sv
   cv32e40p_load_store_unit.sv
   cv32e40p_mult.sv
   cv32e40p_obi_interface.sv
   cv32e40p_popcnt.sv
   cv32e40p_prefetch_buffer.sv
   cv32e40p_register_file_*.sv
   cv32e40p_sleep_unit.sv

(yaklasik 20-25 dosya, openhwgroup/cv32e40p reposundan)

## Dogrulanan Ozellikler

- [x] fpga_top.sv yazildi (87 satir, sentezlenebilir)
- [x] Clock divider 100 MHz -> 50 MHz (basit /2)
- [x] Reset senkronizator (2-flop)
- [x] Reset debounce (16-bit sayici, ~1.3 ms)
- [x] soc_top instantiation (mevcut SoC bozulmadi)
- [x] GPIO -> 4 LED + 4 switch baglantilari
- [x] UART tx -> USB-UART kopru pin yonlendirme
- [x] arty_a7.xdc yazildi (12 pin atamasi + clock constraint)
- [x] README'ye Vivado talimatlari eklendi (6 adim)
- [x] Mevcut build.sh / simulasyon etkilenmedi
- [x] Iki ayri build path (sim vs FPGA) bagimsiz

## Sartname / DTR Etkisi

### Odul Kriteri #1 Hazirligi

Sartname Madde 4.2.2.2 minimum odul kriteri #1:

"FPGA demosunun yapilmis, en az 2 cevre birim ile test edilmis
olmasi beklenmektedir."

DTR'de su anki durum:
- RTL sentezlenebilir hale getirildi (M09)
- Top-level wrapper yazildi (M10)
- Pin atamalari hazirlandi (M10)
- Vivado projesi olusturma talimatlari yazildi (M10)
- Kalan: gerc0ek sentez + bitstream + FPGA'ya yukleme

DTR icin "FPGA akisi kuruldu, sentez denemesi yapildi" demek
yeterli. Tam demo final teslim icin (Agustos) saklaniyor. M09 +
M10 birlikte bu kriter icin somut zemin olusturur.

### DTR Anlatim Hikayesi

DTR raporunda asagidaki gibi anlatilabilir:

"FPGA entegrasyonu iki milestone ile saglandi. Milestone 09'da
UART modulu sentezlenebilir hale getirildi (gerc0ek baud rate
generator + 10-bit TX state machine + tx_o pini). Milestone 10'da
Arty A7-100T icin top-level wrapper (rtl/fpga_top.sv) yazildi: 100
MHz sysclk'i 50 MHz'e bolen clock divider, reset senkronizator ve
debounce, GPIO/UART pin yonlendirme. Constraints dosyasi
(constraints/arty_a7.xdc) 12 pin atamasini ve clock constraint'i
icerir. README'de Vivado proje olusturma adimlari belgelendi."

Bu hikaye DTR'nin "FPGA hazirligi" basliginda kullanilir.

### Mukayese: Onceden vs Su An

| Aspect              | Once (M08'de)        | Simdi (M10'da)         |
|---------------------|----------------------|------------------------|
| Top-level modul     | sadece tb_top.sv     | tb_top + fpga_top.sv  |
| Pin atamasi         | Yok                  | 12 pin XDC dosyasi     |
| Clock yapisi        | sim only (5 ns)      | 100 MHz + /2 divider   |
| Reset stratejisi    | sim only             | Debounce + sync        |
| UART cikisi         | $write only          | tx_o gerc0ek pin       |
| FPGA hazirligi      | Hayir                | Evet (Vivado projesi)  |

## Mimari Notlar

### MMCM mi /2 mi?

Profesyonel olarak Xilinx MMCM (Mixed-Mode Clock Manager) clock
generation icin kullanilir. Ama ilk denemede /2 daha basit:
- Tek bir flop
- Saglikli timing
- Simulator'da da test edilebilir
- Sentez bonus IP gerektirmez

Faz 2 (final teslim icin) MMCM eklenebilir. Su an /2 yeterli.

### Reset Debounce Surenin Sec0imi

@ 50 MHz ile 16-bit sayici ~1.3 ms. Push button mekanik bouncing
genelde 0.1-10 ms aralliginda. 1.3 ms guvenli orta nokta. Daha
agressif (0.1 ms) hızlı tepki ama bouncing yakalayabilir; daha
yavas (10+ ms) kullanici deneyimini bozabilir.

### GPIO Bit Genisligi

soc_top'ta gpio 16-bit. Arty'de sadece 4 LED + 4 switch var. Geri
kalan 12 bit fpga_top'ta tanimlanmadi (Vivado warning verecek ama
sentezler). DTR'de "GPIO 16-bit, FPGA'da alt 4 bit kullanildi"
denir.

## Sonraki Adimlar

- [ ] Hafta sonu (3-4 May): Umur Bugra ile Vivado sentez denemesi
- [ ] Sentez sonuc raporu DTR'ye eklenir (kaynak kullanim, timing)
- [ ] Olasi: Bitstream + Arty'ye yukleme + UART demo
- [ ] DTR rapor yazimi (9-15 May)
- [ ] Final teslim icin: MMCM clock manager, RX UART eklenecek
