# ============================================================================
# test_full.S - Comprehensive SoC test
#
# Coverage genisletme amacli: tum modullere erisim, hem read hem write,
# birden fazla yazmac kullanimi.
#
# Sirayla test edilenler:
#   1. UART'a "RUN" yaz (3 karakter)
#   2. GPIO_ODR'a 0x55 yaz, oku, beq ile kontrol et
#   3. GPIO_ODR'a 0xAA yaz, oku, beq ile kontrol et
#   4. Timer CLR, ENA, bekle, CNT oku, bne ile sayac arttı mi kontrol
#   5. UART_CFG oku (read islemi)
#   6. UART'a "PASS\n" yaz veya "FAIL\n" yaz
# ============================================================================

.section .text
.global _start

_start:
    # Pipeline isinma
    nop
    nop
    nop
    nop

    # Adres registerlari
    lui   x10, 0x40002    # UART base
    lui   x11, 0x40000    # GPIO base
    lui   x12, 0x40001    # Timer base

    nop
    nop

    # ========================================================================
    # 1. UART'a "RUN" yaz
    # ========================================================================
    addi  x14, x0, 0x52    # 'R'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x55    # 'U'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x4E    # 'N'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x0A    # '\n'
    sw    x14, 12(x10)
    nop

    # ========================================================================
    # 2. GPIO 0x55 test
    # ========================================================================
    addi  x13, x0, 0x55
    sw    x13, 4(x11)      # GPIO_ODR yaz
    nop
    nop
    lw    x14, 4(x11)      # GPIO_ODR oku
    nop
    nop
    bne   x13, x14, fail_path

    # ========================================================================
    # 3. GPIO 0xAA test
    # ========================================================================
    addi  x13, x0, 0xAA
    sw    x13, 4(x11)
    nop
    nop
    lw    x14, 4(x11)
    nop
    nop
    bne   x13, x14, fail_path

    # ========================================================================
    # 4. Timer test
    # ========================================================================
    addi  x13, x0, 1
    sw    x13, 8(x12)      # TIM_CLR
    nop
    nop
    sw    x13, 12(x12)     # TIM_ENA
    nop
    nop
    nop
    nop
    nop
    nop
    lw    x14, 20(x12)     # TIM_CNT oku
    nop
    nop
    beq   x14, x0, fail_path  # sayac 0 ise fail

    # ========================================================================
    # 5. UART_CFG oku (read coverage)
    # ========================================================================
    lw    x15, 16(x10)     # UART_CFG oku (default 0x01 olmali)
    nop
    nop

    # ========================================================================
    # 7. I2C Master test (M15: SoC entegrasyon dogrulamasi)
    # PRER=4, CTR=1, TXR=0xA5, CMR=STA+WR -> I2C transaction baslar
    # ========================================================================
    lui   x16, 0x40004     # I2C base 0x40004000
    addi  x17, x0, 4
    sw    x17, 0(x16)      # PRER = 4 (hizli sim icin)
    nop
    addi  x17, x0, 1
    sw    x17, 4(x16)      # CTR = 1 (EN=1)
    nop
    addi  x17, x0, 0xA5
    sw    x17, 8(x16)      # TXR = 0xA5
    nop
    addi  x17, x0, 0x90
    sw    x17, 16(x16)     # CMR = STA + WR
    nop
    nop
    nop

    # ========================================================================
    # 8. PASS yazdir
    # ========================================================================
pass_path:
    addi  x14, x0, 0x50    # 'P'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x41    # 'A'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x53    # 'S'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x53    # 'S'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x0A    # '\n'
    sw    x14, 12(x10)
    j     end

fail_path:
    addi  x14, x0, 0x46    # 'F'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x41    # 'A'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x49    # 'I'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x4C    # 'L'
    sw    x14, 12(x10)
    nop
    addi  x14, x0, 0x0A    # '\n'
    sw    x14, 12(x10)

end:
    jal   x0, end
