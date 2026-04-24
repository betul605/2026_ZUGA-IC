# ============================================================================
# test_gpio.S — GPIO self-checking test
#
# 1. GPIO_ODR (0x40000004) -> yaz 0xAA
# 2. GPIO_ODR (0x40000004) -> oku
# 3. 0xAA ile karsilastir
# 4. UART (0x10000000) -> 'P' (pass) veya 'F' (fail) yaz
# ============================================================================

.section .text
.global _start

_start:
    # Pipeline isinsin
    nop
    nop
    nop
    nop

    # x10 = UART base adresi (0x10000000)
    lui   x10, 0x10000

    # x11 = GPIO base adresi (0x40000000)
    lui   x11, 0x40000

    nop
    nop

    # Test deseni (0xAA) -> GPIO_ODR (offset 0x04)
    addi  x12, x0, 0xAA
    sw    x12, 4(x11)
    nop
    nop

    # GPIO_ODR'yi geri oku
    lw    x13, 4(x11)
    nop
    nop

    # Beklenen (x12) ile karsilastir
    beq   x12, x13, pass_path

fail_path:
    # 'F' (0x46) -> UART
    addi  x14, x0, 0x46
    sw    x14, 0(x10)
    nop
    # newline
    addi  x14, x0, 0x0A
    sw    x14, 0(x10)
    j     end

pass_path:
    # 'P' (0x50) -> UART
    addi  x14, x0, 0x50
    sw    x14, 0(x10)
    nop
    # newline
    addi  x14, x0, 0x0A
    sw    x14, 0(x10)

end:
    jal   x0, end
