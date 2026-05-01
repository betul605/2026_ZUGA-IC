// ============================================================================
// ram_axi.sv  -- AXI4-Lite Slave RAM (parametreli, native AXI4-Lite)
//
// Sartname EK-2 ve 4.2.2 gereksinimi:
//   - Cekirdek 8 KB buyruk + 8 KB veri bellegi
//   - Cevre birim arayuzleri AXI4-Lite
//
// Bu modul iki kullanim icin parametreli:
//   - IRAM:  WRITE_ENABLE = 0 (read-only, sadece AR + R kanali)
//   - DRAM:  WRITE_ENABLE = 1 (full read/write, 5 kanal)
//
// Mimari:
//   - Tek state machine (4 durum: IDLE, WRITE, READ, RESP)
//   - 32-bit data, 32-bit addr
//   - Byte enable destek (wstrb)
//   - $readmemh ile bellek init (MEM_FILE)
//
// State Machine:
//   IDLE  -> WRITE: AWVALID + WVALID -> bellege yaz -> RESP
//   IDLE  -> READ:  ARVALID -> bellekten oku -> R kanalindan ver
//   WRITE -> IDLE:  BREADY geldikten sonra
//   READ  -> IDLE:  RREADY geldikten sonra
// ============================================================================

module ram_axi #(
    parameter int unsigned SIZE_WORDS = 2048,    // 8 KB / 4 = 2048 word
    parameter string       MEM_FILE   = "",      // "" ise init yok
    parameter bit          WRITE_ENABLE = 1'b1  // 0 = IRAM (read-only), 1 = DRAM
) (
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
    input  logic [3:0]  axi_wstrb_i,

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
    // Bellek tanimi
    // ------------------------------------------------------------------------
    localparam int unsigned ADDR_WIDTH = $clog2(SIZE_WORDS);
    logic [31:0] mem [SIZE_WORDS];

    initial begin
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, mem);
        end
    end

    logic [ADDR_WIDTH-1:0] write_word_addr;
    logic [ADDR_WIDTH-1:0] read_word_addr;
    assign write_word_addr = axi_awaddr_i[ADDR_WIDTH+1:2];
    assign read_word_addr  = axi_araddr_i[ADDR_WIDTH+1:2];

    // ------------------------------------------------------------------------
    // State Machine
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {
        S_IDLE       = 2'd0,
        S_WRITE_RESP = 2'd1,
        S_READ_RESP  = 2'd2
    } state_e;

    state_e state_q;
    logic [31:0] read_data_q;

    // ------------------------------------------------------------------------
    // Sabit cevap kodlari (AXI4-Lite OKAY)
    // ------------------------------------------------------------------------
    assign axi_bresp_o = 2'b00;
    assign axi_rresp_o = 2'b00;

    // ------------------------------------------------------------------------
    // Hazir sinyaller
    // ------------------------------------------------------------------------
    assign axi_awready_o = WRITE_ENABLE && (state_q == S_IDLE) &&
                           axi_awvalid_i && axi_wvalid_i;
    assign axi_wready_o  = WRITE_ENABLE && (state_q == S_IDLE) &&
                           axi_awvalid_i && axi_wvalid_i;
    assign axi_arready_o = (state_q == S_IDLE) && axi_arvalid_i;

    assign axi_bvalid_o  = (state_q == S_WRITE_RESP);
    assign axi_rvalid_o  = (state_q == S_READ_RESP);
    assign axi_rdata_o   = read_data_q;

    // ------------------------------------------------------------------------
    // Ana State Machine + Bellek operasyonlari
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q     <= S_IDLE;
            read_data_q <= 32'h0;
        end else begin
            case (state_q)
                S_IDLE: begin
                    if (WRITE_ENABLE && axi_awvalid_i && axi_wvalid_i) begin
                        if (axi_wstrb_i[0]) mem[write_word_addr][7:0]   <= axi_wdata_i[7:0];
                        if (axi_wstrb_i[1]) mem[write_word_addr][15:8]  <= axi_wdata_i[15:8];
                        if (axi_wstrb_i[2]) mem[write_word_addr][23:16] <= axi_wdata_i[23:16];
                        if (axi_wstrb_i[3]) mem[write_word_addr][31:24] <= axi_wdata_i[31:24];
                        state_q <= S_WRITE_RESP;
                    end
                    else if (axi_arvalid_i) begin
                        read_data_q <= mem[read_word_addr];
                        state_q     <= S_READ_RESP;
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
