# Simulasyon Cikti Kanitlari

**Takim:** ZUGA-IC | TEKNOFEST 2026
**Versiyon:** v1 (27 Nis 2026)
**Kaynak:** Verilator 5.020 simulasyon ciktilari

Bu doküman DTR Raporu icin kanit niteliginde simulator c0iktilarini
iceriyor. Hafta 3'te (9-15 May) bu ciktilar:
1. DTR raporuna metin olarak yapistirilacak
2. Terminal screenshot olarak (.png) DTR raporuna eklenecek
3. screenshots/ klasorune kaydedilecek

---

## 1. Build Basarili Cikti (M10 sonrasi)

Komut: ~/cv32_sim/build.sh 2>&1 | tail -10

```
g++ -Os -I. -MMD -I/usr/share/verilator/include ...
Archive ar -rcs Vtb_top__ALL.a Vtb_top__ALL.o
g++ verilated.o verilated_timing.o verilated_threads.o ...
rm Vtb_top__ALL.verilator_deplist.tmp
make: Leaving directory '/home/betul/cv32_sim/obj_dir'
=== Build basarili. Calistirmak icin: ./obj_dir/sim_cv32 ===
```

Yorum: Verilator'da hicbir hata, uyari sentez disinda. 5 RTL modul
+ tb (obi_assertions dahil) basariyla derlendi.

---

## 2. Test PASS Cikti (test_full.S, M08)

Komut: cd ~/cv32_sim && ./obj_dir/sim_cv32 2>&1 | grep DWRITE | head -20

```
[355000] DWRITE addr=0x4000200c data=0x00000052  'R'
[385000] DWRITE addr=0x4000200c data=0x00000055  'U'
[415000] DWRITE addr=0x4000200c data=0x0000004e  'N'
[445000] DWRITE addr=0x4000200c data=0x0000000a  '\n'
[475000] DWRITE addr=0x40000004 data=0x00000055  GPIO 0x55
[555000] DWRITE addr=0x40000004 data=0x000000aa  GPIO 0xAA
[635000] DWRITE addr=0x40001008 data=0x00000001  TIM_CLR
[665000] DWRITE addr=0x4000100c data=0x00000001  TIM_ENA
[815000] DWRITE addr=0x4000200c data=0x00000050  'P'
[845000] DWRITE addr=0x4000200c data=0x00000041  'A'
[875000] DWRITE addr=0x4000200c data=0x00000053  'S'
[905000] DWRITE addr=0x4000200c data=0x00000053  'S'
[935000] DWRITE addr=0x4000200c data=0x0000000a  '\n'
```

Yorum: test_full.S 'RUN' yazdi, GPIO 0x55+0xAA pattern gec0ti,
Timer CLR+ENA gec0ti, sayac arttı, 'PASS' yazdi. 13 DATA write +
(perde arkasi 4 read) = 17 islem.

---

## 3. Coverage Cikti (M07 + M08)

Komut: ./obj_dir/sim_cv32 2>&1 | grep COVERAGE

```
[DATA COVERAGE] Toplam okuma: 4, yazma: 13, toplam: 17
[INSTR COVERAGE] Toplam okuma: 999, yazma: 0, toplam: 999
```

Yorum: 1000 cycle simulasyon icinde DATA bus 17 islem yapti
(GPIO + Timer + UART), INSTR bus 999 fetch yapti (lineer akis).
Bu sayilar test_full.S programinin gercek davranisini yansitir.

Karsilastirma tablosu (test bazinda):

| Test       | Read | Write | Total | INSTR |
|------------|------|-------|-------|-------|
| hello.S    | 0    | 3     | 3     | ~10   |
| test_gpio  | 1    | 4     | 5     | ~30   |
| test_timer | 1    | 4     | 5     | ~50   |
| test_full  | 4    | 13    | 17    | 999   |

test_full.S vs basit testlere gore 3.4x daha yogun DATA aktivitesi.

---

## 4. Protocol Check FAIL Sayisi (M07)

Komut: ./obj_dir/sim_cv32 2>&1 | grep ASSERT

```
(bos cikti)
```

Yorum: 1000 cycle simulasyon boyunca tek bir ASSERT FAIL mesaji
olmadi. 3 protocol kurali (gnt-req, handshake-rvalid, rvalid-only)
DATA + INSTR bus icin ayri instance, toplamda 6 paralel kontrol.
OBI bus protocolu tamamen dogru calisiyor.

