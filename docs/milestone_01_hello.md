# Milestone 01: İlk Çalışan SoC — "Hi" mesajı
Tarih: 22 Nisan 2026
Takım: ZUGA-IC (Betül Bedir, Umur Buğra Dikmen)

## Hedef
CV32E40P RISC-V çekirdeğini Verilator'da ayağa kaldırmak,
basit bir RISC-V programı çalıştırıp memory-mapped UART üzerinden
bir karakter yazdırmak.

## Ortam
- İşletim sistemi: Ubuntu Linux
- Simülatör: Verilator 5.020
- RISC-V toolchain: xPack RISC-V GCC 13.2.0
- Çekirdek: CV32E40P (cv32e40p_core, FPU=0)

## Bellek Haritası (geçici, smoke test için)
- 0x00000000 - 0x00003FFF: RAM (16 KB, tek blok)
- 0x10000000: Memory-mapped UART (sadece write)

## Test Programı (hello.S, rv32i)
4 adet NOP (pipeline ısınması)
lui x1, 0x10000 ; UART adresi
2 adet NOP
addi x2, x0, 72 ; 'H'
sw x2, 0(x1)
NOP
addi x2, x0, 105 ; 'i'
sw x2, 0(x1)
NOP
addi x2, x0, 10 ; '\n'
sw x2, 0(x1)
NOP
loop_end: jal x0, loop_end

## Karşılaşılan Problemler ve Çözümleri

### Problem 1: cv32e40p_top FPU paketi arıyor
cv32e40p_top modülü FPU wrapper içerdiğinden fpnew_pkg paketini
arıyor. FPU=0 parametresi olsa bile derleme hata veriyor.
Çözüm: cv32e40p_core kullanıldı (sade çekirdek, FPU wrapper yok).

### Problem 2: Hex dosya formatı
objcopy veya benzeri araçların ürettiği hex'ler her satıra birden
çok word koyuyordu. Verilator $readmemh bunu tutarsız şekilde
okuyordu.
Çözüm: Python script ile her satıra tek word yazan özel dönüştürücü
yazıldı (binary → düz hex).

### Problem 3: Compressed instruction karışıklığı
rv32imc ile derlenen kod compressed (16-bit) komutlar içeriyordu.
Basit testbench 4-byte aligned okuduğu için karışıklık çıkıyordu.
Çözüm: -march=rv32i ile compressed kapatıldı.

### Problem 4: OBI instruction rdata latency
OBI protokolünde rdata, request/grant cycle'ından BİR CYCLE SONRA
dönmeli. İlk testbench combinational okuyordu, çekirdek yanlış
komutlar fetch ediyordu.
Çözüm: Testbench içinde adres latch'lendi, rdata o adres üzerinden
bir cycle sonra verildi. Çekirdek doğru komutları fetch etti.

## Sonuç
UART output: "H" (tam "Hi\n" bir sonraki milestone'da sağlanacak)

## Sonraki Adım
- SoC'yi modüler yapıya dönüştür (ram.sv, uart.sv, soc_top.sv)
- Decoder ekle (birden fazla slave'in bus'ta olabilmesi için)
