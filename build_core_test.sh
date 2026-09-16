#!/bin/bash
set -e
cd "$(dirname "$0")"
GCC=~/xpack-riscv-none-elf-gcc-13.2.0-2/bin/riscv-none-elf-gcc
OC=~/xpack-riscv-none-elf-gcc-13.2.0-2/bin/riscv-none-elf-objcopy
$GCC -march=rv32imc -mabi=ilp32 -nostdlib -Wl,-Ttext=0x00000000 -Wl,--no-relax sw/core_test.S -o sw/core_test.elf
$OC -O binary sw/core_test.elf sw/core_test.bin
python3 - <<'PY'
d=open('sw/core_test.bin','rb').read(); d+=b'\x00'*((-len(d))%4)
lines=[f'{int.from_bytes(d[i:i+4],"little"):08x}' for i in range(0,len(d),4)]
open('sw/core_test.hex','w').write('\n'.join(lines)+'\n'); print('core_test.hex word:',len(lines))
PY
