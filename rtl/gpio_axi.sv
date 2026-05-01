// ============================================================================
// gpio_axi.sv  -- AXI4-Lite Slave GPIO (32-bit, sartname EK-2 uyumlu)
//
// Yazmac haritasi (Sartname EK-2):
//   Offset 0x00  GPIO_IDR  RO  [15:0]=gpio_in, [31:16]=0 (her zaman)
//   Offset 0x04  GPIO_ODR  RW  [15:0] cikis pinleri, [31:16] etkisiz
//
// Toplam 32 pin (16 in + 16 out) — Sartname EK-2 net diyor.
// ============================================================================

module gpio_axi (
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
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [31:0] axi_wdata_i,
    /* verilator lint_on UNUSEDSIGNAL */
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

    // GPIO pinleri (32-bit: 16 in + 16 out)
    input  logic [15:0] gpio_in_i,
    output logic [15:0] gpio_out_o
);

    // ------------------------------------------------------------------------
    // Yazmac
    // ------------------------------------------------------------------------
    logic [15:0] gpio_odr_q;
    assign gpio_out_o = gpio_odr_q;

    // ------------------------------------------------------------------------
    // Adres dekod (addr[3:2] = offset/4)
    // ------------------------------------------------------------------------
    /* verilator lint_off UNUSEDSIGNAL */
    logic is_idr_w, is_odr_w;
    /* verilator lint_on UNUSEDSIGNAL */
    logic is_idr_r, is_odr_r;
    assign is_idr_w = (axi_awaddr_i[3:2] == 2'b00);
    assign is_odr_w = (axi_awaddr_i[3:2] == 2'b01);
    assign is_idr_r = (axi_araddr_i[3:2] == 2'b00);
    assign is_odr_r = (axi_araddr_i[3:2] == 2'b01);

    // ------------------------------------------------------------------------
    // State Machine (3 durum)
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
    // Ana state machine + register update
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q     <= S_IDLE;
            gpio_odr_q  <= 16'h0;
            read_data_q <= 32'h0;
        end else begin
            case (state_q)
                S_IDLE: begin
                    // Yazma istegi
                    if (axi_awvalid_i && axi_wvalid_i) begin
                        if (is_odr_w) begin
                            // Sadece [15:0] etkili, ust 16 bit yok say
                            gpio_odr_q <= axi_wdata_i[15:0];
                        end
                        // is_idr_w yazilamaz (RO), sessizce yok say
                        state_q <= S_WRITE_RESP;
                    end
                    // Okuma istegi
                    else if (axi_arvalid_i) begin
                        if (is_idr_r) begin
                            // GPIO_IDR: [15:0]=gpio_in, [31:16]=0
                            read_data_q <= {16'h0, gpio_in_i};
                        end else if (is_odr_r) begin
                            // GPIO_ODR: [15:0]=gpio_odr_q, [31:16]=0
                            read_data_q <= {16'h0, gpio_odr_q};
                        end else begin
                            read_data_q <= 32'h0;  // Bilinmeyen adres
                        end
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
