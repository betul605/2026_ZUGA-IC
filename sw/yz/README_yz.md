# YZ Hızlandırıcı — Gerçek MAC Datapath (ZUGA-IC)

Bu klasör, şartname EK-1 "Tiny Conv" modelini **sabit-nokta (int8) donanım datapath'i**
olarak gerçekleyen YZ hızlandırıcının altın (golden) referans modelini ve test
vektörlerini içerir. Donanım RTL'i `rtl/yz_accel.sv`, testbench `tb/yz_accel_tb.sv`.

## Mimari
```
Reshape → DepthwiseConv2D(+ReLU, SAME padding, stride S) → FullyConnected → argmax
```
Tek (paylaşımlı) signed MAC birimi ile katmanlar sırayla hesaplanır. Tam Tiny Conv
konfigürasyonu: giriş 49×40, 8 filtre 10×8 çekirdek, stride 2, SAME padding →
25×20×8 = 4000 öznitelik → FullyConnected 4000→4 → argmax (4 sınıf).

## Sabit-nokta şeması (donanım ↔ yazılım birebir)
- conv: `acc(int32) = bias + Σ(int8_in · int8_w)` → ReLU → `acc >>> SHIFT` → clamp[0,127]
- fc:   `logit(int32) = bias + Σ(int8_act · int8_w)` (requant yok)
- argmax: en büyük logit indeksi

> Not: Bu şema TFLite'in tam requantizasyonunu birebir taklit etme iddiası taşımaz;
> amacı **donanım ile yazılım altın modeli arasında bit-bit özdeşlik** sağlamaktır
> (§5.2 #4 + EK-1 "yazılım modeline göre doğruluk" kanıtı). Gerçek eğitilmiş TFLite
> ağırlıkları aynı şema ile yüklendiğinde aynı akış çalışır.

## Çalıştırma (tek komut)
```bash
./build_yz_accel.sh          # tam Tiny Conv (49×40, 8 filtre)
./build_yz_accel.sh small    # küçük konfig (hızlı bring-up)
```
Beklenen çıktı: `===== YZ HIZLANDIRICI TEST PASSED ===== (HW == golden, bit-bit)`

## Sonuç (tam Tiny Conv, doğrulanmış)
- logit = `[27076, -28255, 48488, 18675]`, argmax = `2` — donanım ve altın model **bit-bit özdeş**
- Donanım çıkarım süresi = **344013 çevrim** (~336000 MAC + FSM ek yükü)
- Verilator lint: **0 uyarı**

## Yazılım/donanım hızlanma (ölçülen)
`sw/yz/yz_soft.c` — Tiny Conv'un **salt yazılım** (hızlandırıcısız) referansı; donanım/altın model ile
**bit-bit aynı** logit'leri üretir (`[27076, -28255, 48488, 18675]`). Ölçüm: `./sw/yz/measure_speedup.sh`

- Donanım çıkarım = **344.013 çevrim** (tb_yz_accel)
- Yazılım (rv32imc, gcc -O2): conv sınır-içi MAC = 10 komut, fc MAC = 7 komut; kesin yineleme ile
  yazılım ≈ **3.140.800 komut** (conv 285760×10 + padding 34240×5 + fc 16000×7)
- **Hızlanma ≈ 9,1×** (komut/çevrim; CPI~1,2 ile ~11×) → EK-1 ">5× hızlanma" şartı karşılanır

> Not: Bu, derlenmiş RISC-V kodundan analitik ve tekrar-üretilebilir bir tahmindir; çevrim-tam değer
> yazılımın CV32E40P çekirdeğinde koşulup çevrim sayacının okunmasıyla elde edilir (SoC sim / Vivado).

## Sonraki adımlar (yol haritası)
- SoC entegrasyonu ✅ (`yz_csr` + `yz_accel` → `yz_top` → `soc_top_axi`, CSR 0x5000_0000, veri 0x50xx_xxxx)
- Donanımlı C demosu (CPU YZ'yi sürer: MMIO yaz → START → IRQ → logit oku → UART) — SoC sim çıktısı
- MAC datapath pipeline derinliği + çift tampon (throughput artışı)
