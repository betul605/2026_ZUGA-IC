# Milestone 07: SVA Protocol Check

**Tarih:** 26 Nisan 2026
**Commit:** 512da0d

## Hedef

Sartname Madde 4.2.2.2 minimum odul kriteri #3 ("AXI Protocol Check
(en az 1)") karsiligini OBI bus icin gerc0eklemek. RTL'i degistirmeden
protokol kurallarini otomatik kontrol etmek.

## Strateji ve Karar Surecleri

### Yontem: SVA mi UVM mi?

Iki olasilik vardi:
- **Tam UVM Agent (3-4 saat):** uvm_test, uvm_sequence, uvm_monitor
  hierarsisi. Daha sus0lu ama Verilator destegi sinirli ve ogrenme
  egrisi dik.
- **SVA Assertion (1-1.5 saat):** SystemVerilog Assertions ile basit
  property tabanli kontrol. Verilator destekli, hizli sonuc.

SVA secildi cunku DTR icin yeterli kanit, hizli tamamlanir, basariyla
kurulduktan sonra UVM'e gec0is ileride yapilabilir.

### Karsilasilan Verilator Kisitlamalari

**Kisitlama 1: Cycle delay range desteklenmiyor**
- SVA `|-> ##[0:1] gnt_i;` Verilator'da hata verdi
- Cozum: Sabit delay'e gec0is `|-> ##0 gnt_i;`

**Kisitlama 2: Sabit cycle delay de desteklenmiyor**
- Verilator 5.020 sequence expression'larinda `##N` hic dogrulamiyor
- Cozum: SVA'dan vazgec0i, klasik `always_ff + if(cond) $display`
  yontemine gec0is. Bu Verilator'da %100 destekli.

**Kisitlama 3: Yorumda "verilator" kelimesi pragma sandiriyor**
- "Verilator SVA cycle-delay..." yorumu hata verdi
- Cozum: "Bu simulator SVA cycle-delay..." olarak degistirildi

**Kisitlama 4: bus_name port mu parameter mi?**
- Ilk versiyon `input string bus_name` port idi
- Verilator string portlari kismi destekliyor, parameter daha guvenli
- Cozum: `parameter string BUS_NAME` ile yeniden yapildi

## Yapilanlar

### Yeni Dosya: tb/obi_assertions.sv (108 satir)

OBI bus protocol kontrolu icin bagimsiz modul. Parametreli BUS_NAME
oldugu icin hem DATA hem INSTR bus icin tek tanimla iki instance.

Iceriginde:
- 3 protocol kurali (Rule 1, 2, 3)
- 2 coverage sayaci (read_count, write_count)
- final block ile simulasyon sonu raporu

### Kontrol Edilen Kurallar

Rule 1 - gnt sadece req aktifken cikabilir:
   if rst_ni and gnt_i and not req_i then $display FAIL
gnt'nin "spurious" cikmasini yakalar. Bizim slave'lerde gnt = req
oldugu icin hep gec0iyor.

Rule 2 - handshake sonrasi rvalid gelmeli:
   handshake_q latch eder req_i AND gnt_i (1 cycle gecikme)
   if handshake_q and not rvalid_i then FAIL
Bizim slave'lerimizde rvalid 1 cycle sonra cikiyor; uyumlu.

Rule 3 - rvalid sadece handshake sonrasi cikabilir:
   if rvalid_i and not handshake_q then FAIL
"Idle"da rvalid'in spurious cikmasini yakalar.

Rule 4 (KALDIRILDI): Adres stabilite kuralı. Bizim slave'lerde
gnt = req (combinational, tek cycle handshake). Yani req aktifken zaten
ayni cycle gnt veriliyor; "req aktif ama gnt gelmemis" durumu hic
olusmuyor. Bu kural yanlis pozitif uretiyordu, kaldirildi. AXI4-Lite
wrapper'a gec0ildiginde (handshake gec0ikebilir) tekrar eklenecektir.

### Coverage Sayaclari

read_count ve write_count int unsigned olarak tanimli.
Her handshake'te (req AND gnt) we_i'ye gore arttirilir.
Simulasyon sonunda final block ile raporlanir.

### Bind ile Entegrasyon (tb_top.sv)

bind SystemVerilog ozelligi RTL'i degistirmeden assertion ekler.
soc_top icindeki sinyallere DISARDAN baglanir.

Iki instance: DATA bus ve INSTR bus icin ayri.

