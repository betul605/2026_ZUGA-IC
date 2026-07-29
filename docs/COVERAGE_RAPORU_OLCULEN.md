# ZUGA-IC — Ölçülen Coverage Raporu (Verilator)

**Tarih:** 28 Temmuz 2026 · **Yöntem:** Verilator `--coverage` ile **fiilen ölçülmüş** (satır + dal + toggle)
**Tekrar üret:** `./coverage/run_coverage.sh`

> Bu rapor, `docs/COVERAGE_RAPORU.md` (manuel/tahmini ~%82) belgesinin yerine geçer.
> Buradaki sayılar Verilator tarafından ölçülmüş gerçek değerlerdir; yalnızca tasarım
> RTL'i (`rtl/*.sv`) sayılır, testbench satırları hariçtir.

## Sonuçlar (ölçülen)

| Modül | Satır (line) | Dal (branch) |
|---|---|---|
| gpio_axi.sv | 8/9 · %88.9 | 7/10 · %70.0 |
| ram_axi.sv | 6/7 · %85.7 | 14/18 · %77.8 |
| timer_axi.sv | 20/28 · %71.4 | 17/20 · %85.0 |
| uart_axi.sv | 18/30 · %60.0 | 27/44 · %61.4 |
| i2c_master_axi.sv | 24/42 · %57.1 | 35/52 · %67.3 |
| yz_csr.sv | 20/46 · %43.5 | 13/24 · %54.2 |
| yz_accel.sv | 18/40 · %45.0 | 44/80 · %55.0 |
| yz_top.sv | 4/6 · %66.7 | 4/8 · %50.0 |
| **TOPLAM** | **118/208 · %56.7** | **161/256 · %62.9** |

Toggle (sinyal değişimi) toplam: 1290/5862 · %22.0

## Yorum ve hedef

Şartname/§4.3 hedefleri: **≥%95 satır, ≥%90 dal.** Şu anki ölçüm bunun altında çünkü
mevcut testbench'ler her modülü **tek/dar senaryoyla** sınıyor (hata yolları, kullanılmayan
durumlar, kenar koşulları uyarılmıyor). En düşükler: `yz_csr`, `yz_accel`, `i2c`, `uart`.

**Kapsamı yükseltme planı (yönlendirilmiş testler):**
- `yz_csr`: tüm yazmaç R/W + RO koruma + sw_reset + hata bayrakları senaryoları.
- `yz_accel`: farklı boyut/stride, ReLU negatif dal, clamp doygunluğu, sw_reset ile iptal, argmax eşitlik.
- `uart`/`i2c`: farklı baud/NBY, stop-bit, ACK/NACK, TX+RX tüm dallar.
- Ardından `run_coverage.sh` tekrar koşulur; hedefe ulaşana dek yinelenir.

## Yöntem (nasıl ölçülüyor)

Her testbench Verilator ile `--coverage` bayrağıyla derlenir; coverage'ı diske yazan
küçük bir C++ main eklenir (Verilator 5.020 otomatik main coverage yazmaz). Üretilen
`*.dat` dosyaları `verilator_coverage --write merged.dat` ile birleştirilir ve
`coverage/parse_coverage.py` yalnızca `rtl/` noktalarını sayarak yüzde üretir.
Verilator satır (`v_line`), dal (`v_branch`) ve toggle (`v_toggle`) noktaları verir.
