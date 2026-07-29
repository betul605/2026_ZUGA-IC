// ============================================================================
// yz_accel_tb.sv -- YZ Hizlandirici self-checking cikarim testi (§5.2 #4)
//
// Altin model (sw/yz/gen_golden.py) uretir:
//   yz_input/wconv/bconv/wfc/bfc.hex  -> DUT belleklerine yuklenir
//   yz_expected.hex                   -> beklenen logit'ler + argmax
// DUT cikarimi kosar; tb logit'leri ve argmax'i BIT-BIT karsilastirir.
//
// Kosum:  iverilog -g2012 -I sw/yz -s yz_accel_tb -o /tmp/yz.vvp \
//                    rtl/yz_accel.sv tb/yz_accel_tb.sv && vvp /tmp/yz.vvp
// ============================================================================
`timescale 1ns/1ps
`include "yz_params.svh"

module yz_accel_tb;
    localparam int FC_OUT = `YZ_FC_OUT;

    logic clk = 0, rst_ni = 0;
    always #5 clk = ~clk;   // 100 MHz

    logic        start, sw_reset, busy, done, error, irq;
    logic [31:0] cyc;
    logic [7:0]  argmax;
    logic [15:0] logit_addr;
    logic [31:0] logit_rdata;

    yz_accel #(
        .IN_H(`YZ_IN_H), .IN_W(`YZ_IN_W), .K_H(`YZ_K_H), .K_W(`YZ_K_W),
        .STRIDE(`YZ_STRIDE), .N_FILT(`YZ_N_FILT), .OUT_H(`YZ_OUT_H),
        .OUT_W(`YZ_OUT_W), .FEAT(`YZ_FEAT), .FC_OUT(`YZ_FC_OUT),
        .SHIFT(`YZ_SHIFT), .PAD_H(`YZ_PAD_H), .PAD_W(`YZ_PAD_W),
        .IMEM_FILE ("sw/yz/yz_input.hex"),
        .WCONV_FILE("sw/yz/yz_wconv.hex"),
        .BCONV_FILE("sw/yz/yz_bconv.hex"),
        .WFC_FILE  ("sw/yz/yz_wfc.hex"),
        .BFC_FILE  ("sw/yz/yz_bfc.hex")
    ) dut (
        .clk_i(clk), .rst_ni(rst_ni),
        .start_i(start), .sw_reset_i(sw_reset),
        .busy_o(busy), .done_o(done), .error_o(error), .irq_o(irq),
        .cycle_cnt_o(cyc), .argmax_o(argmax),
        .logit_addr_i(logit_addr), .logit_rdata_o(logit_rdata),
        .mem_we_i(1'b0), .mem_region_i(3'd0), .mem_addr_i(16'd0), .mem_wdata_i(32'd0)
    );

    // Beklenen degerler: FC_OUT logit + 1 argmax
    logic signed [31:0] exp [0:FC_OUT];   // FC_OUT+1 eleman
    integer i, errors;

    initial begin
        $readmemh("sw/yz/yz_expected.hex", exp);
        errors = 0;
        start = 0; sw_reset = 0; logit_addr = 0;
        repeat (4) @(posedge clk);
        rst_ni = 1;
        repeat (2) @(posedge clk);

        $display("=========================================================");
        $display(" ZUGA-IC YZ Hizlandirici - Self-Checking Cikarim Testi");
        $display(" Model: Tiny Conv (DepthwiseConv2D+ReLU -> FC -> argmax)");
        $display(" Konfig: in=%0dx%0d k=%0dx%0d s=%0d filt=%0d out=%0dx%0dx%0d feat=%0d",
                 `YZ_IN_H,`YZ_IN_W,`YZ_K_H,`YZ_K_W,`YZ_STRIDE,`YZ_N_FILT,
                 `YZ_OUT_H,`YZ_OUT_W,`YZ_N_FILT,`YZ_FEAT);
        $display("=========================================================");

        // Cikarimi baslat (1-cycle pulse)
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;

        // done bekle (timeout korumali)
        i = 0;
        while (!done && i < 5_000_000) begin @(posedge clk); i = i + 1; end
        if (!done) begin
            $display("[TB] HATA: done gelmedi (timeout @%0d cevrim)", i);
            $display("===== YZ HIZLANDIRICI TEST FAILED =====");
            $finish;
        end
        @(posedge clk);

        // Logit'leri oku ve karsilastir
        $display("[TB] Cikarim tamamlandi. Donanim cevrimi = %0d", cyc);
        for (i = 0; i < FC_OUT; i = i + 1) begin
            logit_addr = i[15:0];
            #1;
            if (logit_rdata !== exp[i]) begin
                $display("[TB] FAIL logit%0d: HW=%0d  golden=%0d", i, $signed(logit_rdata), exp[i]);
                errors = errors + 1;
            end else begin
                $display("[TB] PASS logit%0d = %0d", i, $signed(logit_rdata));
            end
        end

        // argmax karsilastir
        if (argmax !== exp[FC_OUT][7:0]) begin
            $display("[TB] FAIL argmax: HW=%0d  golden=%0d", argmax, exp[FC_OUT][7:0]);
            errors = errors + 1;
        end else begin
            $display("[TB] PASS argmax (siniflandirma) = %0d", argmax);
        end

        $display("---------------------------------------------------------");
        if (errors == 0)
            $display("===== YZ HIZLANDIRICI TEST PASSED ===== (HW == golden, bit-bit)");
        else
            $display("===== YZ HIZLANDIRICI TEST FAILED ===== (%0d hata)", errors);
        $display("=========================================================");
        $finish;
    end
endmodule
