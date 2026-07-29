#!/usr/bin/env bash
# ============================================================================
# build_yz_accel.sh -- YZ Hizlandirici self-checking cikarim testi (§5.2 #4)
#
# Altin modeli uretir, RTL'i derler, self-checking testbench'i kosar.
# Kullanim:
#   ./build_yz_accel.sh            # tam Tiny Conv (49x40, 8 filtre) - varsayilan
#   ./build_yz_accel.sh small      # kucuk konfig (hizli bring-up)
#
# Cikis: "YZ HIZLANDIRICI TEST PASSED" -> exit 0,  aksi -> exit 1
# ============================================================================
set -e
CFG="${1:-full}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> [1/3] Altin model uretiliyor (sw/yz/gen_golden.py $CFG)"
python3 sw/yz/gen_golden.py "$CFG"

echo "==> [2/3] Verilator lint (rtl/yz_accel.sv)"
if command -v verilator >/dev/null 2>&1; then
    verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDPARAM --timing rtl/yz_accel.sv \
        && echo "    lint TEMIZ (0 uyari)"
else
    echo "    (verilator yok - lint atlandi)"
fi

echo "==> [3/4] Datapath testi (iverilog): tb_yz_accel"
iverilog -g2012 -I sw/yz -s yz_accel_tb -o /tmp/yz_accel.vvp \
         rtl/yz_accel.sv tb/yz_accel_tb.sv
vvp /tmp/yz_accel.vvp | tee /tmp/yz_accel.log

echo
echo "==> [4/4] SoC-entegrasyon testi (CPU AXI yolu): tb_yz_top"
iverilog -g2012 -I sw/yz -s yz_top_tb -o /tmp/yz_top.vvp \
         rtl/yz_csr.sv rtl/yz_accel.sv rtl/yz_top.sv tb/yz_top_tb.sv
vvp /tmp/yz_top.vvp | tee /tmp/yz_top.log

echo
P1=$(grep -c "YZ HIZLANDIRICI TEST PASSED" /tmp/yz_accel.log || true)
P2=$(grep -c "YZ SOC ENTEGRASYON TESTI PASSED" /tmp/yz_top.log || true)
if [ "$P1" = "1" ] && [ "$P2" = "1" ]; then
    echo "SONUC: PASS (datapath + SoC entegrasyon)"
    exit 0
else
    echo "SONUC: FAIL"
    exit 1
fi
