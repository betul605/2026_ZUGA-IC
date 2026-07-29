# ZUGA-IC — Durum, Yapılan Değişiklikler ve Final Planı
**Tarih:** 28 Temmuz 2026 · **Nihai teslim:** 14 Ağustos 2026 · **Kategori:** Mikrodenetleyici Tasarım

Bu belge üç soruyu yanıtlar: (1) bu çalışmada repoya ne eklendi, (2) şartname nihai tasarımda ne istiyor, (3) OpenLane ile nasıl devam edeceğiz, ne eksik, neyi tamamlayacağız.

---

## 1) Değişiklikleri GitHub'a alma

Değişiklikler `zuga_full.patch` içinde. Repo kökünde:
```bash
git checkout -b feat/yz-accel        # istege bagli
git apply zuga_full.patch
git add -A
git commit -m "YZ hizlandirici + SoC entegrasyonu + Sky130 cip akisi"
git push -u origin feat/yz-accel      # veya main
```
Uygulamadan önce görmek istersen: `git apply --stat zuga_full.patch`.

---

## 2) Bu oturumda yapılan değişiklikler (dosya dosya)

### Yeni: Gerçek YZ hızlandırıcı (kategorinin kalbi, §5.2 #4)
| Dosya | Ne yapıyor |
|---|---|
| `rtl/yz_accel.sv` | **Gerçek MAC datapath.** DepthwiseConv2D(+ReLU, SAME, stride) → FullyConnected → argmax; tek paylaşımlı signed-MAC. Sabit-nokta (int8→int32). Bellekler CPU'dan AXI ile veya (sim) dosyadan yüklenir. |
| `rtl/yz_top.sv` | **AXI4-Lite sarmalayıcı:** `yz_csr` (0x5000_0000 kontrol) + `yz_accel` + veri pencereleri (0x50xx_xxxx: input/wconv/bconv/wfc/bfc/logit). CPU yükler, START verir, DONE + kesme alır. |
| `sw/yz/gen_golden.py` | **Altın (golden) referans model** — donanımla **bit-bit özdeş** sabit-nokta; test vektörlerini + beklenen logit/argmax'ı üretir. |
| `tb/yz_accel_tb.sv` | Datapath self-checking testi (altın modele karşı). |
| `tb/yz_top_tb.sv` | **SoC-entegrasyon testi:** CPU'yu taklit eden AXI master; belleği yükler, START, DONE yoklar, logit okur, karşılaştırır. |
| `sw/yz/*.hex, yz_params.svh` | Üretilen test vektörleri + paylaşılan parametreler. |
| `build_yz_accel.sh` | Tek komut: altın model + lint + datapath testi + entegrasyon testi. |

**Doğrulanmış sonuç:** Tam Tiny Conv (49×40 → 8 filtre 10×8 s2 SAME → 25×20×8=4000 → FC→4): donanım = altın model **bit-bit** (`logit=[27076,-28255,48488,18675]`, argmax=2), 344 013 çevrim, Verilator lint 0 uyarı.

### Değişen: SoC entegrasyonu
| Dosya | Değişiklik |
|---|---|
| `rtl/soc_top_axi.sv` | `yz_top` örneği eklendi (tam Tiny Conv), adres çözücü `sel_yz` (0x50xx_xxxx), cevap mux'ları, ve **kesme çekirdeğe** bağlandı (`irq[16]` fast interrupt). |

### Yeni: Açık kaynak çip akışı (§3.3 / §5.2 #5)
| Dosya | Ne yapıyor |
|---|---|
| `asic/run_synth_sky130.sh` | Yosys ile 8 bloğu **Sky130 standart hücrelerine** sentezler; netlist + alan raporu. |
| `asic/config_openlane.json` | Tam GDSII (P&R+CTS+DRC/LVS) için OpenLane config'i. |
| `asic/README_asic.md` | Akış, doğrulanmış sonuçlar, sonraki adımlar. |
| `asic/reports/summary.md` | Alan/hücre özeti (aşağıda). |

**Doğrulanmış sentez (Sky130):** obi_to_axi_lite 2 996 µm² · gpio 1 406 · timer 10 219 · uart 9 304 · i2c 8 013 · yz_csr 10 774 · yz_accel/yz_top (küçük konfig) ~0,26 mm². 8/8 blok 0 hata.

---

## 3) Şartname nihai tasarımda ne istiyor?

**Puanlama (Mikrodenetleyici):** Tasarım&Doğrulama **%40** · Çip Akışı **%20** · DTR %15 · Demo %10 · ÖTR %10 · Sunum %5.

**§4.3 — GitHub'da olması gereken çıktılar:**
- *FPGA akışı:* tüm RTL + testbench, **başarılı sentez raporu, STA raporu, P&R raporu, bitstream.**
- *Fiziksel (ASIC) akış:* tüm RTL + testbench, **üretime hazır LEF/DEF/GDSII**, **signoff (LVS/DRC/ERC)** sonuçları, **tüm otomasyon kodları.**

**§5.2 — Ödül sıralaması için minimum kriterler (5/5 şart):**
1. FPGA'da kurulun test senaryolarının çalışması
2. En az 1 self-checking test: boot + çevre birim programlama + çalışması
3. Çevre birim + YZ {AXI} arayüzleri en az protocol-check ile doğrulanmış
4. YZ hızlandırıcı en az 1 test senaryosuyla doğrulanmış ✅ *(bu oturumda tamamlandı)*
5. Fiziksel akış tamamlanıp **üretime hazır GDSII** ⏳ *(sentez tamam; P&R→GDS OpenLane ile)*

