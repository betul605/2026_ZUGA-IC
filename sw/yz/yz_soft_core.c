// yz_soft_core.c -- Tiny Conv'un stdio'suz salt-hesap cekirdegi (RISC-V maliyet olcumu icin)
// yz_soft.c ile ayni algoritma; newlib gerektirmez -> rv32imc'ye dogrudan derlenir.
//   riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -O2 -S yz_soft_core.c -o yz_soft_core.s
// Ic donguler (run): conv MAC (sinir-ici) ve fc MAC komut sayilari objdump/-S ile sayilir.
typedef signed char i8;  typedef int i32;
#define IN_H 49
#define IN_W 40
#define K_H 10
#define K_W 8
#define STRIDE 2
#define N_FILT 8
#define OUT_H 25
#define OUT_W 20
#define FEAT (N_FILT*OUT_H*OUT_W)
#define FC_OUT 4
#define SHIFT 8
#define PAD_H 4
#define PAD_W 3
i8  inp[IN_H*IN_W], wconv[N_FILT*K_H*K_W], act[FEAT], wfc[FC_OUT*FEAT];
i32 bconv[N_FILT], bfc[FC_OUT], logit[FC_OUT];
void run(void){
  for(int c=0;c<N_FILT;c++)
    for(int oy=0;oy<OUT_H;oy++)
      for(int ox=0;ox<OUT_W;ox++){
        i32 acc=bconv[c];
        for(int ky=0;ky<K_H;ky++)
          for(int kx=0;kx<K_W;kx++){
            int iy=oy*STRIDE-PAD_H+ky, ix=ox*STRIDE-PAD_W+kx;
            if(iy>=0&&iy<IN_H&&ix>=0&&ix<IN_W)
              acc += (i32)inp[iy*IN_W+ix]*(i32)wconv[(c*K_H+ky)*K_W+kx];
          }
        if(acc<0) acc=0; acc>>=SHIFT; if(acc>127) acc=127;
        act[(c*OUT_H+oy)*OUT_W+ox]=(i8)acc;
      }
  for(int f=0;f<FC_OUT;f++){
    i32 acc=bfc[f];
    for(int i=0;i<FEAT;i++) acc+=(i32)act[i]*(i32)wfc[f*FEAT+i];
    logit[f]=acc;
  }
}
