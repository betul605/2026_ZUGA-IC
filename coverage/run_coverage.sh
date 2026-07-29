#!/usr/bin/env bash
# ============================================================================
# run_coverage.sh -- ZUGA-IC GERCEK coverage olcumu (Verilator, olculmus)
# Her testbench'i --coverage ile derler/kosar, coverage yazan ozel main ekler,
# birlestirir ve satir/dal/toggle yuzdesini raporlar (yalnizca rtl/ tasarim).
# Kullanim: ./coverage/run_coverage.sh
# ============================================================================
set +e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
CD="$ROOT/coverage"; rm -rf "$CD/obj_"* "$CD"/*.dat "$CD"/main_*.cpp
mkdir -p "$CD"
run() { local name="$1" top="$2"; shift 2; local srcs="$*"
  cat > "$CD/main_$name.cpp" <<EOF
#include "verilated.h"
#include "verilated_cov.h"
#include "V$top.h"
int main(int argc,char**argv,char**){const std::unique_ptr<VerilatedContext> c{new VerilatedContext};
c->commandArgs(argc,argv);const std::unique_ptr<V$top> t{new V$top{c.get()}};
while(!c->gotFinish()){t->eval();if(!t->eventsPending())break;c->time(t->nextTimeSlot());}
t->final();c->coveragep()->write("$CD/$name.dat");return 0;}
EOF
  verilator --cc --exe --build --timing --coverage -j 0 --top-module $top --Mdir "$CD/obj_$name" \
    -Wno-fatal -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE -Wno-WIDTH -Wno-TIMESCALEMOD \
    -Isw/yz $srcs "$CD/main_$name.cpp" > "$CD/build_$name.log" 2>&1
  if [ -f "$CD/obj_$name/V$top" ]; then "$CD/obj_$name/V$top" > "$CD/run_$name.log" 2>&1
     [ -f "$CD/$name.dat" ] && echo "  OK $name" || echo "  NODAT $name"
  else echo "  BUILDFAIL $name"; fi
}
run gpio    gpio_axi_tb       tb/axi_lite_assertions.sv rtl/gpio_axi.sv tb/gpio_axi_tb.sv
run timer   timer_axi_tb      tb/axi_lite_assertions.sv rtl/timer_axi.sv tb/timer_axi_tb.sv
run uart    uart_axi_tb       tb/axi_lite_assertions.sv rtl/uart_axi.sv tb/uart_axi_tb.sv
run i2c     i2c_master_axi_tb tb/axi_lite_assertions.sv rtl/i2c_master_axi.sv tb/i2c_master_axi_tb.sv
run ram     ram_axi_tb        tb/axi_lite_assertions.sv rtl/ram_axi.sv tb/ram_axi_tb.sv
run yzcsr   yz_csr_axi_tb     rtl/yz_csr.sv tb/yz_csr_axi_tb.sv
run yzaccel yz_accel_tb       rtl/yz_accel.sv tb/yz_accel_tb.sv
run yztop   yz_top_tb         rtl/yz_csr.sv rtl/yz_accel.sv rtl/yz_top.sv tb/yz_top_tb.sv
verilator_coverage --write "$CD/merged.dat" "$CD"/*.dat >/dev/null 2>&1
echo; echo "=== GERCEK COVERAGE (olculmus, yalnizca rtl/) ==="
python3 "$CD/parse_coverage.py" "$CD/merged.dat"
