# ZUGA-IC

TEKNOFEST 2026 Çip Tasarım Yarışması - Mikrodenetleyici Tasarım Kategorisi

CV32E40P RISC-V çekirdeği üzerine kurulu, **AXI4-Lite tabanlı** System-on-Chip
prototipi. Yapay zeka hızlandırıcı için altyapı hazır.

[![GitHub commits](https://img.shields.io/badge/commits-72-brightgreen)]()
[![Milestone](https://img.shields.io/badge/milestone-54-blue)]()
[![Tests](https://img.shields.io/badge/AXI%20tests-117%2B%20PASS-success)]()
[![Errors](https://img.shields.io/badge/errors-0-success)]()

---

## Takım

| Rol | İsim |
|-----|------|
| Takım Adı | ZUGA-IC (ID: 989786) |
| Kaptan | Umur Buğra Dikmen |
| Üye | Betül Bedir |
| Danışman | Dr. Fatih Gül |
| Üniversite | Recep Tayyip Erdoğan Üniversitesi EEM |

---

## Mevcut Durum (11 Mayıs 2026)

### Hızlı Özet

- **72 commit, 54 milestone** (M01-M54)
- DTR Teslim: **15 Mayıs 2026** (4 gün kaldı)
- **54 AXI transaction PASS**, 117+ handshake, **0 hata**
- Şartname Min. Başarı Kriteri **#1 (UART RX), #2 (Self-checking), #3 (Protocol Check)** ✅

### Aşama Tablosu

| Aşama | Milestone | Durum | Sonuç |
|-------|-----------|-------|-------|
| RTL temel sistem | M01-M10 | ✅ TAMAM | OBI bus + 4 çevre birim |
| I2C entegrasyonu | M11-M15 | ✅ TAMAM | 6. slave eklendi |
| Şartname analizi | M16 | ✅ TAMAM | AXI4-Lite gereksinimi tespit |
| AXI Bridge | M17 | ✅ TAMAM | OBI ↔ AXI4-Lite (12/12 PASS) |
| AXI4-Lite slave geçişi | M18-M22 | ✅ TAMAM | 5 slave (37 PASS) |
| AXI Protocol Check | M23 | ✅ TAMAM | 5 SVA, 63 handshake, 0 FAIL |
| DTR rapor güncelleme | M24 | ✅ TAMAM | 1039 satır |
| Test screenshot kanıtları | M25 | ✅ TAMAM | 6 PNG + 6 TXT |
| Vivado sentez | - | 🔄 PLAN | 9-10 May (Umur ile) |
| Boot ROM + Memory Map | - | 🔄 PLAN | 7-8 May |
| 2. UART instance | M31 | ✅ TAMAM | uart_axi.sv 2 instance, 6/6 PASS |
| **DTR güncelleme dalgası** | **M27-M40** | ✅ **TAMAM** | **14 milestone** |
| Boot ROM (mühendislik zarafeti) | M29 | ✅ TAMAM | ram_axi.sv yeniden kullanım, 6/6 PASS |
| **Ekstra puan dalgası** | **M41-M48** | ✅ **TAMAM** | **8 milestone** |
| Regression Suite | M41 | ✅ TAMAM | 8/8 PASS otomatik |
| Coverage Raporu | M42 | ✅ TAMAM | 199 satır, ~%82 line/%75 toggle |
| 4 Mermaid Diyagram PNG | M44 | ✅ TAMAM | System/Modules/Handshake/Boot |
| Boot ROM Disassembly | M46 | ✅ TAMAM | Compile + Run çift doğrulama |
| **🌟 FAZ 7: soc_top_axi.sv** | **M49** | ✅ **TAMAM** | **520 satır, lint temiz** |
| DTR'de Faz 7 TAMAMLANDI | M50 | ✅ TAMAM | 9 yer güncellendi |
| **Şablon eksikleri** | **M51-M52** | ✅ **TAMAM** | **+18 puan garanti** |
| Çip Tasarım Akışı (Bölüm 14) | M51 | ✅ TAMAM | 5p |
| Kaynakça (Bölüm 15) | M51 | ✅ TAMAM | 2p, IEEE 21 kaynak |
| **YZ Hızlandırıcı (Bölüm 16)** | **M52** | ✅ **TAMAM** | **11p, 9 alt bölüm** |
| **🌟 UART RX (Test 25p kritik)** | **M53-M54** | ✅ **TAMAM** | **5/5 PASS, TX->RX loopback** |
| Vivado sentez | - | 🔄 PLAN | 9-10 May (Umur ile) |
| DTR şablon yapısına çevirme | - | 🔄 PLAN | 11-12 May |
| Kapak + İçindekiler | - | 🔄 PLAN | 12-13 May |
| PDF üretimi + format | - | 🔄 PLAN | 13-14 May |
| DTR PDF teslim | - | 🔄 PLAN | 12-15 May |

---

## Kritik Sayılar

### Doğrulama Sonuçları
- **OBI Sistem**: 4 self-checking test (hello, GPIO, Timer, full+I2C) — tümü PASS
- **OBI Protocol Check**: 3 SVA, 1000 cycle, **0 FAIL**
- **AXI Bridge**: 12 transaction (6 write + 6 read) — tümü PASS
- **AXI Slave Bağımsız**: 25 senaryo, 37 transaction — tümü PASS
- **AXI Protocol Check**: 5 SVA × 3 modül bind, 63 handshake — **0 FAIL**

### Toplam: 162+ AXI transaction (49 fonksiyonel + 113 protocol check), 0 hata, 0 lint warning

### Şartname Uyumu
| Madde | Durum |
|-------|-------|
| §4.1 AXI4-Lite zorunlu | ✅ Bridge + 5 slave |
| §4.2.2 CV32E40P çekirdek | ✅ |
| §4.2.2 Çevre birimleri (en az 2) | ✅ 5 birim (RAM, GPIO, Timer, UART, I2C) |
| §4.2.2.1 Boot ROM | ⏳ 7-8 May |
| §4.2.2 İkinci UART | ⏳ 11 May |
| §5.2 #1 FPGA + 2 çevre | 🔄 Vivado sentez 9-10 May |
| §5.2 #2 Self-checking test | ✅ KARŞILANDI |
| §5.2 #3 AXI Protocol Check | ✅ **KARŞILANDI** |
| §5.2 #4 YZ test | ⏳ Final dönem |
| §5.2 #5 GDSII | ⏳ Final dönem |
| EK-2 yazmaç haritası | ✅ 5 birim birebir uyumlu |

---

## Milestone Geçmişi

Detaylı milestone raporları için: `docs/milestone_XX.md`

### Faz 1: Temel Sistem (M01-M10)

- **M01**: CV32E40P entegrasyonu, basic OBI bus
- **M02**: RAM modülü (8 KB IRAM + 8 KB DRAM)
- **M03**: UART primitive (TX-only)
- **M04**: GPIO 16-bit (IDR/ODR)
- **M05**: Timer 32-bit (prescaler + event)
- **M06**: soc_top OBI decoder, 4 çevre birim entegrasyonu
- **M07**: OBI Protocol Check (3 SVA assertion, 1000 cycle 0 FAIL)
- **M08**: Self-checking test programları (hello, GPIO, Timer)
- **M09**: UART Faz 2 (TX state machine + baud generator, 'R' karakteri gözlendi)
- **M10**: FPGA Top-Level (Arty A7-100T, pin atamaları, clock yapısı)

### Faz 2: I2C Entegrasyonu (M11-M15)

- **M11**: DTR rapor şablonu hazırlandı (12 bölüm)
- **M12**: Mimari diyagram (3 Mermaid)
- **M13**: I2C Master modülü (OpenCores tarzı, 6 yazmaç)
- **M14**: I2C testbench (5 senaryo PASS)
- **M15**: 6. slave entegrasyonu, full regression test

### Faz 3: Şartname Analizi + AXI4-Lite Geçişi (M16-M22)

**Kritik Karar:** Şartname §4.1 AXI4-Lite zorunlu kıldığı tespit edildi (M16). 8 fazlı geçiş planı yapıldı.

- **M16**: Şartname detaylı analizi (`docs/SARTNAME_ANALIZI.md`)
- **M17 (Faz 1)**: OBI ↔ AXI4-Lite Bridge — `obi_to_axi_lite.sv` (12/12 PASS)
- **M18 (Faz 2)**: RAM AXI4-Lite — `ram_axi.sv` (parametreli IRAM/DRAM, 4/4 PASS)
- **M19 (Faz 3)**: GPIO AXI4-Lite — `gpio_axi.sv` (32-bit, EK-2 uyumlu, 5/5 PASS)
- **M20 (Faz 4)**: Timer AXI4-Lite — `timer_axi.sv` (8 yazmaç, EK-2, 5/5 PASS)
- **M21 (Faz 5)**: UART AXI4-Lite — `uart_axi.sv` (TX state machine + baud, 6/6 PASS)
- **M22 (Faz 6)**: I2C AXI4-Lite — `i2c_master_axi.sv` (10-durumlu state machine, 5/5 PASS)

**Faz 7 (soc_top entegrasyon)** Final teslimine ertelendi (alt-sistem testleri yeterli kanıt sağladı).

### Faz 4: Doğrulama + DTR Birinci Dalga (M23-M26, 3-5 May)

- **M23 (Faz 8)**: AXI Protocol Check — `axi_lite_assertions.sv` (5 SVA, 3 modül bind, 63 handshake / 0 FAIL)
- **M24**: DTR rapor AXI sonuçları ile güncellendi (Bölüm 1, 7, 12 — 855→1039 satır)
- **M25**: Test screenshot kanıtları (6 PNG + 6 TXT, `docs/screenshots/`)
- **M26**: README.md kapsamlı yenileme (81→421 satır)

### Faz 5: Boot ROM + Dual UART + DTR İkinci Dalga (M27-M39, 7 May)

**13 milestone, ~10 saat çalışma, DTR raporu 855→1678 satır (%96 büyüme).**

**Yeni RTL Eklemeleri (Mühendislik Zarafeti — yeni RTL yazılmadan):**
- **M29**: Boot ROM (512 B @ 0x00) — `ram_axi.sv` parametreli yeniden kullanım, 6/6 PASS, 12 handshake
- **M31**: Dual UART (2× UART) — `uart_axi.sv` 2 instance, 6/6 PASS, 'U' 'S' '1' ekranda, 38 handshake

**DTR Rapor Güncellemeleri (12/13 bölüm tamamlandı):**
- **M27**: Bölüm 10 (Şartname Kriterleri) + Bölüm 13 (Sonuç)
- **M30**: Bölüm 3 (Memory Map ÖTR Tablo 1 birebir)
- **M32**: Bölüm 3 UART-1 → M31 OK
- **M34**: Bölüm 11 (Takvim, 4 faz, 33 milestone tablosu)
- **M35**: Bölüm 4 (Modül Detayları, 13 RTL detay)
- **M36**: Bölüm 6 (Doğrulama Metodolojisi, 4 katman)
- **M37**: Bölüm 8 (Karşılaşılan Zorluklar, AXI geçiş hikayesi)
- **M38**: Bölüm 5 (Tasarım Kararları, AXI4-Lite rasyonel)
- **M39**: Bölüm 2 (ÖNTR Değişiklikler, OTR-DTR uyum %92)

**Görsel Kanıt + GitHub:**
- **M28**: GitHub commits + git tag screenshot, dtr-pre-axi-m17 annotated'a çevrildi
- **M33**: UART-dual + Lint screenshots (10 görsel toplam)

---

## Sıradaki Adımlar

### Hafta Sonu (9-10 Mayıs) — Vivado Sentez ⭐
**Sorumlu:** Umur Buğra Dikmen + Betül Bedir
- Arty A7-100T için Vivado projesi oluşturma
- Sentez raporu (resource utilization)
- Static Timing Analysis (STA)
- 50 MHz timing constraint doğrulama
- Sonuç: 3 yeni screenshot DTR raporuna

### Hafta 2 (5-11 Mayıs)
- **Boot ROM + Memory Map** (7-8 May): Şartname §4.2.2.1 (QSPI'dan boot, 512B-1KB ROM)
- **2. UART Instance** (11 May): Şartname §4.2.2 (genel + YZ veri akışı)
- **DTR Bölüm 10, 13 güncelleme**

### Hafta 3 (12-15 Mayıs)
- **Mermaid diyagramları PNG'ye çevirme** (mermaid CLI veya mermaid.live)
- **DTR PDF üretimi** (pandoc, A4, 11 punto Calibri, 1.15 satır)
- **Son revizyon ve format kontrolü**
- **15 May 17:00** — DTR Teslim 🎯

### Final Dönemi (Mayıs-Temmuz 2026)
- soc_top tam AXI4-Lite entegrasyonu (Faz 7)
- YZ Hızlandırıcı (TFLite Tiny Conv)
- QSPI Master
- UART RX (Receive)
- UVM Agent (AXI doğrulama)
- GDSII (Sky130 + OpenLane)
- JTAG Debug (opsiyonel)

---

## Test Sonuçları (Detaylı)

### AXI4-Lite Bağımsız Slave Testleri

| Modül | Yazmaç | Test | Transaction | Sonuç |
|-------|--------|------|-------------|-------|
| ram_axi (M18) | parametreli | 4 | 4W + 4R | ✅ PASS |
| gpio_axi (M19) | 2 (32-bit) | 4 | 2W + 3R | ✅ PASS |
| timer_axi (M20) | 8 (EK-2) | 5 | 7W + 5R | ✅ PASS |
| uart_axi (M21) | 5 (EK-2) | 6 | 4W + 4R | ✅ PASS |
| i2c_master_axi (M22) | 5 (EK-2) | 5 | 5W + 5R | ✅ PASS |
| **TOPLAM** | | **24** | **37** | **✅ 0 hata** |

### AXI4-Lite Bridge

| Test | Transaction | Sonuç |
|------|-------------|-------|
| Tek WRITE | 1 | ✅ PASS |
| Tek READ | 1 | ✅ PASS |
| Back-to-back 5 WRITE | 5 | ✅ 5/5 PASS |
| Back-to-back 5 READ | 5 | ✅ 5/5 PASS |
| **TOPLAM** | **12** | **✅ 0 hata** |

### AXI Protocol Check (Şartname §5.2 Min. Kriter #3)

5 SVA assertion: AW/W/B/AR/R stability

| Modül | AW | W | B | AR | R | FAIL |
|-------|----|----|----|----|----|------|
| ram_axi | 4 | 4 | 4 | 4 | 4 | 0 |
| gpio_axi | 2 | 2 | 2 | 3 | 3 | 0 |
| timer_axi | 7 | 7 | 7 | 5 | 5 | 0 |
| **TOPLAM** | **13** | **13** | **13** | **12** | **12** | **0** |

**63 handshake gözlemi, 5 × 63 = 315 kural değerlendirmesi, 0 ASSERT FAIL.**

### Test Kanıt Görselleri

Her AXI testi için terminal screenshot ve simulator çıktısı:

- `docs/screenshots/01_ram_axi_test.png` + `.txt`
- `docs/screenshots/02_gpio_axi_test.png` + `.txt`
- `docs/screenshots/03_timer_axi_test.png` + `.txt`
- `docs/screenshots/04_uart_axi_test.png` + `.txt`
- `docs/screenshots/05_i2c_master_axi_test.png` + `.txt`
- `docs/screenshots/06_axi_bridge_test.png` + `.txt`

---

## Proje Yapısı

```
cv32_sim/
├── rtl/                          # Sentezlenebilir RTL (13 modül)
│   ├── ram.sv, ram_axi.sv        # 8KB RAM (OBI + AXI4-Lite)
│   ├── gpio.sv, gpio_axi.sv      # GPIO (16-bit OBI / 32-bit AXI)
│   ├── timer.sv, timer_axi.sv    # Timer (32-bit, 8 yazmaç EK-2)
│   ├── uart.sv, uart_axi.sv      # UART (TX state machine)
│   ├── i2c_master.sv, i2c_master_axi.sv  # I2C (10-durumlu)
│   ├── obi_to_axi_lite.sv        # AXI Bridge (Faz 1)
│   ├── soc_top.sv                # OBI tabanlı sistem (mevcut)
│   └── fpga_top.sv               # FPGA wrapper (Arty A7)
├── tb/                           # Testbench dosyaları
│   ├── tb_top.sv                 # Ana sistem testbench
│   ├── obi_assertions.sv         # OBI Protocol Check (M07)
│   ├── axi_lite_assertions.sv    # AXI Protocol Check (M23)
│   └── *_axi_tb.sv               # AXI bağımsız testbench (5 adet)
├── sw/                           # RISC-V test programları
│   ├── hello.S, test_gpio.S      # Self-checking testler
│   ├── test_timer.S, test_full.S # Regression test
│   └── *.hex                     # Linker output
├── docs/                         # Dokümantasyon (16+ .md)
│   ├── DTR_RAPORU_v0.md          # DTR Raporu (1039 satır)
│   ├── SARTNAME_ANALIZI.md       # Şartname analizi (M16)
│   ├── MIMARI_DIYAGRAM.md        # 3 Mermaid diyagram
│   ├── milestone_XX.md           # Her milestone için rapor
│   └── screenshots/              # Test kanıt görselleri
├── constraints/
│   └── arty_a7.xdc               # FPGA pin atamaları
├── build*.sh                     # Otomasyon scriptleri (8 adet)
└── README.md                     # Bu dosya
```

---

## Kurulum ve Çalıştırma

### Bağımlılıklar

- **Verilator** 5.020+ (`--timing` flag testbench için gerekli)
- **xPack RISC-V GCC** 13.2.0+ (`xpack-riscv-none-elf-gcc-13.2.0-2`)
- **CV32E40P RTL**: Ayrı klonlanmalı (`~/cv32e40p/`)
- Python 3, make, bash, git

### CV32E40P Çekirdeği

```bash
git clone https://github.com/openhwgroup/cv32e40p ~/cv32e40p
```

### Eski OBI Sistem (M01-M15)

```bash
./build.sh
./obj_dir/sim_cv32 | head -30
```
**Beklenen:** `data=0x00000054` (T = Timer test PASS)

### AXI4-Lite Bağımsız Testler (M17-M22)

Her modül için ayrı build script:

```bash
./build_axi.sh        # M17: AXI Bridge testi
./build_ram_axi.sh    # M18: RAM AXI4-Lite testi
./build_gpio_axi.sh   # M19: GPIO AXI4-Lite testi
./build_timer_axi.sh  # M20: Timer AXI4-Lite testi
./build_uart_axi.sh   # M21: UART AXI4-Lite testi
./build_i2c_axi.sh    # M22: I2C AXI4-Lite testi
```

Her script şu çıktıyı verir:
- `[TB] ====== ALL TESTS PASSED ======`
- `[AXI-CHECK] Sonuc raporu` (M23 protocol check sonrası)

---

## Bellek Haritası

Mevcut OBI tabanlı sistem (eski) ve AXI4-Lite slave'ler aynı bellek adreslerini kullanır:

| Adres Aralığı | Modül | Boyut | Yazmaç |
|---------------|-------|-------|--------|
| `0x00000000-0x00001FFF` | IRAM | 8 KB | (program kodu) |
| `0x00020000-0x00021FFF` | DRAM | 8 KB | (veri belleği) |
| `0x40000000-0x40000FFF` | GPIO | - | IDR (0x00), ODR (0x04) |
| `0x40001000-0x40001FFF` | Timer | - | PRE/ARE/CLR/ENA/MOD/CNT/EVN/EVC (8 yazmaç) |
| `0x40002000-0x40002013` | UART | - | CPB/STP/RDR/TDR/CFG (5 yazmaç) |
| `0x40004000-0x40004017` | I2C Master | - | NBY/ADR/RDR/TDR/CFG (5 yazmaç) |

**Not:** Yazmaç haritaları şartname EK-2'ye birebir uyumlu.

---

## FPGA Sentez (Arty A7-100T)

Proje **Xilinx Artix-7 XC7A100TCSG324-1** (Digilent Arty A7-100T) için sentezlenebilir hale getirilmiştir (M10).

### Vivado Projesi Oluşturma

1. Vivado 2023.x aç
2. **Create New Project** → RTL Project → "Do not specify sources" seç
3. **Part:** `xc7a100tcsg324-1`
4. **Add Sources** (Design Sources):
   - `rtl/cv32e40p_*.sv` (CV32E40P kaynak dosyaları, ayrı klonlanmalı)
   - `rtl/ram.sv`, `rtl/gpio.sv`, `rtl/timer.sv`, `rtl/uart.sv`
   - `rtl/i2c_master.sv`, `rtl/soc_top.sv`
   - `rtl/fpga_top.sv` (**TOP MODULE** olarak işaretle)
5. **Add Constraints:** `constraints/arty_a7.xdc`
6. **Run Synthesis**

### FPGA Pin Atamaları

| Sinyal | Yön | FPGA Pin | Açıklama |
|--------|-----|----------|----------|
| sysclk | input | E3 | 100 MHz osilatör |
| cpu_resetn | input | D9 | Reset push button (active low) |
| uart_tx | output | D10 | USB-UART köprü (FPGA→PC) |
| led[3:0] | output | H5, J5, T9, T10 | 4 LED |
| sw[3:0] | input | A8, C11, C10, A10 | 4 Switch |

### Clock Yapısı

- Arty 100 MHz `sysclk` → /2 divider → **50 MHz çekirdek saati**
- ÖNTR'de vaat edilen 50 MHz hedefi tutturuldu
- Gelecek: MMCM ile gerçek clock generation

### UART Kullanımı

UART TX pini Arty USB-UART köprüsüne (FT2232HL) bağlı. PC'de seri port açılarak UART çıktısı görülebilir:

- **Baud rate:** 9600 (CPB = 5208 ile, 50 MHz / 9600)
- **Format:** 8N1 (8 data bit, no parity, 1 stop bit)
- **Yazılım:** PuTTY, minicom, screen, vb.

Yazılım önyükleme: CPB yazmacına 5208 yaz (default 16, simulator hızı için)

```assembly
LUI  x10, 0x40002
ADDI x11, x0, 5208     # 0x1458
SW   x11, 0(x10)       # CPB = 5208
```

### Reset Davranışı

Push button (CPU_RESETN) basıldığında:
1. Senkronizasyon: 2-flop senkronizatörden geçer
2. Debounce: 16-bit sayıcı (~1.3 ms @ 50 MHz) bekleyiş
3. `rst_n_clean` SoC'ye geçer

---

## Teknik Kararlar

- **Çekirdek:** `cv32e40p_core` seçildi (top değil, FPU wrapper bağımlılığı nedeniyle)
- **FPU=0** (int8 AI hedefi)
- **SystemVerilog 2017** sentetik alt küme (tip güvenliği + CV32E40P uyumu)
- **AXI4-Lite Bridge:** OBI ↔ AXI4-Lite dönüşümü için 6 durumlu state machine
- **Doğrulama:** SVA + always_ff (Verilator-uyumlu, pragmatik). Şartname §5.2 kriter #3 SVA ile karşılandı.
- **Cevre birim sayısı:** Şartname kriteri 2 çevre birim, biz **5 birim** sağladık (RAM hariç GPIO, Timer, UART, I2C)

---

## Önemli Dosyalar

### Dokümantasyon
- [`docs/DTR_RAPORU_v0.md`](docs/DTR_RAPORU_v0.md) — DTR Raporu (1039 satır, 13 ana bölüm)
- [`docs/SARTNAME_ANALIZI.md`](docs/SARTNAME_ANALIZI.md) — Şartname analizi (M16)
- [`docs/MIMARI_DIYAGRAM.md`](docs/MIMARI_DIYAGRAM.md) — 3 Mermaid sistem diyagramı
- [`docs/OTR_DTR_KARSILASTIRMA.md`](docs/OTR_DTR_KARSILASTIRMA.md) — ÖNTR ↔ DTR karşılaştırması

### Test Kanıtları
- [`docs/screenshots/`](docs/screenshots/) — 6 PNG + 6 TXT (test sonuçları)

### Milestone Raporları
- `docs/milestone_01.md` ... `docs/milestone_25.md` (her milestone için ayrı rapor)

---

## Git Tag'leri (Sigorta Noktaları)

- `dtr-pre-axi-m17` — AXI geçişi öncesi (28 Nis 2026)
- `m22-axi-slaves-done` — 6/8 AXI fazı tamam (1 May 2026)

Rollback için: `git checkout TAG_NAME`

---

## Referanslar

- **CV32E40P:** https://github.com/openhwgroup/cv32e40p
- **CV32E40P Manual:** https://docs.openhwgroup.org/projects/cv32e40p-user-manual/
- **RISC-V Spec:** https://riscv.org
- **TEKNOFEST:** https://www.teknofest.org
- **Verilator:** https://www.veripool.org/verilator/
- **AXI4-Lite Spec:** https://developer.arm.com/documentation/ihi0022

---

## İletişim

Proje hakkında sorular için takım kaptanına ulaşabilirsiniz: **Umur Buğra Dikmen**

GitHub: https://github.com/betul605/ZUGA-IC

---

**Son Güncelleme:** 5 Mayıs 2026 — Milestone 25
**DTR Teslim:** 15 Mayıs 2026, 17:00
**Final Teslim:** 31 Temmuz 2026
