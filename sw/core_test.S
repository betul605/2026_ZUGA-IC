.section .text
.global _start
_start:
    nop
    nop
    nop
    nop
    lui   x10, 0x40002      # UART base
    addi  x1, x0, 5
    addi  x2, x0, 3
    add   x3, x1, x2
    addi  x4, x0, 8
    bne   x3, x4, fail
    addi  x1, x0, 10
    addi  x2, x0, 4
    sub   x3, x1, x2
    addi  x4, x0, 6
    bne   x3, x4, fail
    addi  x1, x0, 0xF0
    addi  x2, x0, 0x0F
    and   x3, x1, x2
    bne   x3, x0, fail
    or    x3, x1, x2
    addi  x4, x0, 0xFF
    bne   x3, x4, fail
    xor   x3, x1, x2
    bne   x3, x4, fail
    addi  x1, x0, 1
    slli  x3, x1, 4
    addi  x4, x0, 16
    bne   x3, x4, fail
    addi  x1, x0, 0x80
    srli  x3, x1, 3
    addi  x4, x0, 0x10
    bne   x3, x4, fail
    addi  x1, x0, 6
    addi  x2, x0, 7
    mul   x3, x1, x2
    addi  x4, x0, 42
    bne   x3, x4, fail
    addi  x1, x0, 100
    addi  x2, x0, 5
    div   x3, x1, x2
    addi  x4, x0, 20
    bne   x3, x4, fail
    addi  x1, x0, 17
    addi  x2, x0, 5
    rem   x3, x1, x2
    addi  x4, x0, 2
    bne   x3, x4, fail
    addi  x1, x0, 3
    addi  x2, x0, 5
    blt   x1, x2, b_ok
    j     fail
b_ok:
    bge   x1, x2, fail
    addi  x5, x0, 0
    addi  x6, x0, 1
    addi  x7, x0, 11
loop:
    add   x5, x5, x6
    addi  x6, x6, 1
    blt   x6, x7, loop
    addi  x4, x0, 55
    bne   x5, x4, fail
    lui   x11, 0x40000
    addi  x9, x0, 0x5A
    sw    x9, 4(x11)
    nop
    nop
    lw    x3, 4(x11)
    bne   x3, x9, fail
pass:
    addi  x14, x0, 0x43
    sw    x14, 12(x10)
    addi  x14, x0, 0x4F
    sw    x14, 12(x10)
    addi  x14, x0, 0x52
    sw    x14, 12(x10)
    addi  x14, x0, 0x45
    sw    x14, 12(x10)
    addi  x14, x0, 0x20
    sw    x14, 12(x10)
    addi  x14, x0, 0x50
    sw    x14, 12(x10)
    addi  x14, x0, 0x41
    sw    x14, 12(x10)
    addi  x14, x0, 0x53
    sw    x14, 12(x10)
    addi  x14, x0, 0x53
    sw    x14, 12(x10)
    addi  x14, x0, 0x0A
    sw    x14, 12(x10)
    j     halt
fail:
    addi  x14, x0, 0x46
    sw    x14, 12(x10)
    addi  x14, x0, 0x41
    sw    x14, 12(x10)
    addi  x14, x0, 0x49
    sw    x14, 12(x10)
    addi  x14, x0, 0x4C
    sw    x14, 12(x10)
    addi  x14, x0, 0x0A
    sw    x14, 12(x10)
halt:
    jal   x0, halt
