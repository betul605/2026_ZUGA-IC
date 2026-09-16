#include <stdint.h>
#define U1 0x40003000u
#define RDR 0x08u
#define TDR 0x0Cu
#define CFG 0x10u
#define CPB 0x00u
#define GPIO_ODR 0x40000004u
#define YZ_CTRL 0x50000000u
#define YZ_STATUS 0x50000004u
#define YZ_LOGIT 0x50600000u
#define YZ_IN   0x50100000u
#define YZ_WC   0x50200000u
#define YZ_BC   0x50300000u
#define YZ_WF   0x50400000u
#define YZ_BF   0x50500000u
#define IN_COUNT 1960
#define N_WCONV 640
#define N_BCONV 8
#define N_WFC 16000
#define N_BFC 4
#define FC_OUT 4
static inline void wr(uint32_t a,uint32_t v){*(volatile uint32_t*)a=v;}
static inline uint32_t rd(uint32_t a){return *(volatile uint32_t*)a;}
static void led(uint32_t v){wr(GPIO_ODR,v&0xFFu);}
static void dly(uint32_t n){volatile uint32_t i;for(i=0;i<n;i++){}}
static void t1(char c){wr(U1+TDR,(uint8_t)c);dly(3000);}
static void i1(int32_t v){char b[12];int i=0;uint32_t u;int neg=0;if(v<0){neg=1;u=(uint32_t)(-(int64_t)v);}else u=(uint32_t)v;if(u==0)b[i++]='0';while(u){b[i++]=(char)('0'+(u%10));u/=10;}if(neg)t1('-');while(i)t1(b[--i]);}
static void pcls(int k){if(k==0){t1('s');t1('i');t1('l');t1('e');t1('n');t1('c');t1('e');}else if(k==1){t1('u');t1('n');t1('k');t1('n');t1('o');t1('w');t1('n');}else if(k==2){t1('y');t1('e');t1('s');}else{t1('n');t1('o');}}
static uint8_t g1(void){while(!(rd(U1+CFG)&0x2u)){}uint8_t x=(uint8_t)(rd(U1+RDR)&0xFFu);wr(U1+CFG,0x1u);return x;}
static uint32_t g4(void){uint32_t a=g1();a|=(uint32_t)g1()<<8;a|=(uint32_t)g1()<<16;a|=(uint32_t)g1()<<24;return a;}
static void waitpre(void){for(;;){if(g1()!=0xAA)continue;if(g1()==0x55)return;}}
int main(void){
  for(int k=0;k<4;k++){led(0xFFu);dly(4000000u);led(0x00u);dly(4000000u);}
  wr(U1+CPB,434); wr(U1+CFG,0x1u);
  t1('R');t1('D');t1('Y');t1('\n');
  led(0x01u);                                     /* agirlik yukleniyor */
  for(int i=0;i<N_WCONV;i++) wr(YZ_WC+i*4,(uint32_t)g1());
  for(int i=0;i<N_BCONV;i++) wr(YZ_BC+i*4,g4());
  for(int i=0;i<N_WFC;i++)   wr(YZ_WF+i*4,(uint32_t)g1());
  for(int i=0;i<N_BFC;i++)   wr(YZ_BF+i*4,g4());
  t1('W');t1('O');t1('K');t1('\n');               /* agirliklar yuklendi */
  led(0x80u);
  for(;;){
    waitpre();
    led(0x40u);
    for(int i=0;i<IN_COUNT;i++) wr(YZ_IN+i*4,(uint32_t)g1());
    wr(YZ_CTRL,0x1u);
    uint32_t wd=20000000u; int to=0;
    while(!(rd(YZ_STATUS)&0x2u)){if(--wd==0){to=1;break;}}
    if(to){led(0xAAu);t1('E');t1('R');t1('R');t1('\n');led(0x80u);continue;}
    int32_t lo[FC_OUT];volatile int32_t*lg=(volatile int32_t*)YZ_LOGIT;int best=0;
    for(int i=0;i<FC_OUT;i++){lo[i]=lg[i];if(lo[i]>lo[best])best=i;}
    led((uint32_t)(1<<best));
    t1('R');t1('E');t1('S');t1('U');t1('L');t1('T');t1(':');t1(' ');
    pcls(best);
    t1(' ');t1('s');t1('c');t1('o');t1('r');t1('e');t1('s');t1('=');
    for(int i=0;i<FC_OUT;i++){i1(lo[i]);if(i<FC_OUT-1)t1(',');}
    t1('\n');
    led(0x80u);
  }
  return 0;
}
