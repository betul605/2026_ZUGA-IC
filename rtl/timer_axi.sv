// ============================================================================
// timer_axi.sv  -- AXI4-Lite Slave Timer (sartname EK-2 tam uyumlu)
//
// Yazmac haritasi (Sartname EK-2):
//   0x00  TIM_PRE  RW  Prescaler (saat bolme katsayisi)
//   0x04  TIM_ARE  RW  Auto-reload (sayac limiti)
//   0x08  TIM_CLR  RW  Clear (1 yazilirsa sayac 0 olur)
//   0x0C  TIM_ENA  RW  Enable (1 = sayac calisir, 0 = duraklar)
//   0x10  TIM_MOD  RW  Mode (1 = yukari say, 0 = asagi say)
//   0x14  TIM_CNT  RO  Mevcut sayac degeri
//   0x18  TIM_EVN  RO  Event sayisi (TIM_CNT == TIM_ARE oldugunda +1)
//   0x1C  TIM_EVC  RW  Event clear (1 yazilirsa TIM_EVN 0 olur)
//
// Sayac mantigi:
//   - Prescaler: TIM_PRE+1 saat vurusunda 1 saymak (orn TIM_PRE=0 -> her saat 1)
//   - Auto-reload: TIM_CNT == TIM_ARE'a ulasinca TIM_EVN++, TIM_CNT 0'a doner
//   - Mode 1: yukari say (0 -> ARE -> 0 -> ARE ...)
//   - Mode 0: asagi say (ARE -> 0 -> ARE -> 0 ...)
// ============================================================================

