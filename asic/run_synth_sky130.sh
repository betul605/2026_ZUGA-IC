#!/usr/bin/env bash
# ============================================================================
# run_synth_sky130.sh -- ZUGA-IC acik kaynak ASIC akisi: SENTEZ asamasi
#
# Yosys ile RTL bloklarini SkyWater 130nm (sky130_fd_sc_hd) standart hucrelerine
# sentezler; her blok icin gate-level netlist + alan/hucre raporu uretir.
# Bu, cip akisinin 1. asamasidir (sartname §3.3 / §4.1). P&R + DRC/LVS + GDSII
# icin asic/config_openlane.json ile OpenLane kullanilir (asic/README_asic.md).
#
# GEREKSINIM: sky130 liberty dosyasi. Yolu env ile verin:
#   export SKY130_LIB=/yol/.../sky130_fd_sc_hd__tt_025C_1v80.lib
# (volare:  volare enable --pdk sky130 ;  veya OpenROAD-flow-scripts platform lib)
#
# Kullanim:  ./asic/run_synth_sky130.sh
# ============================================================================
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p asic/netlists asic/reports

if [ -z "$SKY130_LIB" ] || [ ! -f "$SKY130_LIB" ]; then
    echo "HATA: SKY130_LIB ayarli degil veya dosya yok."
    echo "  export SKY130_LIB=/yol/sky130_fd_sc_hd__tt_025C_1v80.lib"
    exit 1
fi
echo "Liberty: $SKY130_LIB"

SUMMARY=asic/reports/summary.md
echo "# ZUGA-IC Sky130 Sentez Ozeti"            >  "$SUMMARY"
echo ""                                          >> "$SUMMARY"
echo "| Blok | Hucre | Alan (um^2) |"            >> "$SUMMARY"
echo "|---|---:|---:|"                            >> "$SUMMARY"

synth_one() {
    local top=$1; shift; local files="$*"
    yosys -q -p "
        read_verilog -sv -DSYNTHESIS $files
        hierarchy -top $top
        synth -flatten -top $top
        dfflibmap -liberty $SKY130_LIB
        abc -liberty $SKY130_LIB
        opt_clean
        write_verilog asic/netlists/${top}_sky130.v
        tee -o asic/reports/${top}_area.txt stat -liberty $SKY130_LIB
    " 2> asic/reports/${top}_err.txt
    local area=$(grep -E "Chip area" asic/reports/${top}_area.txt | tail -1 | grep -oE "[0-9.]+$")
    local cells=$(grep -E "Number of cells" asic/reports/${top}_area.txt | tail -1 | grep -oE "[0-9]+$")
    printf "| %s | %s | %s |\n" "$top" "$cells" "$area" >> "$SUMMARY"
    printf "  %-16s hucre=%-7s alan=%s um^2\n" "$top" "$cells" "$area"
}

echo "=== ZUGA-IC bloklari Sky130 sentezi ==="
synth_one obi_to_axi_lite rtl/obi_to_axi_lite.sv
synth_one gpio_axi        rtl/gpio_axi.sv
synth_one timer_axi       rtl/timer_axi.sv
synth_one uart_axi        rtl/uart_axi.sv
synth_one i2c_master_axi  rtl/i2c_master_axi.sv
synth_one yz_csr          rtl/yz_csr.sv
synth_one yz_accel        rtl/yz_accel.sv
synth_one yz_top          "rtl/yz_csr.sv rtl/yz_accel.sv rtl/yz_top.sv"

echo ""
echo "Ozet: $SUMMARY"
cat "$SUMMARY"
echo ""
echo "NOT: yz_accel/yz_top burada KUCUK konfig ile sentezlenir; tam Tiny Conv"
echo "     agirlik/ara bellekleri gercek akista SRAM makrosu olur (FF degil)."
echo "P&R + DRC/LVS + GDSII icin: asic/README_asic.md (OpenLane)."
