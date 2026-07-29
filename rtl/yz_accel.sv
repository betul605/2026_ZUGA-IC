// ============================================================================
// yz_accel.sv  --  ZUGA-IC YZ Hizlandirici DATAPATH (paylasimli MAC)
//
// Sartname EK-1 "Tiny Conv" akisi, sabit-nokta (int8) donanim:
//   DepthwiseConv2D(+ReLU, SAME padding, stride S) -> FullyConnected -> argmax
// Tek (paylasimli) signed MAC birimi ile katmanlar sirayla hesaplanir.
//
// Sabit-nokta semasi (sw/yz/gen_golden.py ile BIT-BIT ozdes):
//   conv:  acc = bias + Σ(int8_in * int8_w);  ReLU;  acc >>> SHIFT;  clamp[0,127]
//   fc:    logit(int32) = bias + Σ(int8_act * int8_w)
//   argmax: en buyuk logit indeksi
//
// Bellek yukleme iki yolla mumkun:
//   (a) parametre dosyalari ile initial $readmemh   -> standalone testbench
//   (b) senkron yazma portu (mem_we_i/region/addr)  -> SoC (CPU AXI uzerinden)
//
// Kontrol arayuzu yz_csr.sv portlarina birebir uyumludur (start/busy/done/...).
// ============================================================================
module yz_accel #(
    parameter int IN_H    = 8,
    parameter int IN_W    = 8,
    parameter int K_H     = 3,
    parameter int K_W     = 3,
    parameter int STRIDE  = 1,
    parameter int N_FILT  = 2,
    parameter int OUT_H   = 8,
    parameter int OUT_W   = 8,
    parameter int FEAT    = 128,   // = N_FILT*OUT_H*OUT_W
    parameter int FC_OUT  = 4,
    parameter int SHIFT   = 6,
    parameter int PAD_H   = 1,
    parameter int PAD_W   = 1
`ifndef SYNTHESIS
    ,
    // Standalone tb icin opsiyonel dosya yukleme (yalnizca simulasyon)
    parameter string IMEM_FILE  = "",
    parameter string WCONV_FILE = "",
    parameter string BCONV_FILE = "",
    parameter string WFC_FILE   = "",
    parameter string BFC_FILE   = ""
`endif
)(
    input  logic        clk_i,
    input  logic        rst_ni,
    // Kontrol (yz_csr ile uyumlu)
    input  logic        start_i,        // 1-cycle pulse: cikarimi baslat
    input  logic        sw_reset_i,     // yumusak reset (mevcut kosuyu iptal)
    output logic        busy_o,
    output logic        done_o,
    output logic        error_o,
    output logic        irq_o,          // done aninda 1-cycle pulse
    output logic [31:0] cycle_cnt_o,    // BUSY suresince gecen cevrim
    output logic [7:0]  argmax_o,       // siniflandirma sonucu
    // Logit okuma portu (CPU ISR / tb)  -- ust adres bitleri kullanilmaz
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [15:0] logit_addr_i,
    output logic [31:0] logit_rdata_o,
    // Senkron bellek yukleme portu (SoC/CPU)
    input  logic        mem_we_i,
    input  logic [2:0]  mem_region_i,   // 0=input 1=wconv 2=bconv 3=wfc 4=bfc
    input  logic [15:0] mem_addr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [31:0] mem_wdata_i
);
    // --------------------------------------------------------------------
    // Bellekler
    // --------------------------------------------------------------------
    logic signed [7:0]  imem  [0:IN_H*IN_W-1];      // giris ozniteligi
    logic signed [7:0]  wconv [0:N_FILT*K_H*K_W-1]; // conv agirliklari
    logic signed [31:0] bconv [0:N_FILT-1];         // conv bias
    logic signed [7:0]  actm  [0:FEAT-1];           // ara aktivasyon (int8)
    logic signed [7:0]  wfc   [0:FC_OUT*FEAT-1];    // FC agirliklari
    logic signed [31:0] bfc   [0:FC_OUT-1];         // FC bias
    logic signed [31:0] logitm[0:FC_OUT-1];         // cikis logit'leri

    // Bellek adres genislikleri (lint-temiz indeksleme icin)
    localparam int IN_AW  = (IN_H*IN_W       > 1) ? $clog2(IN_H*IN_W)       : 1;
    localparam int WC_AW  = (N_FILT*K_H*K_W  > 1) ? $clog2(N_FILT*K_H*K_W)  : 1;
    localparam int ACT_AW = (FEAT            > 1) ? $clog2(FEAT)            : 1;
    localparam int WF_AW  = (FC_OUT*FEAT     > 1) ? $clog2(FC_OUT*FEAT)     : 1;
    localparam int BC_AW  = (N_FILT          > 1) ? $clog2(N_FILT)          : 1;
    localparam int BF_AW  = (FC_OUT          > 1) ? $clog2(FC_OUT)          : 1;

    // Opsiyonel dosya yukleme (yalnizca simulasyon; sentezde devre disi)
