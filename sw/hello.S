.section .text
.global _start
_start:
    # Pipeline ısınsın
    nop
    nop
    nop
    nop

    # UART adresini x1'e yukle (0x40002000, EK-2 base)
    lui   x1, 0x40002

    # Bir kaç nop daha, x1'in WB stage'i bitsin
    nop
    nop

    # Şimdi yazabiliriz
    addi  x2, x0, 72        # 'H'
    sw    x2, 12(x1)
    nop

    addi  x2, x0, 105       # 'i'
    sw    x2, 12(x1)
    nop

    addi  x2, x0, 10        # '\n'
    sw    x2, 12(x1)
    nop

loop_end:
    jal   x0, loop_end