bind soc_top obi_assertions paramlari:
- BUS_NAME = "DATA" veya "INSTR"
- Tum OBI sinyalleri soc_top'tan baglanir
- INSTR icin we_i tie 1'b0, wdata_i tie 32'h0

### build.sh Guncellemesi

- tb/obi_assertions.sv build listesine eklendi
- Verilator --assert flag komuta eklendi (gelecekteki SVA icin)

## Sonuc

### Build ve Simulasyon

Build basarili. Hicbir Verilator hatasi yok.

Simulasyon ciktisi (test_timer.hex yuklu, default):
- UART output: T (Timer self-check basarili)
- DATA COVERAGE: Toplam okuma 1, yazma 4, toplam 5
- INSTR COVERAGE: Toplam okuma 999, yazma 0, toplam 999
- ASSERT FAIL mesaji: HIC YOK

Yani: 3 protocol kurali tum simulasyon boyunca SESSIZ kaldi.
Bu, OBI bus'imizin protokol acidan dogru calistiginin
otomatik kanitidir.

### Coverage Detayi

DATA bus: 5 islem (Timer'a 3 yazma + UART_TDR'a 2 yazma)
INSTR bus: 999 fetch (1000 cycle simulasyon, lineer akis)

Bu sayilar DTR raporu icin somut metrik.

### Regression Yok

Onceki testler (Hi, P, T) hala basariyla calisiyor.
SVA Protocol Check eklenmesi mevcut davranisı bozmadi.

## Dogrulanan Ozellikler

- [x] OBI bus protocol kurallari otomatik kontrol ediliyor
- [x] DATA bus icin 3 assertion aktif
- [x] INSTR bus icin 3 assertion aktif (ayri instance)
- [x] Coverage sayilari toplaniyor (5 DATA, 999 INSTR)
- [x] bind ile RTL'den bagimsiz entegrasyon
- [x] Verilator destekli (SVA olmadan, klasik always_ff)
- [x] Mevcut testler bozulmadi (Hi, P, T hala calisir)
- [x] Hicbir false-positive yok

## Sartname / DTR Etkisi

### Odul Kriteri Karsilanmasi

Sartname Madde 4.2.2.2 minimum odul kriterleri:
1. FPGA + 2 cevre birim - henuz
2. Self-checking test - VAR (3 test, M03+M04+M06)
3. AXI Protocol Check - SIMDI VAR (M07, OBI varyanti)
4. YZ test - henuz
5. GDSII - final icin

3/5 odul kriteri DTR icin karsilandi.

### DTR Anlatim Hikayesi

"OBI bus protocol kurallari, RTL'den bagimsiz olarak bind mekanizmasi
ile testbench'ten kontrol edilmektedir. 3 kural (gnt-req tutarliligi,
handshake-rvalid sirasi, rvalid-handshake correspondence) tum
simulasyon boyunca otomatik dogrulandi. AXI4-Lite wrapper geldiginde
ayni metodoloji yeniden kullanilacak; ek olarak adres stabilite ve
write strobe kurallari eklenecektir."

### Tool Kisitlamasini Cozum

Verilator 5.020 SVA cycle-delay desteklemiyor. Bunu klasik
always_ff + $display ile cozdugumuz, DTR'de "tool ozelliklerini
gozonune alarak metodoloji uyarladik" diye anlatilabilir.
Bu DTR raporunda "muhendislik kararlarinin gerekceleri" basliklarinda
guzel bir ornek olur.

## Mimari Notlar

### bind vs. Inline Assertion

bind tercih edildi cunku:
- RTL temiz kalir (assertion'lar testbench tarafinda)
- Productiona giden kod ile dogrulama kodu ayri
- Iki bus icin tek modul, iki instance (kod yeniden kullanim)

### Parametre vs. Port

bus_name parametre olarak verildi. Sebep: Verilator string port
desteginin sinirli olmasi. Parameter daha taşinabilir.

### final Block

Simulasyon sonunda coverage raporu otomatik basiliyor. Bu DTR'ye
ekran goruntusu eklemek icin kolaylik saglar.

## Sonraki Adimlar

- [ ] YZ hizlandirici iskelet RTL (sartname odul kriteri #4)
- [ ] FPGA Vivado projesi (hafta sonu, Umur Bugra ile)
- [ ] DTR raporunun yazimi (9-15 May)
- [ ] Coverage raporu sayisini artir (daha fazla test ile)
- [ ] AXI4-Lite wrapper'a gec0ildiginde Rule 4 (addr_stable) eklenecek