`ifndef SYNTHESIS
    initial begin
        if (IMEM_FILE  != "") $readmemh(IMEM_FILE,  imem);
        if (WCONV_FILE != "") $readmemh(WCONV_FILE, wconv);
        if (BCONV_FILE != "") $readmemh(BCONV_FILE, bconv);
        if (WFC_FILE   != "") $readmemh(WFC_FILE,   wfc);
        if (BFC_FILE   != "") $readmemh(BFC_FILE,   bfc);
    end
`endif

    // Senkron yazma portu (SoC yolu)
    always_ff @(posedge clk_i) begin
        if (mem_we_i) begin
            case (mem_region_i)
                3'd0: imem [mem_addr_i[IN_AW-1:0]]  <= mem_wdata_i[7:0];
                3'd1: wconv[mem_addr_i[WC_AW-1:0]]  <= mem_wdata_i[7:0];
                3'd2: bconv[mem_addr_i[BC_AW-1:0]]  <= mem_wdata_i;
                3'd3: wfc  [mem_addr_i[WF_AW-1:0]]  <= mem_wdata_i[7:0];
                3'd4: bfc  [mem_addr_i[BF_AW-1:0]]  <= mem_wdata_i;
                default: ;
            endcase
        end
    end

    assign logit_rdata_o = logitm[logit_addr_i[BF_AW-1:0]];

    // --------------------------------------------------------------------
    // FSM
    // --------------------------------------------------------------------
    typedef enum logic [3:0] {
        S_IDLE, S_CONV_LOAD, S_CONV_MAC, S_CONV_STORE,
        S_FC_LOAD, S_FC_MAC, S_FC_STORE, S_ARGMAX, S_DONE
    } state_e;
    state_e st;

    // Sayaclar (32-bit - int parametrelerle lint-temiz)
    logic [31:0] c, oy, ox, ky, kx;   // conv
    logic [31:0] f, ii;               // fc
    logic [31:0] am_f;                // argmax tarama
    logic signed [31:0] acc;
    logic signed [31:0] am_best;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0]        am_idx;
    /* verilator lint_on UNUSEDSIGNAL */

    // Indeks hesaplari (combinational, 32-bit ara - lint temiz)
    logic signed [31:0] iy, ix;
    assign iy = $signed(oy) * STRIDE - PAD_H + $signed(ky);
    assign ix = $signed(ox) * STRIDE - PAD_W + $signed(kx);
    logic in_bounds;
    assign in_bounds = (iy >= 0) && (iy < IN_H) && (ix >= 0) && (ix < IN_W);

    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] in_idx, wc_idx, act_idx, wf_idx;  // ust bitler indekste kullanilmaz
    /* verilator lint_on UNUSEDSIGNAL */
    assign in_idx  = $unsigned(iy*IN_W + ix);
    assign wc_idx  = (c*K_H + ky)*K_W + kx;
    assign act_idx = (c*OUT_H + oy)*OUT_W + ox;
    assign wf_idx  = f*FEAT + ii;

    logic signed [7:0]  op_in;
    logic signed [31:0] product_conv;
    assign op_in = in_bounds ? imem[in_idx[IN_AW-1:0]] : 8'sd0;
    assign product_conv = 32'($signed(op_in) * $signed(wconv[wc_idx[WC_AW-1:0]]));

    logic signed [31:0] product_fc;
    assign product_fc = 32'($signed(actm[ii[ACT_AW-1:0]]) * $signed(wfc[wf_idx[WF_AW-1:0]]));

    // requant: ReLU -> >>>SHIFT -> clamp[0,127]
    function automatic logic signed [7:0] requant(input logic signed [31:0] a);
        logic signed [31:0] t;
        begin
            t = (a < 0) ? 32'sd0 : a;
            t = t >>> SHIFT;
            if (t > 127) t = 127;
            requant = t[7:0];
        end
    endfunction

    logic done_pulse;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            st <= S_IDLE; busy_o <= 1'b0; done_o <= 1'b0; error_o <= 1'b0;
            done_pulse <= 1'b0; cycle_cnt_o <= 32'd0; argmax_o <= 8'd0;
            c<=0; oy<=0; ox<=0; ky<=0; kx<=0; f<=0; ii<=0; am_f<=0;
            acc<=0; am_best<=0; am_idx<=0;
        end else begin
            done_pulse <= 1'b0;
            if (sw_reset_i) begin
                st <= S_IDLE; busy_o <= 1'b0; done_o <= 1'b0; error_o <= 1'b0;
            end else begin
                if (busy_o) cycle_cnt_o <= cycle_cnt_o + 1;
                case (st)
                    // ---------------- IDLE ----------------
                    S_IDLE: begin
                        if (start_i) begin
                            busy_o<=1'b1; done_o<=1'b0; error_o<=1'b0;
                            cycle_cnt_o<=32'd0;
                            c<=0; oy<=0; ox<=0;
                            st<=S_CONV_LOAD;
                        end
                    end
                    // ---------------- CONV ----------------
                    S_CONV_LOAD: begin
                        acc <= bconv[c[BC_AW-1:0]];
                        ky<=0; kx<=0;
                        st<=S_CONV_MAC;
                    end
                    S_CONV_MAC: begin
                        acc <= acc + product_conv;
                        if (kx < K_W-1) begin
                            kx <= kx + 1;
                        end else begin
                            kx <= 0;
                            if (ky < K_H-1) ky <= ky + 1;
                            else            st <= S_CONV_STORE;
                        end
                    end
                    S_CONV_STORE: begin
                        actm[act_idx[ACT_AW-1:0]] <= requant(acc);
                        // sonraki cikis pozisyonu
                        if (ox < OUT_W-1) begin
                            ox <= ox + 1; st <= S_CONV_LOAD;
                        end else begin
                            ox <= 0;
                            if (oy < OUT_H-1) begin
                                oy <= oy + 1; st <= S_CONV_LOAD;
                            end else begin
                                oy <= 0;
                                if (c < N_FILT-1) begin
                                    c <= c + 1; st <= S_CONV_LOAD;
                                end else begin
                                    // conv bitti -> FC
                                    f <= 0; st <= S_FC_LOAD;
                                end
                            end
                        end
                    end
                    // ---------------- FC ----------------
                    S_FC_LOAD: begin
                        acc <= bfc[f[BF_AW-1:0]];
                        ii <= 0;
                        st <= S_FC_MAC;
                    end
                    S_FC_MAC: begin
                        acc <= acc + product_fc;
                        if (ii < FEAT-1) ii <= ii + 1;
                        else             st <= S_FC_STORE;
                    end
                    S_FC_STORE: begin
                        logitm[f[BF_AW-1:0]] <= acc;
                        if (f < FC_OUT-1) begin
                            f <= f + 1; st <= S_FC_LOAD;
                        end else begin
                            am_f<=0; am_best<=32'sh8000_0000; am_idx<=0;
                            st<=S_ARGMAX;
                        end
                    end
                    // ---------------- ARGMAX ----------------
                    S_ARGMAX: begin
                        if (logitm[am_f[BF_AW-1:0]] > am_best) begin
                            am_best <= logitm[am_f[BF_AW-1:0]];
                            am_idx  <= am_f;
                        end
                        if (am_f < FC_OUT-1) am_f <= am_f + 1;
                        else begin
                            argmax_o <= (logitm[am_f[BF_AW-1:0]] > am_best) ? am_f[7:0] : am_idx[7:0];
                            st <= S_DONE;
                        end
                    end
                    // ---------------- DONE ----------------
                    S_DONE: begin
                        busy_o<=1'b0; done_o<=1'b1; done_pulse<=1'b1;
                        st<=S_IDLE;
                    end
                    default: st<=S_IDLE;
                endcase
            end
        end
    end

    assign irq_o = done_pulse;

endmodule
