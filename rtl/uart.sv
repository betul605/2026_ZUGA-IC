// ============================================================================
// uart.sv
// Sartname EK-2 uyumlu UART modulu (Faz 1 - davranissal).
//
// Yazmac haritasi:
//   0x00  UART_CPB   RW   Clock-per-bit (baud bolucu)         [Faz 2]
//   0x04  UART_STP   RW   Stop bit secim                      [Faz 2]
//   0x08  UART_RDR   RO   Receive data register               [Faz 3]
//   0x0C  UART_TDR   RW   Transmit data register
//   0x10  UART_CFG   RW   [0]=TX_EN, [1]=RX_DONE, [2]=TX_DONE
//
// Faz 1 davranisi: CFG[0]=1 (TX enable) iken TDR'ye yazilan veri
// $write ile terminale basilir, CFG[2] (TX complete) hemen set edilir.
// Reset sonrasi CFG=0x01 (TX_EN=1 default), geriye uyumluluk icin.
// ============================================================================
module uart (
    input  logic        clk_i,
    input  logic        rst_ni,

    // OBI slave
    input  logic        req_i,
    output logic        gnt_o,
    output logic        rvalid_o,
    input  logic        we_i,
    input  logic [3:0]  be_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o
);

    // EK-2 yazmaclari
    logic [31:0] cpb_q;   // 0x00  Clock-per-bit
    logic [31:0] stp_q;   // 0x04  Stop bit
    logic [31:0] rdr_q;   // 0x08  RX data
    logic [31:0] tdr_q;   // 0x0C  TX data
    logic [31:0] cfg_q;   // 0x10  Config

    // Adres dekod
    wire is_cpb = (addr_i[4:2] == 3'b000);
    wire is_stp = (addr_i[4:2] == 3'b001);
    wire is_rdr = (addr_i[4:2] == 3'b010);
    wire is_tdr = (addr_i[4:2] == 3'b011);
    wire is_cfg = (addr_i[4:2] == 3'b100);

    assign gnt_o = req_i;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cpb_q    <= 32'd5000;
            stp_q    <= 32'h0;
            rdr_q    <= 32'h0;
            tdr_q    <= 32'h0;
            cfg_q    <= 32'h00000001;
            rvalid_o <= 1'b0;
            rdata_o  <= 32'h0;
        end else begin
            rvalid_o <= req_i && gnt_o;

            cfg_q[2] <= 1'b0;

            if (req_i && gnt_o && we_i) begin
                if      (is_cpb) cpb_q <= wdata_i;
                else if (is_stp) stp_q <= wdata_i;
                else if (is_tdr) begin
                    tdr_q <= wdata_i;
                    if (cfg_q[0]) begin
                        $write("%c", wdata_i[7:0]);
                        $fflush();
                        cfg_q[2] <= 1'b1;
                    end
                end
                else if (is_cfg) begin
                    cfg_q[0] <= wdata_i[0];
                    if (wdata_i[1] == 1'b0) cfg_q[1] <= 1'b0;
                    if (wdata_i[2] == 1'b0) cfg_q[2] <= 1'b0;
                end
            end

            if (req_i && gnt_o && !we_i) begin
                if      (is_cpb) rdata_o <= cpb_q;
                else if (is_stp) rdata_o <= stp_q;
                else if (is_rdr) rdata_o <= rdr_q;
                else if (is_tdr) rdata_o <= tdr_q;
                else if (is_cfg) rdata_o <= cfg_q;
                else             rdata_o <= 32'h0;
            end
        end
    end

endmodule
