#!/bin/bash
set -e
cd "$(dirname "$0")"
GCC=/usr/bin/riscv64-unknown-elf-gcc
OCP=/usr/bin/riscv64-unknown-elf-objcopy
CF="-march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostdlib -fno-jump-tables -fno-tree-loop-distribute-patterns"
echo "== demo firmware derle =="
$GCC $CF -Wl,-T,demo.ld -Wl,--no-relax demo_start.S demo_stream.c -o demo.elf
$OCP -O binary demo.elf demo.bin
echo "== boot stub derle =="
$GCC -march=rv32imc -mabi=ilp32 -nostdlib -Wl,-Ttext=0x00000000 -Wl,--no-relax boot_stub.S -o boot_stub.elf
$OCP -O binary boot_stub.elf boot_stub.bin
python3 bin2hex.py boot_stub.bin bootloader.hex 128; cp bootloader.hex sw/boot_stub.hex
python3 bin2hex.py demo.bin demo_prog.hex 2048
echo "== TAMAM =="