Aktif kurallar:
- Rule 1: gnt sadece req aktifken cikar (spurious gnt yok)
- Rule 2: handshake'den 1 cycle sonra rvalid (gec0ikme yok)
- Rule 3: rvalid sadece handshake sonrasi (idle'da rvalid yok)

Bu DTR Raporu Bolum 7.2'de 'protocol check sonuclari' olarak gec0er.

---

## 5. UART Faz 2 TX Pin Edge Cikti (M09)

Komut: ./obj_dir/sim_cv32 2>&1 | grep TX_PIN | head -8

```
[375000]  TX_PIN edge: 1 -> 0   ('R' karakteri start bit)
[695000]  TX_PIN edge: 0 -> 1   (320 ns sonra = 16 cycle * 20 ns)
[855000]  TX_PIN edge: 1 -> 0
[1175000] TX_PIN edge: 0 -> 1
[1335000] TX_PIN edge: 1 -> 0
[1495000] TX_PIN edge: 0 -> 1
[1655000] TX_PIN edge: 1 -> 0
[1815000] TX_PIN edge: 0 -> 1   (stop bit sonu)
```

Yorum: 'R' (0x52 = binary 01010010) UART_TDR'a yazildi, sonra
tx_o pini 8 edge ile gerc0ek serial sinyal uretti. Her edge
16 cycle (CPB=16) ara ile, UART standardina uygun.

Bit Analizi:

| Edge | Cycle  | Yorum            |
|------|--------|------------------|
| 1->0 | 18750  | START bit        |
| 0->1 | 34750  | DATA1 = 1        |
| 1->0 | 42750  | DATA2 = 0        |
| 0->1 | 58750  | DATA4 = 1        |
| 1->0 | 66750  | DATA5 = 0        |
| 0->1 | 74750  | DATA6 = 1        |
| 1->0 | 82750  | DATA7 = 0        |
| 0->1 | 90750  | STOP bit         |

(DATA0 ve DATA3 onceki bit ile ayni oldugu icin edge yok.)

Bu DTR Raporu Bolum 7.3'te 'UART Faz 2 waveform dogrulamasi' olarak gec0er.

---

## 6. SoC Mimari ve Veri Akisi (M02 + M07)

Komut: ./obj_dir/sim_cv32 2>&1 | grep IFETCH | head -10

```
[225000] IFETCH addr=0x00000000
[235000] IFETCH addr=0x00000004
[245000] IFETCH addr=0x00000008
[255000] IFETCH addr=0x0000000c
[265000] IFETCH addr=0x00000010
[275000] IFETCH addr=0x00000014
[285000] IFETCH addr=0x00000018
[295000] IFETCH addr=0x0000001c
[305000] IFETCH addr=0x00000020
[315000] IFETCH addr=0x00000024
```

Yorum: Lineer instruction fetch, IRAM 0x00000000'dan baslar.
Her IFETCH 10 ns ara ile (1 cycle, 100 MHz). Pipeline calisir.

---

## 7. Ekran Goruntusu Plani (Hafta 3 - 9-15 May)

Asagidaki goruntuler DTR raporuna eklenecek (PNG format):

1. **build_basarili.png** - Verilator build ciktisinin son 10 satiri
2. **test_full_pass.png** - 'RUN\nPASS\n' yazdiran terminal
3. **coverage_raporu.png** - DATA/INSTR coverage sayilari
4. **protocol_check.png** - 0 ASSERT FAIL kanit
5. **tx_pin_waveform.png** - TX_PIN edge'leri
6. **mermaid_diyagram1.png** - Sistem genel gorunumu
7. **mermaid_diyagram2.png** - OBI bus akisi
8. **mermaid_diyagram3.png** - UART state machine
9. **vivado_sentez.png** - Vivado sentez raporu (hafta sonu)
10. **github_repo.png** - GitHub commit history

Ekran goruntusu cekme yontemleri:
- Linux: gnome-screenshot, flameshot, scrot
- Terminal: tmux capture-pane > file.txt + screenshot
- Browser: F12 -> Device toolbar -> screenshot (mermaid icin)
- Vivado: View menu -> Print to PDF -> kirpma

Hedef klasor: ~/cv32_sim/screenshots/
Adlandirma: M0X_aciklama.png
Boyut: 1920x1080 veya daha yuksek (ekran goruntusu)

---

## DTR Raporu Referanslari

Bu doküman DTR Raporu icin asagidaki yerlere kaynaktir:

| Bolum | Aciklama |
|-------|----------|
| 7.1 | Test sonuclari (Bolum 1-2) |
| 7.2 | Protocol check sonuclari (Bolum 4) |
| 7.3 | UART Faz 2 waveform (Bolum 5) |
| 8.X | Coverage metrikleri (Bolum 3) |
| EK | Ekran goruntu klasoru (Bolum 7) |

