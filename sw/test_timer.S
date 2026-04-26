# ============================================================================
# test_timer.S — Timer self-checking test
#
# 1. Timer'i sifirla (CLR = 1 @ 0x40001008)
# 2. Timer'i etkinlestir (ENA = 1 @ 0x4000100C)
# 3. Birkac NOP ile bekle (sayac artsin)
# 4. TIM_CNT oku (@ 0x40001014)
# 5. 0'dan buyukse UART'a 'T' (pass), degilse 'F' (fail)
# ============================================================================

.section .text
.global _start

_start:
    # Pipeline isinsin
    nop
    nop
    nop
    nop

    # x10 = UART base (0x10000000)
    lui   x10, 0x40002

    # x11 = Timer base (0x40001000)
    lui   x11, 0x40001

    nop
    nop

    # TIM_CLR (0x08) = 1 -> sayaci sifirla
    addi  x12, x0, 1
    sw    x12, 8(x11)
    nop
    nop

    # TIM_ENA (0x0C) = 1 -> sayaci baslat
    sw    x12, 12(x11)
    nop
    nop

    # Sayac artsin diye biraz bekle
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    # TIM_CNT (0x14) oku
    lw    x13, 20(x11)
    nop
    nop

    # x13 > 0 mi? (x13 != 0 ise pass)
    bne   x13, x0, pass_path

fail_path:
    # 'F' (0x46) -> UART
    addi  x14, x0, 0x46
    sw    x14, 12(x10)
    addi  x14, x0, 0x0A
    sw    x14, 12(x10)
    j     end

pass_path:
    # 'T' (0x54) -> UART (T for Timer!)
    addi  x14, x0, 0x54
    sw    x14, 12(x10)
    addi  x14, x0, 0x0A
    sw    x14, 12(x10)

end:
    jal   x0, end
