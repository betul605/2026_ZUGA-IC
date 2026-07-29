#!/usr/bin/env python3
# ============================================================================
# gen_golden.py  --  ZUGA-IC YZ Hizlandirici altin (golden) referans modeli
#
# Sartname EK-1 "Tiny Conv" akisini SABIT-NOKTA (int8) olarak gerceklenen
# donanim datapath'i ile BIT-BIT ozdes uretecek sekilde modeller:
#   Reshape -> DepthwiseConv2D(+ReLU, SAME padding, stride S) -> FullyConnected -> argmax
#
# Uretilenler (tb/ tarafindan $readmemh ile yuklenir):
#   yz_input.hex   : giris ozniteligi   (int8, IN_H*IN_W adet, 2 hane)
#   yz_wconv.hex   : conv agirliklari    (int8, N_FILT*K_H*K_W)
#   yz_bconv.hex   : conv bias           (int32, N_FILT)
#   yz_wfc.hex     : FC agirliklari       (int8, FC_OUT*FEAT)
#   yz_bfc.hex     : FC bias             (int32, FC_OUT)
#   yz_expected.hex: beklenen logit'ler  (int32, FC_OUT)  + son satir argmax
#   yz_params.svh  : RTL/tb parametreleri (makro)
#
# Sabit-nokta semasi (donanimla birebir ayni):
#   conv:  acc(int32) = bias + sum(int8_in * int8_w);  ReLU;  acc >>> SHIFT;  clamp[0,127] -> int8
#   fc:    logit(int32) = bias + sum(int8_act * int8_w)   (requant yok)
#   argmax: en buyuk logit indeksi
#
# NOT: Bu sema, TFLite'in tam requantizasyonunu birebir taklit etme iddiasi
# tasimaz; amaci DONANIM ile YAZILIM arasinda bit-bit ozdeslik saglamaktir
# (sartname §5.2 #4 + EK-1 "yazilim modeline gore dogruluk" kanit hedefi).
# Gercek egitilmis TFLite agirliklari ayni semayla yuklendiginde ayni akis calisir.
# ============================================================================
import sys, os, random

random.seed(20260724)  # deterministik -> her kosuda ayni vektorler

# ---- Konfigurasyon: "small" (hizli bring-up) veya "full" (gercek Tiny Conv) ----
CFG = sys.argv[1] if len(sys.argv) > 1 else "small"
if CFG == "full":
    IN_H, IN_W = 49, 40
    K_H, K_W   = 10, 8
    STRIDE     = 2
    N_FILT     = 8
    FC_OUT     = 4
    SHIFT      = 8
else:  # small
    IN_H, IN_W = 8, 8
    K_H, K_W   = 3, 3
    STRIDE     = 1
    N_FILT     = 2
    FC_OUT     = 4
    SHIFT      = 6

def same_out(n, s):      # SAME padding cikis boyutu
    return (n + s - 1) // s
OUT_H = same_out(IN_H, STRIDE)
OUT_W = same_out(IN_W, STRIDE)
FEAT  = N_FILT * OUT_H * OUT_W

def pad_before(n, k, s, o):
    total = max((o - 1) * s + k - n, 0)
    return total // 2

PAD_H = pad_before(IN_H, K_H, STRIDE, OUT_H)
PAD_W = pad_before(IN_W, K_W, STRIDE, OUT_W)

def s8(x):   # int8'e clamp/wrap yok; sadece uretimde [-128,127] araligi
    return max(-128, min(127, x))
def clamp8(x):
    return max(0, min(127, x))
def sra(x, n):   # arithmetic shift right (python >> zaten arithmetic)
    return x >> n

# ---- Rastgele ama deterministik giris/agirlik/bias uret ----
inp   = [random.randint(-128, 127) for _ in range(IN_H * IN_W)]
wconv = [random.randint(-40, 40)   for _ in range(N_FILT * K_H * K_W)]
bconv = [random.randint(-200, 200) for _ in range(N_FILT)]
wfc   = [random.randint(-30, 30)   for _ in range(FC_OUT * FEAT)]
bfc   = [random.randint(-1000,1000)for _ in range(FC_OUT)]

