# Demo Degerlendirme Raporu - ZUGA-IC

- Tarih: 2026-09-15T18:51:22+03:00
- Harness surumu: 1.0.1
- Konfigurasyon kaynagi: `team_icd.json`
- Etkin konfigurasyon: `config_used.json` (SHA256 `fd2f9f81f3811a4d`)
- Veri seti: demo_vectors/manifest.csv | seed: 1337
- Arayuzler: stream `/dev/ttyUSB2@115200`, core `/dev/ttyUSB1@115200`

## 1. Ozet - RTL / Golden Model Uyumu

> **Olculen sey modelin dogrulugu degil, tasarimin golden modele sadakatidir.**
> Birincil olcut, donanimin urettigi sinifin golden modelin ayni vektor icin
> urettigi sinifla ayni olmasidir. Gercek etiket (truth) yalnizca bilgi
> amaciyla raporlanir ve puanlamada kullanilmaz.

| Metrik | Deger |
|---|---|
| Gonderilen ornek | 4 |
| Golden referansi olan | 4 |
| Yanitlanan | 0 |
| **Golden ile uyum** | -  (0/0) |
| Uyusmazlik | 0 |
| Zaman asimi (referansli ornek) | 4 |
| Uyum (zaman asimlari da hata sayilirsa) | 0.00 % |
| Saglamlik senaryolari | 0 / 0 |

> Not: gecikme, cerceve yaziminin bittigi an ile sonuc satirinin son baytinin
> alindigi an arasidir; UART aktarim ve ISR suresini icerir. Saf hizlandirici
> cevrim sayisi icin RTL simulasyon capraz kontrolu esastir.

## 2. Uyum Matrisi (satir = golden referans, sutun = donanim ciktisi)

| golden \ donanim | silence | unknown | yes | no | TIMEOUT |
|---|---|---|---|---|---|
| **silence** | **0** | 0 | 0 | 0 | 0 |
| **unknown** | 0 | **0** | 0 | 0 | 0 |
| **yes** | 0 | 0 | **0** | 0 | 4 |
| **no** | 0 | 0 | 0 | **0** | 0 |

Kosegen = golden ile ayni sinif. Kosegen disi her hucre, RTL'in golden
modelden ayristigi bir ornektir.

### Bilgi amacli: gercek etikete (truth) gore dogruluk

_Bu bolum puanlamada KULLANILMAZ; veri setinin zorlugu hakkinda fikir verir._

| | Dogruluk |
|---|---|
| Golden model (yazilim) | 100.00 % |

## 3. Saglamlik Senaryolari (Secenek F)

| Senaryo | Sonuc | Aciklama |
|---|---|---|

## 4. Golden Modelden Ayrisan Ornekler

| # | ornek | golden | donanim | truth (bilgi) | skor hata (%) | gecikme (ms) |
|---|---|---|---|---|---|---|
| 0 | vec_yes | yes | TIMEOUT | yes | - | - |
| 1 | vec_yes | yes | TIMEOUT | yes | - | - |
| 2 | vec_yes | yes | TIMEOUT | yes | - | - |
| 3 | vec_yes | yes | TIMEOUT | yes | - | - |

## 5. Dosyalar

- `samples.csv` - ornek bazli ham kayit ve skor hata bilgisi
- `robustness.csv` - senaryo sonuclari
- `summary.json` - makine okunabilir ozet
- `transcript.log` - core UART ham ciktisi
- `config_used.json` - kosumda gercekten kullanilan etkin ICD
