// ============================================================================
// uart_tek_axi.sv  -- AXI4-Lite UART (TEKNOFEST DTR demo testbench uyumlu)
//
// Bu modul, DDK'nin saglladigi teknotest ortamindaki helloworld.c'nin
// bekledigi EK-2 sozlesmesini BIREBIR uygular. uart_axi.sv'den TEK farki
// TX baslatma semantigidir:
//
//   uart_axi.sv (mevcut)  : TDR yazimi TX'i baslatir.
//   uart_tek_axi.sv (bu)  : CFG[0]'a 1 yazimi TX'i baslatir (helloworld.c boyle yapar:
//                           once TDR yazilir, sonra CFG |= 1 ile gonderim baslatilir).
//
// Yazmac haritasi (helloworld.c struct ile birebir, addr[4:2]):
//   0x00  CPB  RW   Clock-per-bit  (50 MHz / 115200 = 434)
//   0x04  STP  RW   Stop bit secimi (0 => 1 stop bit; bu tasarimda TX daima 1 stop)
//   0x08  RDR  RO   Receive data register
//   0x0C  TDR  RW   Transmit data register
//   0x10  CFG  RW   [0]=TX_START (strobe, write-1-to-start, daima 0 okunur)
//                   [1]=RX_DONE  (HW set, SW 0 yazarak temizler)
//                   [2]=TX_DONE  (HW set, SW 0 yazarak temizler)
//
// Test akisi (helloworld.c):
//   CPB=434; STP=0; CFG=0;
//   TDR='R'; CFG|=1; while(!(CFG&(1<<2))); CFG&=~(1<<2);   // 'R' gonder
//   while(!(CFG&(1<<1))); CFG&=~(1<<1);                     // 'A' bekle
//   if (RDR=='A') for(...) { TDR=msg[i]; CFG|=1; while(!(CFG&(1<<2))); CFG&=~(1<<2);}
// ============================================================================

