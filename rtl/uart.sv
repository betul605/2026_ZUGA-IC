// ============================================================================
// uart.sv  --  Faz 2: Gerc0ek baud rate generator + 10-bit TX state machine
//
// Sartname EK-2 yazmac haritasi (degisiklik yok):
//   0x00 UART_CPB  RW   Clock-per-bit (baud bolucu)
//   0x04 UART_STP  RW   Stop bit secim (henuz kullanilmiyor, default 1)
//   0x08 UART_RDR  RO   Receive data register (Faz 3)
//   0x0C UART_TDR  RW   Transmit data register
//   0x10 UART_CFG  RW   [0]=TX_EN, [1]=RX_DONE, [2]=TX_DONE
//
// Davranis:
//   - TDR yazma + CFG[0]=1 -> TX state machine baslar
//   - 10-bit dizi: START + 8 DATA + STOP (LSB first)
//   - Her bit CPB cycle kadar surer (gerc0ek baud rate)
//   - tx_o sinyali serial output (FPGA pini)
//   - TX bitince CFG[2] (TX_DONE) set olur
//   - TX surerken yeni TDR yazma yok-sayilir (busy)
//
// Reset degerleri:
//   - CPB = 16 (simulator hizi icin; FPGA'da yazilim 5208 set eder)
//   - CFG = 0x01 (TX_EN default 1, geriye uyumluluk)
//   - tx_o = 1 (idle state)
//
// FPGA'da TX'in gercek serial pini surdugu, $write sadece simulator
// debug icin (synthesis translate_off ile sentez disinda tutulur).
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
    output logic [31:0] rdata_o,

    // Serial output (FPGA pin)
    output logic        tx_o
);

    // ------------------------------------------------------------------------
    // EK-2 yazmaclari
    // ------------------------------------------------------------------------
    logic [31:0] cpb_q;   // 0x00
    logic [31:0] stp_q;   // 0x04
    logic [31:0] rdr_q;   // 0x08
    logic [31:0] tdr_q;   // 0x0C
    logic [31:0] cfg_q;   // 0x10

    // Adres dekod
    wire is_cpb = (addr_i[4:2] == 3'b000);
    wire is_stp = (addr_i[4:2] == 3'b001);
    wire is_rdr = (addr_i[4:2] == 3'b010);
    wire is_tdr = (addr_i[4:2] == 3'b011);
    wire is_cfg = (addr_i[4:2] == 3'b100);

    assign gnt_o = req_i;

    // ------------------------------------------------------------------------
    // TX state machine
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {
        TX_IDLE  = 2'b00,
        TX_START = 2'b01,
        TX_DATA  = 2'b10,
        TX_STOP  = 2'b11
    } tx_state_e;

    tx_state_e   tx_state_q;
    logic [15:0] tx_baud_cnt_q;     // CPB sayici
    logic [3:0]  tx_bit_cnt_q;      // 0..7 data bit
    logic [7:0]  tx_shift_q;        // gonderilecek byte (LSB first)
    logic        tx_start_pulse;    // TDR yazildi + CFG[0]=1 + idle

    // TDR yazma + TX_EN + idle = baslat
    assign tx_start_pulse = req_i && gnt_o && we_i && is_tdr &&
                            cfg_q[0] && (tx_state_q == TX_IDLE);

    // ------------------------------------------------------------------------
    // OBI yazma + okuma (yazmac dosyasi)
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cpb_q    <= 32'd16;        // simulator hizi icin
            stp_q    <= 32'h0;
            rdr_q    <= 32'h0;
            tdr_q    <= 32'h0;
            cfg_q    <= 32'h00000001;  // TX_EN=1 default
            rvalid_o <= 1'b0;
            rdata_o  <= 32'h0;
        end else begin
            rvalid_o <= req_i && gnt_o;

            // CFG[2] (TX_DONE) - asagidaki state machine yonetir
            // CFG[0] - SW yazabilir

            if (req_i && gnt_o && we_i) begin
                if      (is_cpb) cpb_q <= wdata_i;
                else if (is_stp) stp_q <= wdata_i;
                else if (is_tdr) begin
                    if (cfg_q[0] && (tx_state_q == TX_IDLE)) begin
                        tdr_q <= wdata_i;
                    end
                end
                else if (is_cfg) begin
                    cfg_q[0] <= wdata_i[0];
                    if (wdata_i[1] == 1'b0) cfg_q[1] <= 1'b0;
                    if (wdata_i[2] == 1'b0) cfg_q[2] <= 1'b0;
                end
            end

            // OKUMA
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

    // ------------------------------------------------------------------------
    // TX state machine (gerc0ek baud rate generator)
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tx_state_q    <= TX_IDLE;
            tx_baud_cnt_q <= 16'h0;
            tx_bit_cnt_q  <= 4'h0;
            tx_shift_q    <= 8'h0;
            tx_o          <= 1'b1;        // idle = high
        end else begin
            case (tx_state_q)
                TX_IDLE: begin
                    tx_o          <= 1'b1;
                    tx_baud_cnt_q <= 16'h0;
                    tx_bit_cnt_q  <= 4'h0;
                    if (tx_start_pulse) begin
                        tx_shift_q  <= wdata_i[7:0];
                        tx_state_q  <= TX_START;
                        // synthesis translate_off
                        $write("%c", wdata_i[7:0]);
                        $fflush();
                        // synthesis translate_on
                    end
                end

                TX_START: begin
                    tx_o <= 1'b0;        // start bit (low)
                    if (tx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        tx_baud_cnt_q <= 16'h0;
                        tx_state_q    <= TX_DATA;
                    end else begin
                        tx_baud_cnt_q <= tx_baud_cnt_q + 1;
                    end
                end

                TX_DATA: begin
                    tx_o <= tx_shift_q[0];
                    if (tx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        tx_baud_cnt_q <= 16'h0;
                        tx_shift_q    <= {1'b0, tx_shift_q[7:1]};
                        if (tx_bit_cnt_q == 4'd7) begin
                            tx_bit_cnt_q <= 4'h0;
                            tx_state_q   <= TX_STOP;
                        end else begin
                            tx_bit_cnt_q <= tx_bit_cnt_q + 1;
                        end
                    end else begin
                        tx_baud_cnt_q <= tx_baud_cnt_q + 1;
                    end
                end

                TX_STOP: begin
                    tx_o <= 1'b1;        // stop bit (high)
                    if (tx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        tx_baud_cnt_q <= 16'h0;
                        tx_state_q    <= TX_IDLE;
                        cfg_q[2]      <= 1'b1;   // TX_DONE
                    end else begin
                        tx_baud_cnt_q <= tx_baud_cnt_q + 1;
                    end
                end
            endcase
        end
    end

endmodule
