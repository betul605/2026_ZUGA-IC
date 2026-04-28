# Sartname Analizi - Kritik Bulgular (28 Nis 2026)

**Kaynak:** 2026_Cip_Tasarim_Yarismasi_Sartnamesi_v1_2.pdf
**Yarisma:** TEKNOFEST 2026 Cip Tasarim - Mikrodenetleyici Kategorisi

---

## Puan Dagilimi (Sartname 3.3.2)

Toplam Puan = 0.10*OTR + 0.15*DTR + 0.05*Sunum + 0.10*Demo
            + 0.40*Tasarim&Dogrulama + 0.20*Cip Akisi

**Onemli:** DTR sadece %15. Asil puan T&D (%40) + Cip Akisi (%20).

---

## DTR'de Istenenler (Sartname 3.2.2)

Mikrodenetleyici DTR icerigi:
- Sartnamedeki gereksinimlerin nasil gerc0eklestirildigi
- Blok diyagramlar
- Benzetim ve sentez sonuclari (ikisi de zorunlu!)
- Dogrulama/test planlari
- Test durum dokumu
- Coverage raporlari
- Ekran goruntuleri
- Git repository referanslari

**Format (Sartname 3.2):** A4, 11 punto Calibri, 1.15 satir araligi,
2.5 cm kenar, max 30 sayfa, PDF, max 60 MB, 15 May 17:00 son

---

## Min. Basari Kriterleri (Sartname 5.2)

Odul kazanim icin GEREKLI:

1. FPGA kartinda kurul testlerini gecme (FINAL'de)
2. En az 1 self-check test ile boot akisi + cevre birim programlama
3. AXI/AXI-Lite protokol check (UVM agent)
4. YZ hizlandirici en az 1 test
5. Fiziksel tasarim akisi + GDSII

---

## Bizim Eksiklerimiz (28 Nis itibariyle)

### KRITIK (DTR'de mutlaka)

- **AXI4-Lite Bus:** Bizde OBI var. Sartname AXI istiyor (4.1, EK-2)
  - Bus 'AXI-uyumlu (konfigurasyon AXI4-Lite, veri AXI4/AXI4-Lite)'
  - 'AXI dogrulamasi icin UVM kutuphanesi ve SystemVerilog HDL'
  - Min. basari kriteri #3 dogrudan ihlal
  - PLAN: OBI uzerine ince AXI4-Lite wrapper, 3-4 gun

- **Sentez Sonuclari:** DTR 3.2.2 zorunlu, biz simulator-only
  - PLAN: Hafta sonu Umur Bugra ile Vivado, 1.5 saat

- **Boot ROM + QSPI:** Sartname 4.2.2.1 net diyor
  - 'QSPI master arayuzunden non-volatile bellekten boot'
  - 'Bootloader kodu kucuk bir ROM (Orn. 512 Byte ya da 1 kB)'
  - Bizde IRAM 0x00'da direkt program (Boot ROM yok)
  - PLAN: Boot ROM 256 byte @ 0x00, IRAM 0x10000'a tasi (1.5-2 gun)
  - QSPI Master Final'e (zorunlu degil DTR'de)

- **Ekran Goruntuleri + PDF:** DTR teslim formati gerek
  - PLAN: Hafta 3'te (12-15 May) cek + pandoc ile PDF

### ONEMLI (yapabilirsek)

- **YZ Hizlandirici:** Min. basari kriteri #4
  - EK-1 detay: TFLite Micro Speech Tiny Conv
  - 30 KB SRAM, AXI master, UART-stream, interrupt
  - PLAN: Iskelet yazilabilir (3-4 gun) ama Final'de tam

- **2x UART:** YZ-stream icin
  - Mevcut uart.sv kopyalanir, 2. instance
  - PLAN: 1 gun, Hafta 2'de

### OPSIYONEL (Final'e)

- AXI agent UVM (Demo Puani icin)
- QSPI Master tam
- GDSII (31.07.2026 son)
- JTAG (+3 bonus)
- FPGA tam demo (Demo Puani icin Final'de)

---

## Yeni Yol Haritasi (DTR'ye 16 gun)

### Hafta 1 (29 Nis - 4 May)
- Car-Per-Cum: AXI4-Lite Wrapper (M17)
- Cmt-Paz: Umur Bugra ile Vivado Sentez (M18)

### Hafta 2 (5-11 May)
- Pzt-Sal: Boot ROM + Memory Map ONTR-Aynisi (M19)
- Car-Per: Test programlari yeniden derleme + regression
- Cum: 2x UART (M20, opsiyonel)

### Hafta 3 (12-15 May)
- Pzt-Sal: DTR Raporu son revizyon
- Car: Ekran goruntuleri + Mermaid PNG
- Per: pandoc ile PDF
- Cum 15 May 17:00: TESLIM

---

## DTR'de Strateji (Sunum Puani 3.3.2)

Sartname diyor:
  '**Sartnameye gore eksikliklerin acik bir sekilde anlatimi ve analizi**'

Yani eksikleri **SAKLAMAK YERINE ACIKCA ANLATMAK PUAN GETIRIYOR.**

DTR raporunda:
- Bolum 11 (Risk Analizi) yeniden duzenlenecek
- Eksikler net tablo: Madde, Sebep, Plan, Final Tarihi
- AXI gec0is rasyoneli savunulacak
- YZ + QSPI 'Final teslim' olarak isaretlenecek

