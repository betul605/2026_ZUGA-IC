# ============================================================================
# bootloader.S - ZUGA-IC Boot ROM (512 B @ 0x0000_0000)
# ============================================================================
# OTR Tablo 1 (sayfa 2-3) ile birebir uyumlu:
#   Boot ROM:  0x0000_0000 - 0x0000_01FF (512 B)
#   IRAM:      0x0001_0000 - 0x0001_1FFF (8 kB)
#
# DTR sürümü davranışı:
#   1. Reset sonrası CPU PC=0x00000000 adresinden başlar
#   2. Bu kod IRAM adresini t0'a yükler (lui)
#   3. IRAM'a (0x00010000) kontrol aktarır (jr)
#   4. Asıl program IRAM'dan çalışmaya devam eder
#
# Final sürümü (planlı):
#   QSPI Master ile NOR Flash'tan IRAM'a dinamik yükleme + jump
#   (OTR Bölüm 2.3 Boot Mekanizması, sayfa 3)
#
# Sartname §4.2.2.1 uyumu:
#   - Sistem hizmeti boot vektörü 0x00 adresinde başlar (TAMAM)
#   - Boot ROM 512 B (TAMAM, OTR'de de 512 B)
#   - QSPI'dan boot mantığı (Final dönemine planlandı)
# ============================================================================

.section .text
.global _start

_start:
    # Pipeline ısınsın (hello.S yöntemi)
    nop
    nop
    nop
    nop

    # IRAM adresini t0'a yükle (0x00010000)
    lui   t0, 0x10          # t0 = 0x00010000

    # Pipeline'da WB stage bitsin
    nop
    nop

    # IRAM'a kontrol aktar (jump-and-register)
    jr    t0                # PC = t0 = 0x00010000

# Buraya ulasilmamali (jr sonrasi), ama guvenlik icin sonsuz loop
hang:
    jal   x0, hang
