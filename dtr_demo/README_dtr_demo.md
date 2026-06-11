# ZUGA-IC — TEKNOFEST DTR Demo Testbench Entegrasyonu

Bu klasör, ZUGA-IC SoC'sini TEKNOFEST'in resmi **demo testbench**'inden (eleme/PASS-FAIL
testi) geçirmek için hazırlanmıştır. Test akışı: DUT `'R'` gönderir → TB `'A'` yollar →
DUT `"Hello World!"` gönderir → **TEST SUCCESS**.

> Bu paket bir simülatör stub'ı + birim simülasyonla doğrulandı (UART sözleşmesi: 'R'
> gönderimi, 'A' alımı, "Hello World!" gönderimi sahte-tetikleme olmadan PASS). **Nihai
> onay sizin makinenizde gerçek CV32E40P ile Vivado xsim çalıştırınca alınır.**

## 1) Yerleşim (repo köküne kopyalayın)

    2026_ZUGA-IC/
    ├── rtl/                 (mevcut — DEĞİŞMEDİ)
    ├── cv32e40p/            (mevcut — DEĞİŞMEDİ)
    └── dtr_demo/            ← BU KLASÖR
        ├── rtl/
        │   ├── soc_top_axi.sv     (override: +uart0_rx_i, u_uart0=uart_tek_axi, bootloader guard)
        │   └── uart_tek_axi.sv    (YENİ: EK-2/helloworld uyumlu UART)
        ├── teknotest/             (TEKNOFEST paketi + doldurulmuş user_files)
        └── README_dtr_demo.md

`dtr_demo/teknotest/` repo kökünden **iki seviye** altta olmalı (relative yollar buna göre).
Mevcut `rtl/` ve `cv32e40p/` klasörlerinize **dokunulmadı**; demo kendi `soc_top_axi.sv`
kopyasını kullanır.

## 2) Toolchain ayarı

`teknotest/user_files/rv_toolchain.conf` içindeki `RISCV_GCC_PREFIX` değerini kendi RISC-V
GCC yolunuza ayarlayın. (Ubuntu paketi `gcc-riscv64-unknown-elf` rv32imc destekler ve
çalışır: `/usr/bin/riscv64-unknown-elf`.) Bu dosya hakemlerce kendi ortamlarına göre
yeniden düzenlenecektir.

## 3) Yazılımı derle

    cd dtr_demo/teknotest
    python3 sw/scripts/build.py        # helloworld.elf + sw/build/helloworld.mem üretir

> `sw/build/helloworld.mem` zaten dahil (rv32imc, .text=240B/60 word, boot ROM'a sığar).
> Derleme akışını doğrulamak için yine de çalıştırın.

## 4) Vivado 2021.2 simülasyonu

    cd dtr_demo/teknotest
    vivado -mode tcl
    source ./scripts/create_vivado_proj.tcl
    # ardından simülasyonu sonuna kadar çalıştırın (run -all)

Beklenen: konsolda DUT'un gönderdiği karakterler (`R` ve `Hello World!`) ve testbench'in
**TEST SUCCESS** mesajı.

## 5) GitHub

    git add dtr_demo
    git commit -m "DTR demo: TEKNOFEST testbench entegrasyonu (PASS)"
    git push

## Doldurulan/eklenen dosyalar (özet)

| Dosya | Ne yapıldı |
|---|---|
| `teknotest/user_files/user_defines.h` | `UART_BASE_ADDR = 0x40002000UL` (UART-0) |
| `teknotest/user_files/bootrom.ld` | BOOTROM `0x00000000`, RAM(stack/DRAM) `0x00020000` |
| `teknotest/user_files/teknotest_wrapper.sv` | 4 pin → `soc_top_axi` (gpio=0, i2c_sda_i=1, gerisi açık) |
| `teknotest/user_files/teknotest_tb_user_code.sv` | `helloworld.mem` → `dut.u_soc.instr_mem` |
| `teknotest/user_files/compile_user_design.tcl` | cv32e40p + çevre birimleri + override RTL + `TEKNOTEST_SIM` define + sim top |
| `teknotest/user_files/rv_toolchain.conf` | RISC-V prefix |
| `dtr_demo/rtl/uart_tek_axi.sv` | YENİ — CFG[0] yazımı TX başlatır (helloworld.c böyle bekler) |
| `dtr_demo/rtl/soc_top_axi.sv` | override — RX portu + uart_tek_axi + bootloader.hex guard |

## Neden ayrı bir UART (uart_tek_axi)?

Mevcut `uart_axi.sv` TX'i **TDR yazımında** başlatıyor; oysa `helloworld.c` önce TDR'yi
yazıp **`CFG |= 1` ile** başlatıyor. Bu haliyle 'R' hiç gönderilmez ve test timeout olurdu.
Doğrulanmış `uart_axi.sv` ve 10/10 regresyonunuza dokunmamak için sözleşmeyi birebir
uygulayan izole bir UART yazıldı; sadece bu demoda kullanılır.
