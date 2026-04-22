# ZUGA-IC Projesi — Güncel Durum

Son güncelleme: 22 Nisan 2026

## Tamamlanan İşler
- [x] CV32E40P Verilator'da derlenip çalışıyor
- [x] OBI instruction + data port doğru protokolle
- [x] Modüler SoC yapısı (ram, uart, soc_top ayrı)
- [x] Adres decoder (UART vs RAM)
- [x] Memory-mapped I/O ("Hi\n" UART'tan basıldı)
- [x] Git repo (iki milestone commit)
- [x] Reproducible build (build.sh)

## Devam Eden İşler
- [ ] (henüz yok)

## Yapılacaklar — Kısa vade (Bu hafta)
- [ ] GPIO modülü (ÖTR EK-2 uyumlu: IDR, ODR yazmaçları)
- [ ] Timer modülü (32-bit sayaç, prescaler)
- [ ] Memory map'i ÖTR adreslerine yaklaştır
- [ ] IRAM ve DRAM'i ayır (şu an tek bir RAM)

## Yapılacaklar — Orta vade (2-3 hafta)
- [ ] Gerçek UART (CPB, STP, RDR, TDR, CFG)
- [ ] I2C Master
- [ ] QSPI Master + Flash simülasyon modeli
- [ ] Bootloader ROM + boot akışı
- [ ] Basit AXI4-Lite wrapper (ÖTR ile tutarlılık için)

## Yapılacaklar — Uzun vade (DTR sonrası)
- [ ] YZ hızlandırıcı (Tiny Conv, int8 MAC)
- [ ] UVM protocol check (en az bir AXI agent)
- [ ] Vivado FPGA projesi (Arty A7-100T)
- [ ] Fiziksel tasarım (GDSII çıkışı)

## ÖTR ile Tutarsızlıklar
Bunlar DTR'de açıklanmalı:
1. RTL dili: ÖTR "Verilog" diyor, gerçekte SystemVerilog
   sentetik alt kümesi kullanılıyor (CV32E40P zaten SV).
2. Bus: ÖTR AXI4-Lite diyor, şu an basit OBI decoder var.
   DTR'ye kadar AXI4-Lite adaptasyonu değerlendirilecek.
3. Bellek haritası: ÖTR ayrı IRAM/DRAM, şu an tek RAM blok.

## Kritik Kararlar ve Rasyoneller
- cv32e40p_core vs cv32e40p_top: FPU wrapper bağımlılığı
  olmasın diye core seçildi.
- FPU=0: int8 quantized AI kullanılacağından FPU gereksiz;
  alan, güç ve sentez süresi kazancı.
- Kendi basit bus/decoder: pulp-platform/axi devasa ve
  2 kişilik takım için öğrenme eğrisi uygun değil; kontrol
  edilebilir, dokümante edilmiş özel bus tercih edildi.
- SystemVerilog: always_ff ve logic kullanımı latch
  hatalarını sentez öncesi yakalıyor; 2 kişilik ekipte
  debug süresini azaltıyor.

## Karşılaşılan Önemli Bug'lar (DTR'de anlatılacak)
1. Hex dosyası formatı - Python script ile düzeltildi
2. Compressed instruction karışıklığı - -march=rv32i
3. OBI rdata latency - adres latch'leme
4. OBI bus select-latch (KRİTİK) - sel_q flip-flop

## Araç/Kütüphane Envanteri
- Verilator 5.020
- xPack RISC-V GCC 13.2.0
- CV32E40P (OpenHW Group, cv32e40p_core + bhv)
- Ubuntu Linux
- Git, Make, Bash, Python3

## Takım Bilgileri
- Takım Adı: ZUGA-IC
- Danışman: Fatih Gül
- Üyeler: Umur Buğra Dikmen (Kaptan), Betül Bedir
- Üniversite: Recep Tayyip Erdoğan Üniversitesi (EEM)d