def idx_in(y, x):        return y * IN_W + x
def idx_wc(c, ky, kx):   return (c * K_H + ky) * K_W + kx
# aktivasyon: kanal-major (c,oy,ox) -> FC giris vektor sirasi ile ayni
def idx_act(c, oy, ox):  return (c * OUT_H + oy) * OUT_W + ox
def idx_wf(f, i):        return f * FEAT + i

# ---- DepthwiseConv2D + ReLU + requant (SAME padding) ----
act = [0] * FEAT
for c in range(N_FILT):
    for oy in range(OUT_H):
        for ox in range(OUT_W):
            acc = bconv[c]
            for ky in range(K_H):
                for kx in range(K_W):
                    iy = oy * STRIDE - PAD_H + ky
                    ix = ox * STRIDE - PAD_W + kx
                    if 0 <= iy < IN_H and 0 <= ix < IN_W:
                        acc += inp[idx_in(iy, ix)] * wconv[idx_wc(c, ky, kx)]
            if acc < 0:
                acc = 0                 # ReLU
            acc = sra(acc, SHIFT)       # requant (arith shift)
            act[idx_act(c, oy, ox)] = clamp8(acc)

# ---- FullyConnected -> logit (int32) ----
logit = [0] * FC_OUT
for f in range(FC_OUT):
    acc = bfc[f]
    for i in range(FEAT):
        acc += act[i] * wfc[idx_wf(f, i)]
    logit[f] = acc

argmax = max(range(FC_OUT), key=lambda f: logit[f])

# ---- Dosya yazicilar ----
OUT = os.path.dirname(os.path.abspath(__file__))
def w8(name, arr):
    with open(os.path.join(OUT, name), "w") as fp:
        for v in arr:
            fp.write("%02x\n" % (v & 0xFF))
def w32(name, arr):
    with open(os.path.join(OUT, name), "w") as fp:
        for v in arr:
            fp.write("%08x\n" % (v & 0xFFFFFFFF))

w8 ("yz_input.hex", inp)
w8 ("yz_wconv.hex", wconv)
w32("yz_bconv.hex", bconv)
w8 ("yz_wfc.hex",   wfc)
w32("yz_bfc.hex",   bfc)
w32("yz_expected.hex", logit + [argmax])

with open(os.path.join(OUT, "yz_params.svh"), "w") as fp:
    fp.write("// Otomatik uretildi: sw/yz/gen_golden.py (%s)\n" % CFG)
    fp.write("// Degistirmeyin - RTL ve tb bu makrolari paylasir.\n")
    for k, v in [("YZ_IN_H",IN_H),("YZ_IN_W",IN_W),("YZ_K_H",K_H),("YZ_K_W",K_W),
                 ("YZ_STRIDE",STRIDE),("YZ_N_FILT",N_FILT),("YZ_OUT_H",OUT_H),
                 ("YZ_OUT_W",OUT_W),("YZ_FEAT",FEAT),("YZ_FC_OUT",FC_OUT),
                 ("YZ_SHIFT",SHIFT),("YZ_PAD_H",PAD_H),("YZ_PAD_W",PAD_W)]:
        fp.write("`define %-12s %d\n" % (k, v))

print("=== gen_golden.py (%s) ===" % CFG)
print("  in=%dx%d  k=%dx%d  s=%d  filt=%d  -> out=%dx%dx%d  feat=%d  fc=%d  shift=%d  pad=(%d,%d)"
      % (IN_H,IN_W,K_H,K_W,STRIDE,N_FILT,OUT_H,OUT_W,N_FILT,FEAT,FC_OUT,SHIFT,PAD_H,PAD_W))
macs = OUT_H*OUT_W*N_FILT*K_H*K_W + FEAT*FC_OUT
print("  yaklasik MAC sayisi = %d" % macs)
print("  logit =", logit)
print("  argmax =", argmax)
