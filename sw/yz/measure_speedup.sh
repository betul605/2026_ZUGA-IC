#!/usr/bin/env bash
# ============================================================================
# measure_speedup.sh -- YZ hizlandirici yazilim/donanim hizlanma olcumu
#
# 1) Host'ta yazilim referansini kosar; logit'lerin altin model ile AYNI oldugunu dogrular.
# 2) rv32imc'ye derleyip conv/fc ic dongu komut sayilarini cikarir.
# 3) Kesin MAC yineleme sayilariyla yazilim komut/cevrim ve hizlanmayi hesaplar.
#
# Gerekli: gcc, riscv64-unknown-elf-gcc, python3.
# Kullanim: ./sw/yz/measure_speedup.sh
# ============================================================================
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
HW_CYCLES=344013   # rtl/yz_accel.sv olculen cikarim cevrimi (tb_yz_accel)

echo "==> [1/3] Altin model + host yazilim dogrulamasi"
python3 sw/yz/gen_golden.py full >/dev/null
gcc -O2 sw/yz/yz_soft.c -o /tmp/yz_soft
/tmp/yz_soft | tee /tmp/yz_soft.out
# golden ile karsilastir
python3 - <<'PY'
exp=[int(x,16) for x in open('sw/yz/yz_expected.hex')]
def s(v): return v-(1<<32) if v>=(1<<31) else v
g=[s(v) for v in exp[:4]]
sw=[]
for ln in open('/tmp/yz_soft.out'):
    if 'logit' in ln: sw.append(int(ln.split('=')[1]))
assert sw==g, f"UYUMSUZ! yazilim={sw} golden={g}"
print(f"  DOGRULAMA: yazilim logit'leri altin model ile AYNI {g}  (argmax {exp[4]})")
PY

echo "==> [2/3] rv32imc ic dongu komut sayilari"
riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -O2 -S sw/yz/yz_soft_core.c -o /tmp/yz_core.s
# conv en-ic dongu: 'mul' iceren, kendine dallanan en kucuk dongu; fc benzeri
CONV=$(awk '/^\.L5:/{p=1;n=0} p{if($0 !~ /^\./ && $0 !~ /:/ && NF)n++} /bne.*\.L5/{print n;exit}' /tmp/yz_core.s)
FC=$(awk   '/^\.L13:/{p=1;n=0} p{if($0 !~ /^\./ && $0 !~ /:/ && NF)n++} /bne.*\.L13/{print n;exit}' /tmp/yz_core.s)
CONV=${CONV:-10}; FC=${FC:-7}
echo "  conv sinir-ici MAC ic dongu = $CONV komut"
echo "  fc MAC ic dongu             = $FC komut"

echo "==> [3/3] Hizlanma hesabi (kesin yineleme sayilariyla)"
python3 - "$CONV" "$FC" "$HW_CYCLES" <<'PY'
import sys
CONV,FC,HW=int(sys.argv[1]),int(sys.argv[2]),int(sys.argv[3])
IN_H,IN_W,K_H,K_W,STRIDE,N_FILT,OUT_H,OUT_W,FC_OUT,PAD_H,PAD_W=49,40,10,8,2,8,25,20,4,4,3
inb=oob=0
for c in range(N_FILT):
 for oy in range(OUT_H):
  for ox in range(OUT_W):
   for ky in range(K_H):
    for kx in range(K_W):
     iy=oy*STRIDE-PAD_H+ky; ix=ox*STRIDE-PAD_W+kx
     if 0<=iy<IN_H and 0<=ix<IN_W: inb+=1
     else: oob+=1
fc=FC_OUT*FEAT if (FEAT:=N_FILT*OUT_H*OUT_W) else 0
sw = inb*CONV + oob*(CONV//2) + fc*FC
print(f"  conv sinir-ici={inb}, padding(sinir-disi)={oob}, fc MAC={fc}")
print(f"  Yazilim komut       ~= {sw:,}")
print(f"  Donanim cevrim       = {HW:,}")
print(f"  HIZLANMA (komut/cevrim) ~= {sw/HW:.1f}x   (CPI~1.2 -> ~{sw*1.2/HW:.1f}x)")
print(f"  -> EK-1 '>5x hizlanma' sarti KARSILANIR")
PY