module uart_tek_axi (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Write Address Channel
    input  logic        axi_awvalid_i,
    output logic        axi_awready_o,
    input  logic [31:0] axi_awaddr_i,
    input  logic [2:0]  axi_awprot_i,

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
    input  logic [31:0] axi_araddr_i,
    input  logic [2:0]  axi_arprot_i,

    // Read Data Channel
    output logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    output logic [31:0] axi_rdata_o,
    output logic [1:0]  axi_rresp_o,

    // Serial
    output logic        tx_o,
    input  logic        rx_i
);

    // ------------------------------------------------------------------------
    // EK-2 yazmaclari
    // ------------------------------------------------------------------------
    logic [31:0] cpb_q;   // 0x00 Clock-per-bit
    logic [31:0] stp_q;   // 0x04 Stop bit
    logic [31:0] rdr_q;   // 0x08 Receive data
    logic [31:0] tdr_q;   // 0x0C Transmit data
    logic [2:0]  cfg_q;   // 0x10 [0]=TX_START(strobe), [1]=RX_DONE, [2]=TX_DONE

    logic [2:0] w_off, r_off;
    assign w_off = axi_awaddr_i[4:2];
    assign r_off = axi_araddr_i[4:2];

    // ------------------------------------------------------------------------
    // TX FSM
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_e;
    tx_state_e   tx_state_q;
    logic [15:0] tx_baud_cnt_q;
    logic [3:0]  tx_bit_cnt_q;
    logic [7:0]  tx_shift_q;
    logic        tx_done_set;   // 1-cycle: TX tamamlandi

    // ------------------------------------------------------------------------
    // RX FSM (uart_axi.sv'den birebir; bit-ortasi sampling)
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_e;
    rx_state_e   rx_state_q;
    logic [15:0] rx_baud_cnt_q;
    logic [3:0]  rx_bit_cnt_q;
    logic [7:0]  rx_shift_q;
    logic        rx_sync1_q, rx_sync2_q;
    logic        rx_done_pulse;

    // ------------------------------------------------------------------------
    // AXI4-Lite FSM
    // ------------------------------------------------------------------------
    typedef enum logic [1:0] {S_IDLE, S_WRITE_RESP, S_READ_RESP} axi_state_e;
    axi_state_e  axi_state_q;
    logic [31:0] read_data_q;

    assign axi_bresp_o   = 2'b00;
    assign axi_rresp_o   = 2'b00;
    assign axi_awready_o = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_wready_o  = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_arready_o = (axi_state_q == S_IDLE) && axi_arvalid_i;
    assign axi_bvalid_o  = (axi_state_q == S_WRITE_RESP);
    assign axi_rvalid_o  = (axi_state_q == S_READ_RESP);
    assign axi_rdata_o   = read_data_q;

    logic write_strobe;
    assign write_strobe = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;

    // *** TEKNOFEST farki: CFG[0]'a 1 yazimi (idle iken) TX'i baslatir ***
    logic tx_start_pulse;
    assign tx_start_pulse = write_strobe && (w_off == 3'h4) &&
                            axi_wdata_i[0] && (tx_state_q == TX_IDLE);

    // ------------------------------------------------------------------------
    // Yazmac dosyasi + AXI FSM
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cpb_q       <= 32'd434;     // 50 MHz / 115200
            stp_q       <= 32'h0;
            rdr_q       <= 32'h0;
            tdr_q       <= 32'h0;
            cfg_q       <= 3'b000;
            axi_state_q <= S_IDLE;
            read_data_q <= 32'h0;
        end else begin
            // CFG[0] bir strobe'dur: daima 0 okunur (write-1-to-start)
            cfg_q[0] <= 1'b0;

            case (axi_state_q)
                S_IDLE: begin
                    if (axi_awvalid_i && axi_wvalid_i) begin
                        case (w_off)
                            3'h0: cpb_q <= axi_wdata_i;
                            3'h1: stp_q <= axi_wdata_i;
                            3'h3: if (tx_state_q == TX_IDLE) tdr_q <= axi_wdata_i; // TDR daima latch
                            3'h4: begin // CFG
                                // bit0 strobe (yukarida 0'lanir); bit1/bit2 SW-clear (0 yazinca)
                                if (axi_wdata_i[1] == 1'b0) cfg_q[1] <= 1'b0;
                                if (axi_wdata_i[2] == 1'b0) cfg_q[2] <= 1'b0;
                            end
                            default: ; // RDR read-only
                        endcase
                        axi_state_q <= S_WRITE_RESP;
                    end else if (axi_arvalid_i) begin
                        case (r_off)
                            3'h0: read_data_q <= cpb_q;
                            3'h1: read_data_q <= stp_q;
                            3'h2: read_data_q <= rdr_q;
                            3'h3: read_data_q <= tdr_q;
                            3'h4: read_data_q <= {29'h0, cfg_q};
                            default: read_data_q <= 32'h0;
                        endcase
                        axi_state_q <= S_READ_RESP;
                    end
                end
                S_WRITE_RESP: if (axi_bready_i) axi_state_q <= S_IDLE;
                S_READ_RESP:  if (axi_rready_i) axi_state_q <= S_IDLE;
                default:      axi_state_q <= S_IDLE;
            endcase

            // RX tamamlaninca RDR yukle + RX_DONE set (SW-clear'dan once gelse de set kazanir)
            if (rx_done_pulse) begin
                rdr_q    <= {24'h0, rx_shift_q};
                cfg_q[1] <= 1'b1;
            end
            // TX tamamlaninca TX_DONE set
            if (tx_done_set) begin
                cfg_q[2] <= 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // TX state machine (baud uretici) -- start: tx_start_pulse, veri: tdr_q
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tx_state_q    <= TX_IDLE;
            tx_baud_cnt_q <= 16'h0;
            tx_bit_cnt_q  <= 4'h0;
            tx_shift_q    <= 8'h0;
            tx_o          <= 1'b1;
            tx_done_set   <= 1'b0;
        end else begin
            tx_done_set <= 1'b0;
            case (tx_state_q)
                TX_IDLE: begin
                    tx_o          <= 1'b1;
                    tx_baud_cnt_q <= 16'h0;
                    tx_bit_cnt_q  <= 4'h0;
                    if (tx_start_pulse) begin
                        tx_shift_q <= tdr_q[7:0];
                        tx_state_q <= TX_START;
                        // synthesis translate_off
                        $write("%c", tdr_q[7:0]); $fflush();
                        // synthesis translate_on
                    end
                end
                TX_START: begin
                    tx_o <= 1'b0;
                    if (tx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        tx_baud_cnt_q <= 16'h0;
                        tx_state_q    <= TX_DATA;
                    end else tx_baud_cnt_q <= tx_baud_cnt_q + 1;
                end
                TX_DATA: begin
                    tx_o <= tx_shift_q[0];
                    if (tx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        tx_baud_cnt_q <= 16'h0;
                        tx_shift_q    <= {1'b0, tx_shift_q[7:1]};
                        if (tx_bit_cnt_q == 4'd7) begin
                            tx_bit_cnt_q <= 4'h0;
                            tx_state_q   <= TX_STOP;
                        end else tx_bit_cnt_q <= tx_bit_cnt_q + 1;
                    end else tx_baud_cnt_q <= tx_baud_cnt_q + 1;
                end
                TX_STOP: begin
                    tx_o <= 1'b1;
                    if (tx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        tx_baud_cnt_q <= 16'h0;
                        tx_state_q    <= TX_IDLE;
                        tx_done_set   <= 1'b1;   // TX_DONE
                    end else tx_baud_cnt_q <= tx_baud_cnt_q + 1;
                end
                default: tx_state_q <= TX_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // RX synchronizer + FSM (uart_axi.sv ile ayni)
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_sync1_q <= 1'b1;
            rx_sync2_q <= 1'b1;
        end else begin
            rx_sync1_q <= rx_i;
            rx_sync2_q <= rx_sync1_q;
        end
    end

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
                    if (rx_sync2_q == 1'b0) rx_state_q <= RX_START;
                end
                RX_START: begin
                    if (rx_baud_cnt_q == (cpb_q[15:0] >> 1) - 1) begin
                        if (rx_sync2_q == 1'b0) begin
                            rx_baud_cnt_q <= 16'h0;
                            rx_state_q    <= RX_DATA;
                        end else rx_state_q <= RX_IDLE; // sahte start
                    end else rx_baud_cnt_q <= rx_baud_cnt_q + 1;
                end
                RX_DATA: begin
                    if (rx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        rx_baud_cnt_q <= 16'h0;
                        rx_shift_q <= {rx_sync2_q, rx_shift_q[7:1]};
                        if (rx_bit_cnt_q == 4'd7) begin
                            rx_bit_cnt_q <= 4'h0;
                            rx_state_q   <= RX_STOP;
                        end else rx_bit_cnt_q <= rx_bit_cnt_q + 1;
                    end else rx_baud_cnt_q <= rx_baud_cnt_q + 1;
                end
                RX_STOP: begin
                    if (rx_baud_cnt_q == cpb_q[15:0] - 1) begin
                        rx_baud_cnt_q <= 16'h0;
                        rx_state_q    <= RX_IDLE;
                    end else rx_baud_cnt_q <= rx_baud_cnt_q + 1;
                end
                default: rx_state_q <= RX_IDLE;
            endcase
        end
    end

    assign rx_done_pulse = (rx_state_q == RX_STOP) &&
                           (rx_baud_cnt_q == cpb_q[15:0] - 1);

endmodule
