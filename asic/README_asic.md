# ZUGA-IC — Açık Kaynak ASIC / Çip Akışı (SkyWater 130 nm)

Bu klasör, şartname §3.3 (Çip Tasarım Akışı, %20) ve §5.2 #5 (üretime hazır GDSII —
minimum ödül kriteri) için **açık kaynak** çip akışını içerir. DDK'nın sağlayacağı
ticari araç + PDK geldiğinde aynı RTL bu akıştan ticari akışa taşınır; buradaki
çalışma hem **öncül prova** hem de "GDSII'nin DDK'ya bağlı olmadığının" kanıtıdır.

## Akışın aşamaları
```
RTL → [Yosys sentez → Sky130 std hücre] → [OpenROAD floorplan/P&R/CTS] → [Magic DRC / netgen LVS] → GDSII
       ^ bu klasörde çalışır (sandbox)      ^ OpenLane ile takım makinesinde
```

## 1) Sentez (bu repoda çalışır — tekrar üretilebilir)
Gerçek Sky130 liberty ile Yosys sentezi:
```bash
export SKY130_LIB=/yol/sky130_fd_sc_hd__tt_025C_1v80.lib   # volare veya ORFS platform lib
./asic/run_synth_sky130.sh
```
Her blok için `asic/netlists/<blok>_sky130.v` (gate-level netlist) ve
`asic/reports/<blok>_area.txt` üretir; özet `asic/reports/summary.md`.

### Doğrulanmış sentez sonuçları (Sky130, sky130_fd_sc_hd)
| Blok | Hücre | Alan (µm²) |
|---|---:|---:|
| obi_to_axi_lite | 206 | 2 996 |
| gpio_axi | 110 | 1 406 |
| timer_axi | 987 | 10 219 |
| uart_axi | 756 | 9 304 |
| i2c_master_axi | 657 | 8 013 |
| yz_csr | 780 | 10 774 |
| yz_accel (küçük konfig) | 22 362 | 254 861 |
| yz_top (küçük konfig) | 22 342 | 259 630 |

> Not: `yz_accel`/`yz_top` burada **küçük konfig** ile sentezlenir; tam Tiny Conv
> ağırlık/ara bellekleri (input 1960, wfc 16000 …) gerçek akışta **SRAM makrosu**
> olur (standart-hücre FF değil), dolayısıyla alanları çok daha küçüktür.

## 2) Tam GDSII (P&R + DRC/LVS) — OpenLane ile (takım makinesi / DDK sunucusu)
Sandbox'ta OpenROAD/Magic ikili araçları yoktu; tam fiziksel akış OpenLane ile koşulur:
```bash
# OpenLane kurulu bir makinede (docker veya OpenLane2):
#   config_openlane.json içindeki DESIGN_NAME/VERILOG_FILES ile
./flow.tcl -design /yol/2026_ZUGA-IC/asic         # klasik OpenLane
# veya
openlane asic/config_openlane.json                # OpenLane2
```
Çıktılar `runs/<tag>/`: `results/final/gds/` (GDSII), `reports/` (STA, DRC, LVS).
`config_openlane.json` varsayılan olarak `i2c_master_axi` bloğunu hedefler; diğer
bloklar için `DESIGN_NAME` + `VERILOG_FILES` değiştirin.

## 3) Sıradaki adımlar
- **STA**: OpenSTA/OpenROAD ile setup/hold; hedef saat 50 MHz (20 ns) — `CLOCK_PERIOD`.
- **SRAM makroları**: tam Tiny Conv bellekleri için OpenRAM/sky130 SRAM; `EXTRA_LEFS/LIBS`.
- **Tam SoC**: cv32e40p + tüm çevre birimleri tek blok olarak (çekirdek std-hücre + SRAM makro).
- **Ticari akış**: DDK PDK/araç gelince Yosys→DC/Genus, OpenROAD→Innovus/ICC2 eşlemesi.

## Araç sürümleri (kanıt)
- Yosys 0.33 · Sky130 PDK: `sky130_fd_sc_hd__tt_025C_1v80` (OpenROAD-flow-scripts platform lib)
- Sentez SystemVerilog: `-DSYNTHESIS` (sim-only `$readmemh`/string parametreler devre dışı)