**§3.2.3 — Kritik:** *"Tasarım çıktıları kullanılarak sunumdaki sonuçlar doğrulanacak ve uyumsuz olan gruplar elenecektir."* → Sunumda gösterilen her sonuç repoda üretilebilir olmalı.

---

## 4) Şu an nerede duruyoruz — tamam / eksik

| Alan | Durum | Not |
|---|---|---|
| RISC-V SoC (CV32E40P + AXI4-Lite çevre birimleri) | ✅ | Repoda mevcuttu |
| DDK demo testbench (eleme kapısı) | ✅ | TEST SUCCESS |
| AXI SVA protokol denetimi | ✅ | 5 assertion |
| **YZ hızlandırıcı gerçek datapath + testi** | ✅ | **Bu oturumda** — min #4 |
| **YZ'nin SoC'a entegrasyonu + kesme** | ✅ | **Bu oturumda** |
| **CPU-AXI yolu doğrulaması** | ✅ | **Bu oturumda** |
| **Sky130 sentez (çip akışı 1. aşama)** | ✅ | **Bu oturumda** |
| **Tam GDSII (P&R/DRC/LVS/STA/LEF/DEF)** | ⏳ | OpenLane ile — min #5, §4.3 |
| FPGA çıktıları (sentez/STA/P&R **raporları** + **bitstream**) repoda | ❌ | Şu an repoda yok; Vivado koşup commit edilmeli — §4.3 |
| Sistem-seviyesi test (CPU C ile uçtan uca) + **Spike ISS** | ❌ | §5.2 #2 güçlendirme, çekirdek doğrulaması |
| **Gerçek coverage** (ölçülmüş) | ❌ | Şu an elle tahmin; Verilator ile ölçülmeli |
| QSPI Master + gerçek flash boot | ❌ | ÖTR'de söz verildi |
| Yazılım hızlanma bazı (≈5× kanıtı) | ❌ | RISC-V yazılımla ölçülecek |
| Repo ↔ DTR ↔ sunum tutarlılığı | ⚠️ | DTR'deki üretilemeyen iddialar (5,4×/logit, Nexys foto, UVM, ölçülmüş coverage) gerçeğe göre düzeltilmeli — §3.2.3 eleme riski |
| Final sunumu + demo | ❌ | Son hafta |
| JTAG (+3 bonus) | ❌ | Opsiyonel |

---

## 5) OpenLane ile devam — evet, neden, nasıl

**Evet, GDSII'yi OpenLane ile üreteceğiz.** Sentez aşamasını Yosys+Sky130 ile bu repoda kanıtladık; fiziksel akış (floorplan → yerleştirme → CTS → yönlendirme → DRC/LVS → GDSII) için OpenLane, OpenROAD+Magic+netgen araçlarını ve sky130 PDK'yı bir arada verir. (Bu sandbox'ta docker daemon kapalı olduğu için tam akışı burada koşamadım; config hazır.)

**Adım adım (senin makinende / DDK sunucusunda):**
1. OpenLane kur (docker'lı klasik OpenLane veya `pip install openlane` — OpenLane2).
2. `asic/config_openlane.json` ile **önce tek bir çevre birimi** (varsayılan `i2c_master_axi`) koş → temiz bir GDSII + DRC/LVS + STA raporu al (hızlı ilk başarı).
3. `DESIGN_NAME`/`VERILOG_FILES`'ı değiştirip diğer blokları (gpio/timer/uart/yz_csr) koş.
4. `yz_top`/tam SoC için: `SYNTH_DEFINES=SYNTHESIS`; tam Tiny Conv bellekleri için **SRAM makroları** (OpenRAM/sky130) ekle; cv32e40p çekirdeğini de dahil et.
5. Üretilen `results/final/gds/*.gds` + `reports/` (STA/DRC/LVS) çıktılarını **repoya commit et** (§4.3 zorunlu).

---

## 6) Kalan işler ve önerilen sıra (14 Ağustos'a)

**P0 (eleme/minimum kriter):**
- OpenLane ile en az bir bloğun **GDSII + DRC/LVS**'ini üret (min #5) → sonra kapsamı büyüt.
- DDK'ya sor: ticari araç/PDK/sunucu erişimi + kesin teslim tarihi.
- Repo ↔ sunum tutarlılığı: üretilemeyen iddiaları gerçeğe çek (dürüstlük §3.3.2'de puan da kazandırıyor).

**P1 (%40 gövdesi):**
- Sistem-seviyesi test (CPU C: YZ'ye veri yaz → START → ISR'de logit oku → UART'tan yaz) + Spike ISS karşılaştırması.
- Gerçek coverage ölçümü (Verilator) + yönlendirilmiş testlerle yükseltme.
- Yazılım hızlanma bazı (aynı çıkarımı RISC-V'de koş, çevrim say).

**P2:**
- FPGA akışını yeniden koş, **raporları + bitstream'i repoya** koy (§4.3); Arty/Nexys tutarlılığını netle.
- QSPI Master + gerçek boot.

**P3 (zaman kalırsa):** JTAG (+3 bonus), UVM protocol-check.

**Son hafta:** Final sunumu (eksik analizi dahil) + demo + repo freeze (14 Ağu 23:59; sunum 17:00).
