// ============================================================================
// obi_to_axi_lite.sv  -- OBI Master to AXI4-Lite Master Bridge
//
// CV32E40P core OBI uretiyor. Sartname EK-2 cevre birim baglantilari icin
// AXI4-Lite bus istiyor. Bu bridge OBI master cikisini AXI4-Lite master
// cikisina cevirir. Iki instance kullanilabilir: biri instr port icin, biri
// data port icin.
//
// Mimari:
//   OBI master cikisi (CV32E40P)         AXI4-Lite master (sistem icine)
//   ===========================         =============================
//     req_o, addr_o, we_o,         -->    AW kanal (yazma adresi)
//     wdata_o, wstrb_o, gnt_i             W  kanal (yazma data)
//     rvalid_i, rdata_i                   B  kanal (yazma response)
//                                         AR kanal (okuma adresi)
//                                         R  kanal (okuma data)
//
// State Machine:
//   IDLE         -> req=0, AXI sinyaller hep VALID=0
//   WRITE_ADDR   -> req+we=1 ise: AW kanali, gnt = awready
//   WRITE_DATA   -> W kanali, wready bekle
//   WRITE_RESP   -> B kanali, bvalid bekle, OBI rvalid yapar
//   READ_ADDR    -> req+!we=1 ise: AR kanali, gnt = arready
//   READ_DATA    -> R kanali, rvalid bekle, OBI rvalid yapar
//
// AXI4-Lite Protokol:
//   - Tum cevre birimler AXI4-Lite slave (Sartname EK-2)
//   - Write: AW + W -> B response
//   - Read:  AR -> R response
//   - 32-bit data, 32-bit addr (sadece [31:0] ada bit)
// ============================================================================

