#!/bin/bash
# ============================================================================
# run_coverage.sh - ZUGA-IC AXI4-Lite Coverage Suite
#
# Verilator --coverage ile fonksiyonel kapsama olcumu:
#   - Line coverage (satir kapsama)
#   - Toggle coverage (sinyal degisimi)
#
# Sartname §3.2.2 (coverage raporlari) icin somut metrik uretir.
# ============================================================================

set -e
cd "$(dirname "$0")"

echo "================================================================"
echo "ZUGA-IC Coverage Olcumu"
echo "Tarih: $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================================"
echo ""

# Coverage data dizini
COV_DIR="coverage_results"
rm -rf $COV_DIR
mkdir -p $COV_DIR

# Helper: bir test coverage modunda calistir
run_with_coverage() {
    local name="$1"
    local top="$2"
    local sources="$3"

    echo "--- Coverage: $name ---"

    local objdir="obj_dir_cov_${name}"
    rm -rf $objdir

    verilator --binary --coverage --timing -j 0 \
        --top-module $top \
        --Mdir $objdir \
        -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
        $sources > /tmp/cov_build_${name}.log 2>&1

    if [ -f "$objdir/V$top" ]; then
        ./$objdir/V$top > /tmp/cov_run_${name}.log 2>&1

        # coverage.dat dosyasini topla
        if [ -f "$objdir/coverage.dat" ]; then
            cp $objdir/coverage.dat $COV_DIR/${name}_coverage.dat
            echo "  PASS - coverage.dat toplandi"
        elif [ -f "coverage.dat" ]; then
            mv coverage.dat $COV_DIR/${name}_coverage.dat
            echo "  PASS - coverage.dat toplandi"
        else
            echo "  WARN - coverage.dat bulunamadi"
        fi
    else
        echo "  FAIL - build hatasi"
    fi
    echo ""
}

# ============================================================================
# Coverage Calismalari
# ============================================================================

run_with_coverage "ram_axi" "ram_axi_tb" \
    "tb/axi_lite_assertions.sv rtl/ram_axi.sv tb/ram_axi_tb.sv"

run_with_coverage "gpio_axi" "gpio_axi_tb" \
    "tb/axi_lite_assertions.sv rtl/gpio_axi.sv tb/gpio_axi_tb.sv"

run_with_coverage "timer_axi" "timer_axi_tb" \
    "tb/axi_lite_assertions.sv rtl/timer_axi.sv tb/timer_axi_tb.sv"

run_with_coverage "uart_axi" "uart_axi_tb" \
    "tb/axi_lite_assertions.sv rtl/uart_axi.sv tb/uart_axi_tb.sv"

run_with_coverage "i2c_master_axi" "i2c_master_axi_tb" \
    "tb/axi_lite_assertions.sv rtl/i2c_master_axi.sv tb/i2c_master_axi_tb.sv"

run_with_coverage "boot_rom_axi" "boot_rom_axi_tb" \
    "tb/axi_lite_assertions.sv rtl/ram_axi.sv tb/boot_rom_axi_tb.sv"

run_with_coverage "uart_dual_axi" "uart_dual_axi_tb" \
    "tb/axi_lite_assertions.sv rtl/uart_axi.sv tb/uart_dual_axi_tb.sv"

# ============================================================================
# Coverage Birlestirme + Rapor
# ============================================================================

echo "================================================================"
echo "COVERAGE BIRLESTIRME"
echo "================================================================"

if ls $COV_DIR/*.dat > /dev/null 2>&1; then
    verilator_coverage --write $COV_DIR/merged.dat $COV_DIR/*.dat
    echo "OK: $COV_DIR/merged.dat olusturuldu"
    echo ""

    echo "================================================================"
    echo "COVERAGE RAPOR"
    echo "================================================================"
    verilator_coverage --annotate $COV_DIR/annotated $COV_DIR/merged.dat 2>&1 | tail -20
    echo ""

    # Annotated dosya sayisi
    if [ -d "$COV_DIR/annotated" ]; then
        echo "Annotated dosyalari:"
        ls -la $COV_DIR/annotated/ | head -20
    fi
else
    echo "HATA: coverage.dat dosyasi yok"
    exit 1
fi
