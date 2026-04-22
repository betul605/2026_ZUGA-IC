# Milestone 02: Modüler SoC + OBI Select Latch Düzeltmesi
Tarih: 22 Nisan 2026 (aynı gün)

## Hedef
Dağınık testbench kodunu modüler SoC yapısına dönüştürmek;
her bileşeni ayrı dosyada tutmak.

## Yapılan Değişiklikler

### Yeni dosya yapısı
- rtl/ram.sv: Dual-port RAM (OBI arayüzlü)
- rtl/uart_primitive.sv: Memory-mapped UART (basit, $write ile)
- rtl/soc_top.sv: Üst modül — çekirdek + bellekler + decoder
- tb/tb_top.sv: Sade testbench (clock, reset, izleme)

### Bus yapısı
Basit bir adres decoder eklendi:
- addr[31:28] == 4'h1 → UART modülüne yönlendir
- aksi durumda → RAM data portuna yönlendir

## Karşılaşılan Problemler ve Çözümleri

### Problem 1: repeat(800) Verilator 5.x'te beklendiği gibi çalışmıyor
repeat(N) @(posedge clk) kullanımı erken bitiyor
(büyük ihtimalle timing mode özelliği).
Çözüm: flip-flop içinde cycle sayacı ile $finish.

### Problem 2: OBI bus select-latch bug'ı (KRİTİK)
SoC decoder'ı data_rvalid'i current data_addr'a göre mux'lıyordu.
Ancak rvalid request'ten bir cycle sonra gelir ve o cycle'da
data_addr başka bir değere dönmüş olabilir.
Semptom: Çekirdek ilk sw'den sonra donuyordu
(sadece 'H' yazıyor, 'i' ve '\n' yok).
Teşhis: Debug trace ile instruction fetch'in durduğu görüldü.
Çözüm: sel_uart_req sinyali request cycle'ında flip-flop ile
latch'lenip (sel_uart_q), rvalid path'inde bu latch kullanıldı.

Bu OBI/AXI protokollerinde klasik bir tasarım tuzağıdır.
Gerçek AXI'de bu sorun transaction ID (AWID/ARID) ile çözülür;
bizim basit OBI bus'ımızda select'i latch'lemek aynı işi yapar.

## Sonuç
UART output: "Hi\n" (H, i, newline — tamamen doğru sıralamada)
Program loop_end'e girip sonsuz döngüye düştü (beklenen davranış).

## Git referansı
Commit: 221d4b0

## Sonraki Adım
- Gerçek UART modülü (ÖTR EK-2 yazmaç haritasına göre)
- GPIO modülü (ilk gerçek çevre birim)
- Memory map'i ÖTR hedefine yaklaştırd
