# DTR için Mevcut Durum Raporu — ZUGA-IC

**Tarih:** 24 Nisan 2026
**DTR Teslim:** 15 Mayıs 2026, 17:00
**Kalan Süre:** 21 gün

---

## Özet Skoru

| Metrik | Durum |
|---|---|
| DTR hazırlığı (11 başlık üzerinden) | ~30% |
| Şartname minimum ödül kriterleri | 1/5 karşılandı |
| Git commit sayısı | 4 |
| RTL satır sayısı | ~410 |
| Çalışan self-checking test | 1 (GPIO) |
| Çözülen kritik bug | 4 |

---

## DTR Zorunlu İçerik — Durum Tablosu

Şartname Madde 4.2.2.1'e göre DTR'de olması gerekenler:

| # | Başlık | Durum | Detay |
|---|---|---|---|
| 1 | Mimarinin tüm detayları | 🟡 Kısmen | ÖTR'de var, güncellenmeli |
| 2 | Tasarım kararları ve rasyoneli | ✅ Güçlü | 4 büyük karar, her biri savunulabilir |
| 3 | Doğrulama sonuçları | 🟡 Başlangıç | 2 test (Hi + GPIO self-check) |
| 4 | Doğrulama/test planları | ❌ Yazılmadı | ÖTR'de çerçeve var, somutlanmalı |
| 5 | Test durum dökümü | 🟡 Eksik | 2 test var, dökümanı yok |
| 6 | Coverage raporları | ❌ Yok | Verilator akışı kurulmalı |
| 7 | Ekran görüntüleri | 🟡 Çekilmedi | Terminal çıktısı var, kaydedilmedi |
| 8 | Git repo referansları | 🟡 Sadece local | GitHub'a yüklenmedi |
| 9 | Takvimsel/kapsam durumu | 🟡 Kısmi | PROJE_DURUM.md var |
| 10 | Karşılaşılan zorluklar | ✅ Çok güçlü | 4 gerçek bug + çözüm |
| 11 | Yaklaşan kilometre taşları | 🟡 Kısmi | Somut plan yapılmalı |

---

## Şu Anda Elimizde Olan Somut Çıktılar

### RTL Kodu (sentezlenebilir, ~410 satır)

| Dosya | Satır | Ne yapıyor |
|---|---|---|
| rtl/ram.sv | 82 | Dual-port RAM, OBI arayüz |
| rtl/uart_primitive.sv | 37 | Memory-mapped UART (\$write) |
| rtl/gpio.sv | 76 | ÖTR EK-2 uyumlu GPIO (IDR+ODR) |
| rtl/soc_top.sv | 212 | SoC üst modülü, 3-slave decoder |

### Testbench

| Dosya | Satır | Ne yapıyor |
|---|---|---|
| tb/tb_top.sv | ~60 | Clock, reset, izleme, cycle sayacı |

### Yazılım (RISC-V asm)

| Dosya | Amaç |
|---|---|
| sw/hello.S | UART'a "Hi\n" basan smoke test |
| sw/test_gpio.S | GPIO write/read self-checking test |

### Altyapı

- build.sh (reproducible build — şartname zorunlu kılıyor)
- .gitignore
- Git repo (local, 4 commit)

### Dokümantasyon

- docs/milestone_01_hello.md
- docs/milestone_02_modular_soc.md
- docs/PROJE_DURUM.md
- docs/DTR_DURUM.md (bu dosya)

---

## Git Commit Geçmişi

| Commit | Mesaj |
|---|---|
| 1aa0ab5 | Milestone 03: GPIO modülü + self-checking test — write/read 0xAA -> 'P' |
| ce79ec3 | Dokumanlar eklendi: milestone 01, milestone 02, PROJE_DURUM |
| 221d4b0 | Milestone 02: Modüler SoC yapısı + OBI bus select latch düzeltmesi |
| b5424de | Milestone 01: CV32E40P ayakta, 'Hi' mesajı UART'tan basıldı |

---

## DTR'de Güçlü Anlatılacak Kısımlar

### 1. Çözülen 4 Kritik Bug

DTR'nin "Karşılaşılan Zorluklar" bölümünde anlatılacak. Her biri gerçek
donanım mühendisliği problemi:

**Bug #1: Hex dosya formatı**
- Sorun: objcopy her satıra birden çok word yazıyor, Verilator \$readmemh
  tutarsız okuyor.
- Çözüm: Python script ile binary → düzgün hex dönüşümü (her satır 1 word).

**Bug #2: Compressed instruction karışıklığı**
- Sorun: rv32imc ile compressed komutlar karışık alignment üretiyor.
- Çözüm: -march=rv32i ile compressed kapatıldı.

**Bug #3: OBI instruction rdata latency**
- Sorun: Testbench rdata'yı combinational döndürüyordu, çekirdek yanlış
  komutlar fetch ediyordu.
- Çözüm: Adres latch'lenip bir cycle sonra rdata üretildi.

**Bug #4: OBI bus select-latch (KRİTİK)**
- Sorun: data_rvalid mux'ı current data_addr'a bakıyordu; ama rvalid
  bir cycle sonra gelir, o sırada addr başka bir değere dönmüş olabilir.
