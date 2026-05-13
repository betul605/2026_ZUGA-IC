// ============================================================================
// yz_csr.sv  -- YZ Hizlandirici AXI4-Lite CSR (Control & Status Register)
//
// Sartname §4.2.2 + §5.2 #4 (YZ Hizlandirici) icin CSR modul iskelet
// gpio_axi.sv ve timer_axi.sv yapisina benzer (AXI4-Lite slave + 8 yazmac)
//
// Adres: 0x5000_0000 - 0x5000_001F (32 byte)
// Toplam 8 yazmac:
//   0x00  CTRL          RW   [0]=START, [1]=RESET, [31:2]=reserved
//   0x04  STATUS        RO   [0]=BUSY, [1]=DONE, [2]=ERROR, [31:3]=reserved
//   0x08  INPUT_ADDR    RW   Giris veri SRAM adresi (0x0003_0000-0x0003_77FF)
//   0x0C  OUTPUT_ADDR   RW   Cikis veri SRAM adresi
//   0x10  WEIGHT_ADDR   RW   Agirlik veri SRAM adresi
//   0x14  CFG           RW   [3:0]=KERNEL_SIZE, [7:4]=STRIDE, [31:8]=reserved
//   0x18  LEN           RW   Veri uzunlugu (sample sayisi)
//   0x1C  CYCLE_CNT     RO   Performans sayaci (BUSY iken artar)
//
// Final donemi (1-21 Haz 2026) RTL gerc0eklemesinin BIRINCI bloku.
// CSR modulu calistirinca FSM ve MAC modullerine sinyal gonderir.
// ============================================================================
module yz_csr (
    input  logic        clk_i,
    input  logic        rst_ni,
    // Write Address Channel
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] axi_awaddr_i,
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
    input  logic [2:0]  axi_arprot_i,
    /* verilator lint_on UNUSEDSIGNAL */
    // Read Data Channel
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    output logic [31:0] axi_rdata_o,
    output logic [1:0]  axi_rresp_o,
    // YZ Modulu Bağlantilari (FSM/MAC modullerine)
    output logic        start_o,        // CTRL[0] -> FSM tetikle
    output logic        sw_reset_o,     // CTRL[1] -> FSM reset
    input  logic        busy_i,         // FSM busy
    input  logic        done_i,         // FSM done
    input  logic        error_i,        // FSM error
    output logic [31:0] input_addr_o,   // INPUT_ADDR
    output logic [31:0] output_addr_o,  // OUTPUT_ADDR
    output logic [31:0] weight_addr_o,  // WEIGHT_ADDR
    output logic [3:0]  kernel_size_o,  // CFG[3:0]
    output logic [3:0]  stride_o,       // CFG[7:4]
    output logic [31:0] len_o            // LEN
);

    // ------------------------------------------------------------------------
    // Yazmac dosyasi (8 register)
    // ------------------------------------------------------------------------
    logic [31:0] ctrl_q;       // 0x00 CTRL
    logic [31:0] status_q;     // 0x04 STATUS (RO, FSM tarafindan set olur)
    logic [31:0] input_addr_q; // 0x08
    logic [31:0] output_addr_q;// 0x0C
    logic [31:0] weight_addr_q;// 0x10
    logic [31:0] cfg_q;        // 0x14
    logic [31:0] len_q;        // 0x18
    logic [31:0] cycle_cnt_q;  // 0x1C CYCLE_CNT (BUSY iken artar)

    // Adres ofseti (32-bit aligned, 8 yazmac = 5 bit ofset yeterli)
    logic [4:0] w_off, r_off;
    assign w_off = axi_awaddr_i[4:0];
    assign r_off = axi_araddr_i[4:0];

    // Yazmac->port baglantilari
    assign start_o       = ctrl_q[0];
    assign sw_reset_o    = ctrl_q[1];
    assign input_addr_o  = input_addr_q;
    assign output_addr_o = output_addr_q;
    assign weight_addr_o = weight_addr_q;
    assign kernel_size_o = cfg_q[3:0];
    assign stride_o      = cfg_q[7:4];
    assign len_o         = len_q;

    // STATUS yazmaci (FSM sinyallerinden combinational)
    assign status_q = {29'h0, error_i, done_i, busy_i};

    // ------------------------------------------------------------------------
    // AXI4-Lite State Machine
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {
        S_IDLE       = 2'd0,
        S_WRITE_RESP = 2'd1,
        S_READ_RESP  = 2'd2
    } axi_state_e;
    axi_state_e axi_state_q;
    logic [31:0] read_data_q;

    // AXI cevap kodlari
    assign axi_bresp_o = 2'b00;  // OKAY
    assign axi_rresp_o = 2'b00;  // OKAY

    // Hazir sinyaller
    assign axi_awready_o = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_wready_o  = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_arready_o = (axi_state_q == S_IDLE) && axi_arvalid_i;
    assign axi_bvalid_o  = (axi_state_q == S_WRITE_RESP);
    assign axi_rvalid_o  = (axi_state_q == S_READ_RESP);
    assign axi_rdata_o   = read_data_q;

    // ------------------------------------------------------------------------
    // AXI write + read + yazmac dosyasi
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ctrl_q        <= 32'h0;
            input_addr_q  <= 32'h0;
            output_addr_q <= 32'h0;
            weight_addr_q <= 32'h0;
            cfg_q         <= 32'h0;
            len_q         <= 32'h0;
            cycle_cnt_q   <= 32'h0;
            axi_state_q   <= S_IDLE;
            read_data_q   <= 32'h0;
        end else begin
            // CYCLE_CNT BUSY iken artar
            if (busy_i) cycle_cnt_q <= cycle_cnt_q + 1;
            else if (start_o) cycle_cnt_q <= 32'h0; // START'ta sifirla

            // CTRL[0] (START) tek bir cycle pulse - otomatik clear
            if (ctrl_q[0]) ctrl_q[0] <= 1'b0;

            // AXI state machine
            case (axi_state_q)
                S_IDLE: begin
                    if (axi_awvalid_i && axi_wvalid_i) begin
                        // Yazma
                        case (w_off)
                            5'h00: ctrl_q        <= axi_wdata_i;
                            5'h08: input_addr_q  <= axi_wdata_i;
                            5'h0C: output_addr_q <= axi_wdata_i;
                            5'h10: weight_addr_q <= axi_wdata_i;
                            5'h14: cfg_q         <= axi_wdata_i;
                            5'h18: len_q         <= axi_wdata_i;
                            default: ;  // STATUS (0x04), CYCLE_CNT (0x1C) read-only
                        endcase
                        axi_state_q <= S_WRITE_RESP;
                    end else if (axi_arvalid_i) begin
                        // Okuma
                        case (r_off)
                            5'h00: read_data_q <= ctrl_q;
                            5'h04: read_data_q <= status_q;
                            5'h08: read_data_q <= input_addr_q;
                            5'h0C: read_data_q <= output_addr_q;
                            5'h10: read_data_q <= weight_addr_q;
                            5'h14: read_data_q <= cfg_q;
                            5'h18: read_data_q <= len_q;
                            5'h1C: read_data_q <= cycle_cnt_q;
                            default: read_data_q <= 32'h0;
                        endcase
                        axi_state_q <= S_READ_RESP;
                    end
                end
                S_WRITE_RESP: begin
                    if (axi_bready_i) axi_state_q <= S_IDLE;
                end
                S_READ_RESP: begin
                    if (axi_rready_i) axi_state_q <= S_IDLE;
                end
                default: axi_state_q <= S_IDLE;
            endcase
        end
    end

endmodule
