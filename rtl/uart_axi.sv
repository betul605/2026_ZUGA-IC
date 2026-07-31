// ============================================================================
// uart_axi.sv  -- AXI4-Lite Slave UART TX (sartname EK-2 tam uyumlu)
//
// Yazmac haritasi (Sartname EK-2):
//   0x00  UART_CPB  RW   Clock-per-bit (baud bolucu)
//   0x04  UART_STP  RW   Stop bit secim
//   0x08  UART_RDR  RO   Receive data (Faz 3 final)
//   0x0C  UART_TDR  RW   Transmit data
//   0x10  UART_CFG  RW   [0]=TX_EN, [1]=RX_DONE, [2]=TX_DONE
//
// TX davranisi (uart.sv'den birebir):
//   - TDR yazma + CFG[0]=1 + IDLE -> TX baslar
//   - 10-bit dizi: START + 8 DATA (LSB first) + STOP
//   - Her bit CPB cycle surer
//   - TX bittiginde CFG[2] (TX_DONE) set olur
//
// Iki instance kullanilabilir:
//   - UART-0: Genel kullanim (printf, debug)
//   - UART-1: YZ veri akisi (stream, sartname icin)
// ============================================================================

module uart_axi (
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
    output logic [1:0]  axi_rresp_o,

    // Serial output
    output logic        tx_o,
    // Serial input (Faz 3: RX)
    input  logic        rx_i
);

    // ------------------------------------------------------------------------
    // EK-2 yazmaclari
    // ------------------------------------------------------------------------
    logic [31:0] cpb_q;   // 0x00 Clock-per-bit
    logic [31:0] stp_q;   // 0x04 Stop bit
    logic [31:0] rdr_q;   // 0x08 Receive data (Faz 3)
    logic [31:0] tdr_q;   // 0x0C Transmit data
    logic [31:0] cfg_q;   // 0x10 Configuration [0]=TX_EN, [1]=RX_DONE, [2]=TX_DONE

    // ------------------------------------------------------------------------
    // Adres dekod (addr[4:2] = offset/4)
    // ------------------------------------------------------------------------
    logic [2:0] w_off;
    logic [2:0] r_off;
    assign w_off = axi_awaddr_i[4:2];
    assign r_off = axi_araddr_i[4:2];

    // ------------------------------------------------------------------------
    // TX state machine sinyalleri (forward declaration)
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {
        TX_IDLE  = 2'b00,
        TX_START = 2'b01,
        TX_DATA  = 2'b10,
        TX_STOP  = 2'b11
    } tx_state_e;

    tx_state_e   tx_state_q;
    logic [15:0] tx_baud_cnt_q;
    logic [3:0]  tx_bit_cnt_q;
    logic [7:0]  tx_shift_q;

    // RX state machine (Faz 3 - sartname §5.2 #1 UART RX gereksinimi)
    typedef enum logic [1:0] {
        RX_IDLE  = 2'b00,
        RX_START = 2'b01,
        RX_DATA  = 2'b10,
        RX_STOP  = 2'b11
    } rx_state_e;
    rx_state_e   rx_state_q;
    logic [15:0] rx_baud_cnt_q;
    logic [3:0]  rx_bit_cnt_q;
    logic [7:0]  rx_shift_q;
    // RX synchronizer (metastability koruma)
    logic        rx_sync1_q, rx_sync2_q;

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

    // Sabit cevap kodlari
    assign axi_bresp_o = 2'b00;  // OKAY
    assign axi_rresp_o = 2'b00;  // OKAY

    // Hazir sinyaller
    assign axi_awready_o = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_wready_o  = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_arready_o = (axi_state_q == S_IDLE) && axi_arvalid_i;
    assign axi_bvalid_o  = (axi_state_q == S_WRITE_RESP);
    assign axi_rvalid_o  = (axi_state_q == S_READ_RESP);
    assign axi_rdata_o   = read_data_q;

    // Yazma stroke (TDR icin tx_start_pulse hesaplamak icin)
    logic write_strobe;
    assign write_strobe = axi_state_q == S_IDLE && axi_awvalid_i && axi_wvalid_i;

    // TDR yazma + TX_EN + IDLE = baslat
    logic tx_start_pulse;
    assign tx_start_pulse = write_strobe && (w_off == 3'h3) &&
                            cfg_q[0] && (tx_state_q == TX_IDLE);

    // TX tamamlanma darbesi (TX_STOP son baud cevrimi). cfg_q[2] SADECE AXI
    // blogunda bu darbeyle set edilir -> tek surucu (Vivado MDRV-1 onlenir).
    logic tx_done_pulse;
    assign tx_done_pulse = (tx_state_q == TX_STOP) && (tx_baud_cnt_q == cpb_q[15:0] - 1);

    // ------------------------------------------------------------------------
    // AXI yazma + okuma (yazmac dosyasi)
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cpb_q       <= 32'd16;
            stp_q       <= 32'h0;
            rdr_q       <= 32'h0;
            tdr_q       <= 32'h0;
            cfg_q       <= 32'h00000001;  // TX_EN=1 default
            axi_state_q <= S_IDLE;
            read_data_q <= 32'h0;
        end else begin
            // AXI state machine
            case (axi_state_q)
                S_IDLE: begin
                    if (axi_awvalid_i && axi_wvalid_i) begin
                        // Yazma
                        case (w_off)
                            3'h0: cpb_q <= axi_wdata_i;
                            3'h1: stp_q <= axi_wdata_i;
                            3'h3: begin  // TDR
                                if (cfg_q[0] && (tx_state_q == TX_IDLE)) begin
                                    tdr_q <= axi_wdata_i;
                                end
                            end
                            3'h4: begin  // CFG
                                cfg_q[0] <= axi_wdata_i[0];
                                if (axi_wdata_i[1] == 1'b0) cfg_q[1] <= 1'b0;
                                if (axi_wdata_i[2] == 1'b0) cfg_q[2] <= 1'b0;
                            end
                            default: ; // RDR (0x08) read-only, sessizce yok say
                        endcase
                        axi_state_q <= S_WRITE_RESP;
                    end else if (axi_arvalid_i) begin
                        // Okuma
                        case (r_off)
                            3'h0: read_data_q <= cpb_q;
                            3'h1: read_data_q <= stp_q;
                            3'h2: read_data_q <= rdr_q;
                            3'h3: read_data_q <= tdr_q;
                            3'h4: read_data_q <= cfg_q;
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

            // RX completion hook (Faz 3 - sartname §5.2 #1 UART RX)
            // rx_done_pulse modul sonunda RX FSM tarafindan uretilir
            if (rx_done_pulse) begin
                rdr_q    <= {24'h0, rx_shift_q};
                cfg_q[1] <= 1'b1;  // RX_DONE flag
            end
            // TX_DONE (cfg_q[2]) burada set edilir (tek surucu blok)
            if (tx_done_pulse) begin
                cfg_q[2] <= 1'b1;  // TX_DONE
            end
        end
    end

    // ------------------------------------------------------------------------
    // TX state machine (gerc0ek baud rate generator)
    // uart.sv'den birebir kopya, sadece tx_start_pulse degisken kaynagi farkli
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
                        tx_shift_q  <= axi_wdata_i[7:0];
                        tx_state_q  <= TX_START;
                        // synthesis translate_off
                        $write("%c", axi_wdata_i[7:0]);
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
                        // cfg_q[2] (TX_DONE) AXI blogunda tx_done_pulse ile set edilir
                    end else begin
                        tx_baud_cnt_q <= tx_baud_cnt_q + 1;
                    end
                end

                default: tx_state_q <= TX_IDLE;
            endcase
        end
    end


    // ========================================================================
    // RX state machine (Faz 3 - sartname §5.2 #1 UART RX)
    // Bit ortasi sampling (CPB/2 + N*CPB)
    // ========================================================================

    // RX input synchronizer (2 cycle delay, metastability)
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_sync1_q <= 1'b1;
            rx_sync2_q <= 1'b1;
        end else begin
            rx_sync1_q <= rx_i;
            rx_sync2_q <= rx_sync1_q;
        end
    end

    // RX FSM
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_state_q    <= RX_IDLE;
            rx_baud_cnt_q <= 16'h0;
            rx_bit_cnt_q  <= 4'h0;
            rx_shift_q    <= 8'h0;
        end else begin
            case (rx_state_q)
                RX_IDLE: begin
                    rx_baud_cnt_q <= 16'h0;
                    rx_bit_cnt_q  <= 4'h0;
                    if (rx_sync2_q == 1'b0) begin
                        rx_state_q <= RX_START;
                    end
                end
                RX_START: begin
                    if (rx_baud_cnt_q == (cpb_q[15:0] >> 1) - 1) begin
                        if (rx_sync2_q == 1'b0) begin
                            rx_baud_cnt_q <= 16'h0;
                            rx_state_q    <= RX_DATA;
                        end else begin
                            rx_state_q <= RX_IDLE;
                        end
                    end else begin
                        rx_baud_cnt_q <= rx_baud_cnt_q + 1;
                    end
                end
                RX_DATA: begin
                    if (rx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        rx_baud_cnt_q <= 16'h0;
                        rx_shift_q <= {rx_sync2_q, rx_shift_q[7:1]};
                        if (rx_bit_cnt_q == 4'd7) begin
                            rx_bit_cnt_q <= 4'h0;
                            rx_state_q   <= RX_STOP;
                        end else begin
                            rx_bit_cnt_q <= rx_bit_cnt_q + 1;
                        end
                    end else begin
                        rx_baud_cnt_q <= rx_baud_cnt_q + 1;
                    end
                end
                RX_STOP: begin
                    if (rx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        rx_baud_cnt_q <= 16'h0;
                        rx_state_q    <= RX_IDLE;
                    end else begin
                        rx_baud_cnt_q <= rx_baud_cnt_q + 1;
                    end
                end
                default: rx_state_q <= RX_IDLE;
            endcase
        end
    end

    // RX completion: rdr_q ve cfg_q[1] update (rx_done_pulse)
    logic rx_done_pulse;
    assign rx_done_pulse = (rx_state_q == RX_STOP) &&
                           (rx_baud_cnt_q == cpb_q[15:0] - 1);

endmodule
