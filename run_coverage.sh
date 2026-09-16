#!/bin/bash
# ZUGA-IC line-coverage suite (DTR-karsilastirilabilir). Tum moduller pass.
cd "$(dirname "$0")"
COV=coverage_results; rm -rf $COV; mkdir -p $COV
mods="ram_axi:build_ram_axi.sh boot_rom_axi:build_boot_rom_axi.sh gpio_axi:build_gpio_axi.sh timer_axi:build_timer_axi.sh uart_axi:build_uart_axi.sh uart_dual_axi:build_uart_dual_axi.sh uart_rx_axi:build_uart_rx_axi.sh i2c_master_axi:build_i2c_axi.sh qspi_master_axi:build_qspi_axi.sh yz_csr_axi:build_yz_csr_axi.sh"
for pair in $mods; do
  m=${pair%%:*}; s=${pair##*:}
  if [ ! -f "$s" ]; then echo "SKIP $m ($s yok)"; continue; fi
  rm -f coverage.dat
  sed -e 's/verilator --binary/verilator --binary --coverage-line/' -e '/dirname/d' "$s" > /tmp/cov_$m.sh
  bash /tmp/cov_$m.sh > /tmp/cov_$m.log 2>&1
  if [ -f coverage.dat ]; then mv coverage.dat $COV/$m.dat; echo "OK   $m"; else echo "WARN $m (dat yok: /tmp/cov_$m.log)"; fi
done
echo "================================================================"
if ls $COV/*.dat >/dev/null 2>&1; then
  verilator_coverage --write $COV/merged.dat $COV/*.dat >/dev/null 2>&1
  for f in $COV/*.dat; do
    [ "$f" = "$COV/merged.dat" ] && continue
    t=$(grep -c "^C " "$f"); c=$(awk '/^C /{if($NF+0>0)x++}END{print x+0}' "$f")
    [ "$t" -gt 0 ] && awk "BEGIN{printf \"  %-18s %d/%d (%.1f%%)\n\",\"$(basename $f .dat)\",$c,$t,$c*100/$t}"
  done
  T=$(grep -c "^C " $COV/merged.dat); C=$(awk '/^C /{if($NF+0>0)x++}END{print x+0}' $COV/merged.dat)
  echo "----------------------------------------------------------------"
  [ "$T" -gt 0 ] && awk "BEGIN{printf \"TOPLAM LINE COVERAGE: %d/%d = %%%.1f\n\",$C,$T,$C*100/$T}"
else echo "HATA: coverage.dat uretilemedi"; fi