module timer_axi (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Write Address Channel
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] axi_awaddr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0]  axi_awprot_i,
    /* verilator lint_on UNUSEDSIGNAL */

    // Write Data Channel
    input  logic        axi_wvalid_i,
    output logic        axi_wready_o,
    input  logic [31:0] axi_wdata_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [3:0]  axi_wstrb_i,
    /* verilator lint_on UNUSEDSIGNAL */

    // Write Response Channel
    output logic        axi_bvalid_o,
    input  logic        axi_bready_i,
    output logic [1:0]  axi_bresp_o,

    // Read Address Channel
    input  logic        axi_arvalid_i,
    output logic        axi_arready_o,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] axi_araddr_i,
    /* verilator lint_on UNUSEDSIGNAL */
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [2:0]  axi_arprot_i,
    /* verilator lint_on UNUSEDSIGNAL */

    // Read Data Channel
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    output logic [31:0] axi_rdata_o,
    output logic [1:0]  axi_rresp_o
);

    // ------------------------------------------------------------------------
    // Yazmaclar (Sartname EK-2)
    // ------------------------------------------------------------------------
    logic [31:0] tim_pre_q;   // 0x00 Prescaler
    logic [31:0] tim_are_q;   // 0x04 Auto-reload
    logic [31:0] tim_cnt_q;   // 0x14 Counter (RO disaridan)
    logic [31:0] tim_evn_q;   // 0x18 Event counter (RO disaridan)
    logic        tim_ena_q;   // 0x0C Enable
    logic        tim_mod_q;   // 0x10 Mode (1=yukari, 0=asagi)

    // Prescaler ic sayac (TIM_PRE+1 saat vurusunda 1 tetik uretir)
    logic [31:0] pre_cnt_q;
    logic        pre_tick;
    assign pre_tick = (pre_cnt_q == tim_pre_q);

    // ------------------------------------------------------------------------
    // Adres dekod (addr[4:2] = offset/4)
    // ------------------------------------------------------------------------
    logic [2:0] w_off;
    logic [2:0] r_off;
    assign w_off = axi_awaddr_i[4:2];
    assign r_off = axi_araddr_i[4:2];

    // ------------------------------------------------------------------------
    // Yazma sinyalleri (write-strobe + adres bazli)
    // ------------------------------------------------------------------------
    logic write_strobe;
    assign write_strobe = axi_awvalid_i && axi_wvalid_i && axi_awready_o;

    logic do_clr;
    logic do_evc;
    assign do_clr = write_strobe && (w_off == 3'h2) && axi_wdata_i[0];  // 0x08
    assign do_evc = write_strobe && (w_off == 3'h7) && axi_wdata_i[0];  // 0x1C

    // ------------------------------------------------------------------------
    // Yazmac update (yazma)
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tim_pre_q <= 32'h0;
            tim_are_q <= 32'hFFFF_FFFF;  // Default max
            tim_ena_q <= 1'b0;
            tim_mod_q <= 1'b1;           // Default yukari
        end else if (write_strobe) begin
            case (w_off)
                3'h0: tim_pre_q <= axi_wdata_i;             // 0x00 PRE
                3'h1: tim_are_q <= axi_wdata_i;             // 0x04 ARE
                3'h3: tim_ena_q <= axi_wdata_i[0];          // 0x0C ENA
                3'h4: tim_mod_q <= axi_wdata_i[0];          // 0x10 MOD
                default: ; // CLR (0x08), CNT (0x14), EVN (0x18), EVC (0x1C) handle edilir
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Prescaler counter
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pre_cnt_q <= 32'h0;
        end else if (tim_ena_q) begin
            if (pre_tick) begin
                pre_cnt_q <= 32'h0;
            end else begin
                pre_cnt_q <= pre_cnt_q + 1;
            end
        end else begin
            pre_cnt_q <= 32'h0;  // Disabled iken sifirla
        end
    end

    // ------------------------------------------------------------------------
    // Ana sayac (TIM_CNT) + Event sayac (TIM_EVN)
    // ------------------------------------------------------------------------
    logic cnt_at_limit;
    assign cnt_at_limit = tim_mod_q ? (tim_cnt_q == tim_are_q) : (tim_cnt_q == 32'h0);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tim_cnt_q <= 32'h0;
            tim_evn_q <= 32'h0;
        end else begin
            // Clear oncelikli
            if (do_clr) begin
                tim_cnt_q <= 32'h0;
            end else if (tim_ena_q && pre_tick) begin
                if (cnt_at_limit) begin
                    // Limit'e ulasti, event uret + sayaci dondur
                    tim_evn_q <= tim_evn_q + 1;
                    tim_cnt_q <= tim_mod_q ? 32'h0 : tim_are_q;
                end else begin
                    tim_cnt_q <= tim_mod_q ? (tim_cnt_q + 1) : (tim_cnt_q - 1);
                end
            end

            // Event clear (CLR'den bagimsiz)
            if (do_evc) begin
                tim_evn_q <= 32'h0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // AXI4-Lite State Machine
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {
        S_IDLE       = 2'd0,
        S_WRITE_RESP = 2'd1,
        S_READ_RESP  = 2'd2
    } state_e;

    state_e state_q;
    logic [31:0] read_data_q;

    // Sabit cevap kodlari
    assign axi_bresp_o = 2'b00;  // OKAY
    assign axi_rresp_o = 2'b00;  // OKAY

    // Hazir sinyaller
    assign axi_awready_o = (state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_wready_o  = (state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_arready_o = (state_q == S_IDLE) && axi_arvalid_i;
    assign axi_bvalid_o  = (state_q == S_WRITE_RESP);
    assign axi_rvalid_o  = (state_q == S_READ_RESP);
    assign axi_rdata_o   = read_data_q;

    // ------------------------------------------------------------------------
    // Read mux + State machine
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q     <= S_IDLE;
            read_data_q <= 32'h0;
        end else begin
            case (state_q)
                S_IDLE: begin
                    if (axi_awvalid_i && axi_wvalid_i) begin
                        state_q <= S_WRITE_RESP;
                    end else if (axi_arvalid_i) begin
                        // Read mux: hangi yazmac okunuyor?
                        case (r_off)
                            3'h0: read_data_q <= tim_pre_q;       // 0x00 PRE
                            3'h1: read_data_q <= tim_are_q;       // 0x04 ARE
                            3'h2: read_data_q <= 32'h0;           // 0x08 CLR (write-only, 0 don)
                            3'h3: read_data_q <= {31'h0, tim_ena_q};  // 0x0C ENA
                            3'h4: read_data_q <= {31'h0, tim_mod_q};  // 0x10 MOD
                            3'h5: read_data_q <= tim_cnt_q;       // 0x14 CNT
                            3'h6: read_data_q <= tim_evn_q;       // 0x18 EVN
                            3'h7: read_data_q <= 32'h0;           // 0x1C EVC (write-only)
                            default: read_data_q <= 32'h0;
                        endcase
                        state_q <= S_READ_RESP;
                    end
                end
                S_WRITE_RESP: begin
                    if (axi_bready_i) state_q <= S_IDLE;
                end
                S_READ_RESP: begin
                    if (axi_rready_i) state_q <= S_IDLE;
                end
                default: state_q <= S_IDLE;
            endcase
        end
    end

endmodule
