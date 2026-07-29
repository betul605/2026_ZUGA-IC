// ============================================================================
// yz_soft.c -- Tiny Conv'un SALT YAZILIM (hizlandiricisiz) referans gerceklemesi
//
// Amac: YZ hizlandiricinin hizlanmasini olcmek icin yazilim baz cizgisi.
// Donanim (rtl/yz_accel.sv) ve altin model (gen_golden.py) ile BIT-BIT ayni
// sabit-nokta semasini kullanir; ayni giris/agirliklarla ayni logit'leri uretir.
//
// Iki kullanim:
//   (a) Host dogrulamasi:   gcc -O2 yz_soft.c -o yz_soft && ./yz_soft   (logit'ler golden ile ayni olmali)
//   (b) RISC-V maliyet:     riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -O2 ... (objdump ile komut sayimi)
//
// Program ayrica conv/fc MAC yineleme sayilarini basar -> yazilim maliyet tahmini.
// ============================================================================
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

// Tam Tiny Conv konfigurasyonu (gen_golden.py full ile ayni)
#define IN_H 49
#define IN_W 40
#define K_H  10
#define K_W  8
#define STRIDE 2
#define N_FILT 8
#define OUT_H 25
#define OUT_W 20
#define FEAT  (N_FILT*OUT_H*OUT_W)   // 4000
#define FC_OUT 4
#define SHIFT 8
#define PAD_H 4
#define PAD_W 3

static int8_t  inp  [IN_H*IN_W];
static int8_t  wconv[N_FILT*K_H*K_W];
static int32_t bconv[N_FILT];
static int8_t  act  [FEAT];
static int8_t  wfc  [FC_OUT*FEAT];
static int32_t bfc  [FC_OUT];
static int32_t logit[FC_OUT];

// Basit hex okuyucu (satir basina bir deger)
static int load8(const char* f, int8_t* a, int n){
    FILE* fp=fopen(f,"r"); if(!fp){perror(f);return -1;}
    unsigned v; for(int i=0;i<n;i++){ if(fscanf(fp,"%x",&v)!=1){fclose(fp);return -1;} a[i]=(int8_t)v; }
    fclose(fp); return 0;
}
static int load32(const char* f, int32_t* a, int n){
    FILE* fp=fopen(f,"r"); if(!fp){perror(f);return -1;}
    unsigned v; for(int i=0;i<n;i++){ if(fscanf(fp,"%x",&v)!=1){fclose(fp);return -1;} a[i]=(int32_t)v; }
    fclose(fp); return 0;
}

int main(void){
    long conv_macs=0, fc_macs=0;
    if(load8 ("sw/yz/yz_input.hex", inp,  IN_H*IN_W)      ) return 1;
    if(load8 ("sw/yz/yz_wconv.hex", wconv,N_FILT*K_H*K_W) ) return 1;
    if(load32("sw/yz/yz_bconv.hex", bconv,N_FILT)         ) return 1;
    if(load8 ("sw/yz/yz_wfc.hex",   wfc,  FC_OUT*FEAT)    ) return 1;
    if(load32("sw/yz/yz_bfc.hex",   bfc,  FC_OUT)         ) return 1;

    // DepthwiseConv2D + ReLU + requant (SAME padding)
    for(int c=0;c<N_FILT;c++)
      for(int oy=0;oy<OUT_H;oy++)
        for(int ox=0;ox<OUT_W;ox++){
            int32_t acc = bconv[c];
            for(int ky=0;ky<K_H;ky++)
              for(int kx=0;kx<K_W;kx++){
                  int iy = oy*STRIDE - PAD_H + ky;
                  int ix = ox*STRIDE - PAD_W + kx;
                  if(iy>=0 && iy<IN_H && ix>=0 && ix<IN_W)
                      acc += (int32_t)inp[iy*IN_W+ix] * (int32_t)wconv[(c*K_H+ky)*K_W+kx];
                  conv_macs++;
              }
            if(acc<0) acc=0;              // ReLU
            acc >>= SHIFT;                 // requant
            if(acc>127) acc=127;
            act[(c*OUT_H+oy)*OUT_W+ox] = (int8_t)acc;
        }

    // FullyConnected
    for(int f=0;f<FC_OUT;f++){
        int32_t acc = bfc[f];
        for(int i=0;i<FEAT;i++){ acc += (int32_t)act[i]*(int32_t)wfc[f*FEAT+i]; fc_macs++; }
        logit[f]=acc;
    }
    int am=0; for(int f=1;f<FC_OUT;f++) if(logit[f]>logit[am]) am=f;

    printf("YZ yazilim referansi (hizlandiricisiz)\n");
    for(int f=0;f<FC_OUT;f++) printf("  logit%d = %d\n", f, logit[f]);
    printf("  argmax = %d\n", am);
    printf("  conv MAC yineleme = %ld\n", conv_macs);
    printf("  fc   MAC yineleme = %ld\n", fc_macs);
    printf("  toplam MAC yineleme = %ld\n", conv_macs+fc_macs);
    return 0;
}
