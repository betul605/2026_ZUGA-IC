OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  IRAM (rx)  : ORIGIN = 0x00010000, LENGTH = 8K
  DRAM (rwx) : ORIGIN = 0x00020000, LENGTH = 8K
}
SECTIONS {
  .text : { . = ALIGN(4); KEEP(*(.text.start)) *(.text*) *(.rodata*) . = ALIGN(4); } > IRAM
  .bss (NOLOAD) : { . = ALIGN(4); __bss_start = .; *(.bss*) *(COMMON) . = ALIGN(4); __bss_end = .; } > DRAM
}
