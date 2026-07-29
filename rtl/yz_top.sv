// ============================================================================
// yz_top.sv  --  YZ Hizlandirici SoC sarmalayicisi (AXI4-Lite slave)
//
// Tek AXI4-Lite slave; pencere 0x50xx_xxxx. Alt bolge addr[23:20],
// bolge-ici word ofseti addr[17:2] (<=64K word):
//   0x5000_0000 : CSR (yz_csr, 8 yazmac)         -> kontrol/durum
//   0x5010_0000 : giris ozniteligi SRAM (input)  -> CPU yazar
//   0x5020_0000 : conv agirliklari (wconv)       -> CPU yazar
//   0x5030_0000 : conv bias (bconv)              -> CPU yazar
//   0x5040_0000 : FC agirliklari (wfc)           -> CPU yazar
//   0x5050_0000 : FC bias (bfc)                  -> CPU yazar
//   0x5060_0000 : logit okuma (RO)               -> CPU okur (ISR)
// 1 MB bolge araligi tam Tiny Conv agirliklarini (wfc 16000 word) barindirir.
//
// Akis (sartname EK-1): CPU agirlik+girisi bu pencerelere yazar, CSR.CTRL[0]
// (START) ile cikarimi baslatir; yz_accel biter -> STATUS.DONE=1 + irq_o.
// CPU ISR logit'leri 0x5060_0000'den okur.
// ============================================================================
module yz_top #(
    parameter int IN_H   = 8,  parameter int IN_W  = 8,
    parameter int K_H    = 3,  parameter int K_W   = 3,
    parameter int STRIDE = 1,  parameter int N_FILT= 2,
    parameter int OUT_H  = 8,  parameter int OUT_W = 8,
    parameter int FEAT   = 128,parameter int FC_OUT= 4,
    parameter int SHIFT  = 6,  parameter int PAD_H = 1, parameter int PAD_W = 1
)(
    input  logic        clk_i,
    input  logic        rst_ni,
    // AXI4-Lite slave
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    input  logic [31:0] axi_awaddr_i,
    input  logic [2:0]  axi_awprot_i,
    input  logic        axi_wvalid_i,
    output logic        axi_wready_o,
    input  logic [31:0] axi_wdata_i,
    input  logic [3:0]  axi_wstrb_i,
    output logic        axi_bvalid_o,
    input  logic        axi_bready_i,
    output logic [1:0]  axi_bresp_o,
    input  logic        axi_arvalid_i,
    output logic        axi_arready_o,
    input  logic [31:0] axi_araddr_i,
    input  logic [2:0]  axi_arprot_i,
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    output logic [31:0] axi_rdata_o,
    output logic [1:0]  axi_rresp_o,
    // Kesme (CPU'ya)
    output logic        irq_o
);
    // -------- Alt bolge secimi (addr[23:20]) --------
    // 0 = CSR, 1..5 = veri bellekleri, 6 = logit okuma
    logic       csr_wr_sel, csr_rd_sel, mem_wr_sel, log_rd_sel;
    assign csr_wr_sel = (axi_awaddr_i[23:20] == 4'h0);
    assign csr_rd_sel = (axi_araddr_i[23:20] == 4'h0);
    assign mem_wr_sel = (axi_awaddr_i[23:20] >= 4'h1) && (axi_awaddr_i[23:20] <= 4'h5);
    assign log_rd_sel = (axi_araddr_i[23:20] == 4'h6);

    // ============================ CSR (yz_csr) ============================
    logic        c_awready, c_wready, c_bvalid, c_arready, c_rvalid;
    logic [1:0]  c_bresp, c_rresp;
    logic [31:0] c_rdata;

    logic        yz_start, yz_swrst, yz_busy, yz_done, yz_error;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] yz_in_addr, yz_out_addr, yz_wt_addr, yz_len;
    logic [3:0]  yz_ksize, yz_stride;
    /* verilator lint_on UNUSEDSIGNAL */

    yz_csr u_csr (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .axi_awvalid_i(axi_awvalid_i & csr_wr_sel), .axi_awready_o(c_awready),
        .axi_awaddr_i(axi_awaddr_i), .axi_awprot_i(axi_awprot_i),
        .axi_wvalid_i(axi_wvalid_i & csr_wr_sel), .axi_wready_o(c_wready),
        .axi_wdata_i(axi_wdata_i), .axi_wstrb_i(axi_wstrb_i),
        .axi_bvalid_o(c_bvalid), .axi_bready_i(axi_bready_i & csr_wr_sel), .axi_bresp_o(c_bresp),
        .axi_arvalid_i(axi_arvalid_i & csr_rd_sel), .axi_arready_o(c_arready),
        .axi_araddr_i(axi_araddr_i), .axi_arprot_i(axi_arprot_i),
        .axi_rvalid_o(c_rvalid), .axi_rready_i(axi_rready_i & csr_rd_sel), .axi_rdata_o(c_rdata), .axi_rresp_o(c_rresp),
        .start_o(yz_start), .sw_reset_o(yz_swrst),
        .busy_i(yz_busy), .done_i(yz_done), .error_i(yz_error),
        .input_addr_o(yz_in_addr), .output_addr_o(yz_out_addr), .weight_addr_o(yz_wt_addr),
        .kernel_size_o(yz_ksize), .stride_o(yz_stride), .len_o(yz_len)
    );

    // ======================== Datapath (yz_accel) ========================
    logic [15:0] logit_addr;
    logic [31:0] logit_rdata;
    logic        mem_we;
    logic [2:0]  mem_region;
    logic [15:0] mem_addr;
    logic [31:0] mem_wdata;

    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] yz_cyc;    // performans sayaci (CSR kendi sayacini tutuyor)
    logic [7:0]  yz_argmax; // argmax (logit'lerden CPU da hesaplayabilir)
    /* verilator lint_on UNUSEDSIGNAL */

    yz_accel #(
        .IN_H(IN_H), .IN_W(IN_W), .K_H(K_H), .K_W(K_W), .STRIDE(STRIDE),
        .N_FILT(N_FILT), .OUT_H(OUT_H), .OUT_W(OUT_W), .FEAT(FEAT),
        .FC_OUT(FC_OUT), .SHIFT(SHIFT), .PAD_H(PAD_H), .PAD_W(PAD_W)
        // dosya init YOK -> CPU AXI uzerinden yukler
    ) u_accel (
        .clk_i(clk_i), .rst_ni(rst_ni),
        .start_i(yz_start), .sw_reset_i(yz_swrst),
        .busy_o(yz_busy), .done_o(yz_done), .error_o(yz_error), .irq_o(irq_o),
        .cycle_cnt_o(yz_cyc), .argmax_o(yz_argmax),
        .logit_addr_i(logit_addr), .logit_rdata_o(logit_rdata),
        .mem_we_i(mem_we), .mem_region_i(mem_region), .mem_addr_i(mem_addr), .mem_wdata_i(mem_wdata)
    );

    // ============ Veri bellek yazma + logit okuma AXI4-Lite slave ============
    // 3 durumlu FSM (yz_csr ile ayni desen)
    typedef enum logic [1:0] { D_IDLE, D_WRESP, D_RRESP } dstate_e;
    dstate_e d_st;
    logic [31:0] d_rdata;

    logic        d_awready, d_wready, d_bvalid, d_arready, d_rvalid;
    assign d_awready = (d_st == D_IDLE) && axi_awvalid_i && axi_wvalid_i && mem_wr_sel;
    assign d_wready  = d_awready;
    assign d_arready = (d_st == D_IDLE) && axi_arvalid_i && log_rd_sel;
    assign d_bvalid  = (d_st == D_WRESP);
    assign d_rvalid  = (d_st == D_RRESP);

    // logit okuma adresi (bolge-ici word ofseti)
    assign logit_addr = axi_araddr_i[17:2];

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            d_st <= D_IDLE; d_rdata <= 32'h0;
            mem_we <= 1'b0; mem_region <= 3'd0; mem_addr <= 16'd0; mem_wdata <= 32'd0;
        end else begin
            mem_we <= 1'b0;  // varsayilan: 1-cycle pulse
            case (d_st)
                D_IDLE: begin
                    if (axi_awvalid_i && axi_wvalid_i && mem_wr_sel) begin
                        // region: addr[15:12] 1..5 -> 0..4
                        mem_region <= (axi_awaddr_i[22:20] - 3'd1);
                        mem_addr   <= axi_awaddr_i[17:2];  // bolge-ici word ofseti
                        mem_wdata  <= axi_wdata_i;
                        mem_we     <= 1'b1;
                        d_st       <= D_WRESP;
                    end else if (axi_arvalid_i && log_rd_sel) begin
                        d_rdata <= logit_rdata;
                        d_st    <= D_RRESP;
                    end
                end
                D_WRESP: if (axi_bready_i) d_st <= D_IDLE;
                D_RRESP: if (axi_rready_i) d_st <= D_IDLE;
                default: d_st <= D_IDLE;
            endcase
        end
    end

    // ==================== AXI cevap mux (CSR vs veri) ====================
    assign axi_awready_o = csr_wr_sel ? c_awready : d_awready;
    assign axi_wready_o  = csr_wr_sel ? c_wready  : d_wready;
    assign axi_bvalid_o  = csr_wr_sel ? c_bvalid  : d_bvalid;
    assign axi_bresp_o   = csr_wr_sel ? c_bresp   : 2'b00;
    assign axi_arready_o = csr_rd_sel ? c_arready : d_arready;
    assign axi_rvalid_o  = csr_rd_sel ? c_rvalid  : d_rvalid;
    assign axi_rdata_o   = csr_rd_sel ? c_rdata   : d_rdata;
    assign axi_rresp_o   = csr_rd_sel ? c_rresp   : 2'b00;

endmodule