module obi_to_axi_lite #(
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    // OBI master tarafi (CV32E40P'den gelir)
    input  logic                    obi_req_i,
    output logic                    obi_gnt_o,
    output logic                    obi_rvalid_o,
    input  logic                    obi_we_i,
    input  logic [3:0]              obi_be_i,
    input  logic [ADDR_WIDTH-1:0]   obi_addr_i,
    input  logic [DATA_WIDTH-1:0]   obi_wdata_i,
    output logic [DATA_WIDTH-1:0]   obi_rdata_o,

    // AXI4-Lite master tarafi (cevre birimlerine)
    // Write Address Channel
    output logic                    axi_awvalid_o,
    input  logic                    axi_awready_i,
    output logic [ADDR_WIDTH-1:0]   axi_awaddr_o,
    output logic [2:0]              axi_awprot_o,

    // Write Data Channel
    output logic                    axi_wvalid_o,
    input  logic                    axi_wready_i,
    output logic [DATA_WIDTH-1:0]   axi_wdata_o,
    output logic [3:0]              axi_wstrb_o,

    // Write Response Channel
    input  logic                    axi_bvalid_i,
    output logic                    axi_bready_o,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [1:0]              axi_bresp_i,
    /* verilator lint_on UNUSEDSIGNAL */

    // Read Address Channel
    output logic                    axi_arvalid_o,
    input  logic                    axi_arready_i,
    output logic [ADDR_WIDTH-1:0]   axi_araddr_o,
    output logic [2:0]              axi_arprot_o,

    // Read Data Channel
    input  logic                    axi_rvalid_i,
    output logic                    axi_rready_o,
    input  logic [DATA_WIDTH-1:0]   axi_rdata_i,
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic [1:0]              axi_rresp_i
    /* verilator lint_on UNUSEDSIGNAL */
);

    // ------------------------------------------------------------------------
    // State Machine
    // ------------------------------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE       = 3'd0,
        S_WRITE_AW   = 3'd1,  // AW kanali aktif (awvalid bekliyor)
        S_WRITE_W    = 3'd2,  // W kanali aktif (wvalid bekliyor)
        S_WRITE_RESP = 3'd3,  // B kanali (bvalid bekleniyor)
        S_READ_AR    = 3'd4,  // AR kanali aktif (arvalid bekliyor)
        S_READ_R     = 3'd5   // R kanali (rvalid bekleniyor)
    } state_e;

    state_e state_q;
    logic [ADDR_WIDTH-1:0] addr_q;     // OBI adresinin latch'lenmis hali
    logic [DATA_WIDTH-1:0] wdata_q;    // OBI yazma datasinin latch'lenmis hali
    logic [3:0]            wstrb_q;    // OBI byte enable latch
    logic                  axi_aw_done; // AW handshake oldu mu
    logic                  axi_w_done;  // W handshake oldu mu

    // ------------------------------------------------------------------------
    // AXI4-Lite Sabit Sinyaller
    // ------------------------------------------------------------------------
    assign axi_awprot_o = 3'b000;  // unprivileged, secure, data access
    assign axi_arprot_o = 3'b000;
    assign axi_awaddr_o = addr_q;
    assign axi_araddr_o = addr_q;
    assign axi_wdata_o  = wdata_q;
    assign axi_wstrb_o  = wstrb_q;
    assign axi_bready_o = (state_q == S_WRITE_RESP);
    assign axi_rready_o = (state_q == S_READ_R);

    // ------------------------------------------------------------------------
    // OBI Cevap Sinyalleri
    // ------------------------------------------------------------------------
    // gnt: IDLE'da req=1 oldugu cycle verilir (1-cycle handshake)
    assign obi_gnt_o = (state_q == S_IDLE) && obi_req_i;

    // rvalid: write icin bvalid geldiginde, read icin rvalid geldiginde
    assign obi_rvalid_o = ((state_q == S_WRITE_RESP) && axi_bvalid_i) ||
                          ((state_q == S_READ_R)     && axi_rvalid_i);

    // rdata: read response geldiginde AXI rdata, aksi halde 0
    assign obi_rdata_o = ((state_q == S_READ_R) && axi_rvalid_i) ?
                         axi_rdata_i : 32'h0;

    // AXI valid sinyaller (state'e gore)
    assign axi_awvalid_o = (state_q == S_WRITE_AW) && !axi_aw_done;
    assign axi_wvalid_o  = ((state_q == S_WRITE_AW) || (state_q == S_WRITE_W)) && !axi_w_done;
    assign axi_arvalid_o = (state_q == S_READ_AR);

    // ------------------------------------------------------------------------
    // Ana State Machine
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q     <= S_IDLE;
            addr_q      <= '0;
            wdata_q     <= '0;
            wstrb_q     <= '0;
            axi_aw_done <= 1'b0;
            axi_w_done  <= 1'b0;
        end else begin
            case (state_q)
                // ----------------------------------------------------------------
                S_IDLE: begin
                    axi_aw_done <= 1'b0;
                    axi_w_done  <= 1'b0;
                    if (obi_req_i) begin
                        addr_q  <= obi_addr_i;
                        wdata_q <= obi_wdata_i;
                        wstrb_q <= obi_be_i;
                        if (obi_we_i)
                            state_q <= S_WRITE_AW;
                        else
                            state_q <= S_READ_AR;
                    end
                end
                // ----------------------------------------------------------------
                S_WRITE_AW: begin
                    // AW ve W ayni anda gonderebiliriz (basit AXI4-Lite slave)
                    if (axi_awvalid_o && axi_awready_i)
                        axi_aw_done <= 1'b1;
                    if (axi_wvalid_o && axi_wready_i)
                        axi_w_done  <= 1'b1;

                    // Her ikisi tamamlandiginda B response bekle
                    if ((axi_aw_done || (axi_awvalid_o && axi_awready_i)) &&
                        (axi_w_done  || (axi_wvalid_o  && axi_wready_i))) begin
                        state_q     <= S_WRITE_RESP;
                        axi_aw_done <= 1'b0;
                        axi_w_done  <= 1'b0;
                    end
                end
                // ----------------------------------------------------------------
                S_WRITE_RESP: begin
                    if (axi_bvalid_i)
                        state_q <= S_IDLE;
                end
                // ----------------------------------------------------------------
                S_READ_AR: begin
                    if (axi_arvalid_o && axi_arready_i)
                        state_q <= S_READ_R;
                end
                // ----------------------------------------------------------------
                S_READ_R: begin
                    if (axi_rvalid_i)
                        state_q <= S_IDLE;
                end
                // ----------------------------------------------------------------
                default: state_q <= S_IDLE;
            endcase
        end
    end

endmodule