- Semptom: Sadece ilk sw çalışıyor, sonra çekirdek donuyor.
- Çözüm: sel_uart_q flip-flop ile select'i request cycle'ında latch'le.
- **Bu AXI'de AWID/ARID'in çözdüğü klasik problem.**

### 2. Tasarım Kararları ve Rasyonelleri

**cv32e40p_core vs cv32e40p_top seçimi:**
- cv32e40p_top FPU wrapper içerir, fpnew_pkg paketi istiyor.
- FPU=0 olsa bile derleme başarısız.
- cv32e40p_core kullanıldı (sade çekirdek, FPU wrapper yok).

**FPU=0 kararı:**
- Hedef: int8 quantized TFLite Micro Speech.
- FPU gereksiz, alan-güç-sentez süresi kazancı.

**SystemVerilog sentetik alt küme:**
- ÖTR'de "Verilog" deniyordu.
- CV32E40P zaten SV ile yazılmış, kod tabanı tutarlılığı için SV seçildi.
- always_ff ve logic kullanımı latch hatalarını sentez öncesi yakalıyor.
- Ağır SV özellikleri (interface, dynamic arrays) kullanılmadı.

**Özel OBI decoder (pulp-platform/axi yerine):**
- pulp-platform/axi devasa, 2 kişilik takım için öğrenme maliyeti yüksek.
- Kendi dokümante edilmiş basit OBI decoder'ı kullanıldı.
- DTR'ye kadar AXI4-Lite wrapper değerlendirilecek.

---

## Şartname Minimum Ödül Kriterleri

| # | Kriter | Durum |
|---|---|---|
| 1 | FPGA + en az 2 çevre birimi koşuyor | ❌ FPGA'ya geçmedik |
| 2 | Self-checking test (Spike veya RTL) | ✅ **GPIO testi (M03)** |
| 3 | AXI Protocol Check (en az 1) | ❌ UVM yok |
| 4 | YZ hızlandırıcı en az 1 test | ❌ RTL yok |
| 5 | GDSII üretim | ❌ Final için |

**1/5 karşılandı.** DTR'ye kadar hedef: en az 3/5 (#2 ✅, #3 ve #4 eklenecek).

---

## ÖTR ile Tutarsızlıklar (DTR'de açıklanacak)

1. **RTL dili:** ÖTR "Verilog" diyor, gerçekte SystemVerilog sentetik alt
   küme kullanılıyor. Rasyonel: CV32E40P zaten SV, tip güvenliği.

2. **Bus:** ÖTR "AXI4-Lite" diyor, şu an basit OBI decoder. Rasyonel:
   kapsam kontrolü, doğrulama basitliği. AXI4-Lite wrapper DTR'ye kadar
   değerlendirilecek.

3. **Bellek haritası:** ÖTR ayrı IRAM/DRAM, şu an tek 16 KB RAM blok.
   DTR'ye kadar ÖTR haritasına yaklaştırılacak.

---

## DTR'ye Kadar Öncelikli İşler

### Mutlaka yapılması gereken (DTR puanı için kritik)

- [ ] Timer modülü + self-check test
- [ ] Dokümantasyon güncellemesi
- [ ] GitHub'a yükleme (kendi hesap, private OK)
- [ ] README dosyası (jüri tek komutla çalıştırabilmeli)
- [ ] En az 1 UVM protocol check
- [ ] Coverage raporu üretme akışı
- [ ] YZ hızlandırıcı iskelet RTL + blok diyagram
- [ ] DTR raporunun kendisi

### Güçlü olmak için

- [ ] Tam UART (EK-2 yazmaçları)
- [ ] I2C Master (basit)
- [ ] Bootloader ROM
- [ ] IRAM/DRAM ayrımı

### DTR sonrası (final için)

- [ ] QSPI Master (tam)
- [ ] Tam YZ hızlandırıcı RTL
- [ ] FPGA (Vivado, Arty A7-100T)
- [ ] Sentez + P&R + GDSII
- [ ] JTAG Debug (opsiyonel bonus)

---

## Haftalık Plan Taslağı

### Hafta 1 (25 Nis – 1 May) — Temel tamamlama
- Cts-Paz: Timer modülü + self-check
- Pzt: IRAM/DRAM ayrımı
- Sal: Dokümantasyon güncellemesi
- Çar: GitHub + README
- Per: Tam UART

### Hafta 2 (2-8 May) — Doğrulama odaklı
- Cts-Paz: UVM protocol check (GPIO agent)
- Pzt: Coverage raporu akışı
- Sal: I2C Master basit
- Çar-Per: YZ hızlandırıcı iskelet + test

### Hafta 3 (9-15 May) — DTR YAZIMI
- Cts-Paz: DTR bölüm 1-3
- Pzt: DTR bölüm 4
- Sal: DTR bölüm 5
- Çar: DTR bölüm 6
- Per: Son kontrol, commit'ler, GitHub push
- **15 May 17:00 — DTR TESLİM**
