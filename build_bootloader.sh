#!/bin/bash
# build_bootloader.sh - Boot ROM (512 B) hex uretimi
# OTR Tablo 1 uyumlu: 0x0000_0000 - 0x0000_01FF

set -e
cd "$(dirname "$0")"

RISCV_GCC=~/xpack-riscv-none-elf-gcc-13.2.0-2/bin/riscv-none-elf-gcc
RISCV_OBJCOPY=~/xpack-riscv-none-elf-gcc-13.2.0-2/bin/riscv-none-elf-objcopy

echo "=== 1. Assemble ==="
$RISCV_GCC -march=rv32imc -mabi=ilp32 -nostdlib \
    -Wl,-Ttext=0x00000000 -Wl,--no-relax \
    sw/bootloader.S -o sw/bootloader.elf
echo "  sw/bootloader.elf olusturuldu"

echo ""
echo "=== 2. Binary ==="
$RISCV_OBJCOPY -O binary sw/bootloader.elf sw/bootloader.bin
ls -la sw/bootloader.bin

echo ""
echo "=== 3. Hex (128 word, 512 byte) ==="
python3 << 'PYEOF'
with open('sw/bootloader.bin', 'rb') as f:
    data = f.read()

print(f"  Binary boyutu: {len(data)} byte")

# 128 word = 512 byte (OTR uyumlu)
hex_lines = []
for i in range(128):
    if i*4 < len(data):
        word = int.from_bytes(data[i*4:i*4+4], 'little')
        hex_lines.append(f'{word:08x}')
    else:
        hex_lines.append('00000000')

with open('sw/bootloader.hex', 'w') as f:
    f.write('\n'.join(hex_lines) + '\n')

print(f"  sw/bootloader.hex olusturuldu (128 satir, 512 byte)")
PYEOF

echo ""
echo "=== 4. Disassembly Onizleme ==="
RISCV_OBJDUMP=~/xpack-riscv-none-elf-gcc-13.2.0-2/bin/riscv-none-elf-objdump
$RISCV_OBJDUMP -d sw/bootloader.elf | head -25

echo ""
echo "=== Bootloader build TAMAM ==="
