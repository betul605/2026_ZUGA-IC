// ============================================================================
// i2c_master_axi.sv  -- AXI4-Lite Slave I2C Master (sartname EK-2 birebir)
//
// Yazmac haritasi (Sartname EK-2):
//   0x00  I2C_NBY  RW  Number of bytes (1-4, baska deger en yakina yuvarlanir)
//   0x04  I2C_ADR  RW  Slave address (7-bit, [6:0] kullanilir)
//   0x08  I2C_RDR  RO  Read data (1-4 byte LSB-first paketlenir)
//   0x0C  I2C_TDR  RW  Transmit data (1-4 byte LSB-first paketlenir)
//   0x10  I2C_CFG  RW  [0]=TX_EN, [1]=TX_DONE, [2]=RX_EN, [3]=RX_DONE
//
// SCL: Sabit 400 kHz (sartname EK-2 zorunlu, sistem saati 50 MHz varsayim)
//   PRER = 50_000_000 / (5 * 400_000) = 25 (ic prescaler)
//   Test icin parametre ile hizlandirilabilir
//
// Davranisi:
//   - TX_EN=1 yazinca: ADR'ye gore master START + ADDR + 1-4 byte + STOP
//   - Bittiginde TX_DONE=1 set olur
//   - RX_EN=1 yazinca: ADR'ye gore master START + ADDR(R) + 1-4 byte oku + STOP
//   - Bittiginde RX_DONE=1 set olur, RDR'a yazilir
//   - TX_EN ve RX_EN ayni anda 1 ise TX once
//
// Open-drain output: scl_oe=1 -> low, oe=0 -> high-Z
// ============================================================================

module i2c_master_axi #(
    parameter int unsigned PRESCALE = 25  // 50MHz / (5 * 400kHz) = 25
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

    // I2C pinleri (open-drain)
    output logic        scl_o,
    output logic        scl_oe,
    output logic        sda_o,
    output logic        sda_oe,
    input  logic        sda_i
);

    // ------------------------------------------------------------------------
    // EK-2 yazmaclari
    // ------------------------------------------------------------------------
    logic [2:0]  nby_q;       // 0x00 NBY (1-4, 3 bit yeterli)
    logic [6:0]  adr_q;       // 0x04 ADR (7-bit slave addr)
    logic [31:0] rdr_q;       // 0x08 RDR (1-4 byte LSB packed)
    logic [31:0] tdr_q;       // 0x0C TDR
    logic [3:0]  cfg_q;       // 0x10 CFG [0]=TX_EN, [1]=TX_DONE, [2]=RX_EN, [3]=RX_DONE

    // Adres dekod (addr[4:2])
    logic [2:0] w_off, r_off;
    assign w_off = axi_awaddr_i[4:2];
    assign r_off = axi_araddr_i[4:2];

    // ------------------------------------------------------------------------
    // I2C state machine sinyalleri (forward declaration)
    // ------------------------------------------------------------------------
    typedef enum logic [3:0] {
        I_IDLE     = 4'h0,
        I_START    = 4'h1,
        I_ADDR     = 4'h2,
        I_ACK_ADDR = 4'h3,
        I_TX_DATA  = 4'h4,
        I_ACK_TX   = 4'h5,
        I_RX_DATA  = 4'h6,
        I_ACK_RX   = 4'h7,
        I_STOP     = 4'h8,
        I_DONE     = 4'h9
    } i2c_state_e;

    i2c_state_e  i2c_state_q;
    logic [15:0] scl_cnt_q;     // SCL clock divider counter
    logic [3:0]  bit_cnt_q;     // 0..7 byte icindeki bit
    logic [2:0]  byte_cnt_q;    // 0..3 cur byte (NBY ile sinirli)
    logic        is_read_q;     // 1=RX, 0=TX (current transaction)
    logic [7:0]  shift_tx_q;    // TX shift register
    logic [7:0]  shift_rx_q;    // RX shift register
    logic [31:0] rx_buf_q;      // toplanan RX data
    logic        sda_drive_q;   // master'in SDA hattini surup surmedigini gosterir
    logic        sda_value_q;   // master'in SDA degeri (open-drain: sda_oe = !sda_value)
    logic        scl_value_q;   // master'in SCL degeri

    // ------------------------------------------------------------------------
    // Open-drain output (sda_o, scl_o sabit 0; oe sinyalleri kontrol ediyor)
    // ------------------------------------------------------------------------
    assign sda_o  = 1'b0;
    assign sda_oe = sda_drive_q && !sda_value_q;  // sda_value=0 -> oe=1 (low surer)
    assign scl_o  = 1'b0;
    assign scl_oe = !scl_value_q;                  // scl_value=0 -> oe=1

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

    assign axi_bresp_o = 2'b00;
    assign axi_rresp_o = 2'b00;
    assign axi_awready_o = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_wready_o  = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;
    assign axi_arready_o = (axi_state_q == S_IDLE) && axi_arvalid_i;
    assign axi_bvalid_o  = (axi_state_q == S_WRITE_RESP);
    assign axi_rvalid_o  = (axi_state_q == S_READ_RESP);
    assign axi_rdata_o   = read_data_q;

    logic write_strobe;
    assign write_strobe = (axi_state_q == S_IDLE) && axi_awvalid_i && axi_wvalid_i;

    // ------------------------------------------------------------------------
    // AXI yazma + okuma + register update
    // I2C tamamlanma darbesi: cfg_q[1]/cfg_q[3] SADECE bu blokta set edilir
    // (FSM I_DONE'a girince) -> tek surucu (Vivado MDRV-1 onlenir).
    // ------------------------------------------------------------------------
    logic i2c_done_pulse;
    assign i2c_done_pulse = (i2c_state_q == I_DONE);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            nby_q       <= 3'd1;     // default 1 byte
            adr_q       <= 7'h0;
            tdr_q       <= 32'h0;
            cfg_q       <= 4'h0;
            axi_state_q <= S_IDLE;
            read_data_q <= 32'h0;
        end else begin
            // CFG[1] (TX_DONE) ve CFG[3] (RX_DONE) I2C FSM tamamlaninca set edilir
            // Yazilim 0 yazarak temizleyebilir

            case (axi_state_q)
                S_IDLE: begin
                    if (axi_awvalid_i && axi_wvalid_i) begin
                        case (w_off)
                            3'h0: begin  // NBY (yuvarla)
                                if      (axi_wdata_i[31:0] >= 32'd4) nby_q <= 3'd4;
                                else if (axi_wdata_i[31:0] >= 32'd1) nby_q <= axi_wdata_i[2:0];
                                else                                  nby_q <= 3'd1;
                            end
                            3'h1: adr_q <= axi_wdata_i[6:0];
                            3'h3: tdr_q <= axi_wdata_i;
                            3'h4: begin  // CFG
                                cfg_q[0] <= axi_wdata_i[0];
                                if (axi_wdata_i[1] == 1'b0) cfg_q[1] <= 1'b0;
                                cfg_q[2] <= axi_wdata_i[2];
                                if (axi_wdata_i[3] == 1'b0) cfg_q[3] <= 1'b0;
                            end
                            default: ;
                        endcase
                        axi_state_q <= S_WRITE_RESP;
                    end else if (axi_arvalid_i) begin
                        case (r_off)
                            3'h0: read_data_q <= {29'h0, nby_q};
                            3'h1: read_data_q <= {25'h0, adr_q};
                            3'h2: read_data_q <= rdr_q;
                            3'h3: read_data_q <= tdr_q;
                            3'h4: read_data_q <= {28'h0, cfg_q};
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

            // I2C tamamlanma bayraklari (tek surucu: sadece bu blok)
            if (i2c_done_pulse) begin
                if (is_read_q) cfg_q[3] <= 1'b1;  // RX_DONE
                else           cfg_q[1] <= 1'b1;  // TX_DONE
            end
        end
    end

    // ------------------------------------------------------------------------
    // SCL clock divider (PRESCALE * 4 = bir SCL periyodu)
    // SCL fazlari: 0=falling, 1=low, 2=rising, 3=high
    // ------------------------------------------------------------------------
    logic [1:0] scl_phase_q;
    logic       phase_tick;
    assign phase_tick = (scl_cnt_q == 16'(PRESCALE - 1));

    // Trigger: TX_EN veya RX_EN 1'e set edildiginde I2C basla
    logic tx_trigger;
    logic rx_trigger;
    assign tx_trigger = write_strobe && (w_off == 3'h4) && axi_wdata_i[0] && (i2c_state_q == I_IDLE);
    assign rx_trigger = write_strobe && (w_off == 3'h4) && axi_wdata_i[2] && (i2c_state_q == I_IDLE) && !axi_wdata_i[0];

    // ------------------------------------------------------------------------
    // I2C state machine - master FSM
    //
    // I_IDLE: bekleme, trigger olunca START'a gec
    // I_START: SDA high->low (SCL high iken), START condition
    // I_ADDR: 7-bit adres + R/W bit gonder (8 clock)
    // I_ACK_ADDR: ACK al (1 clock, sda_drive=0 release)
    // I_TX_DATA: 8 bit veri gonder
    // I_ACK_TX: ACK al
    // I_RX_DATA: 8 bit veri al (sda_drive=0 release, sample)
    // I_ACK_RX: ACK gonder (master ACK/NACK)
    // I_STOP: SDA low->high (SCL high iken), STOP condition
    // I_DONE: cfg_q[1] (TX_DONE) veya cfg_q[3] (RX_DONE) set, IDLE'a don
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            i2c_state_q  <= I_IDLE;
            scl_cnt_q    <= 16'h0;
            scl_phase_q  <= 2'h0;
            bit_cnt_q    <= 4'h0;
            byte_cnt_q   <= 3'h0;
            is_read_q    <= 1'b0;
            shift_tx_q   <= 8'h0;
            shift_rx_q   <= 8'h0;
            rx_buf_q     <= 32'h0;
            sda_drive_q  <= 1'b0;
            sda_value_q  <= 1'b1;
            scl_value_q  <= 1'b1;
        end else begin
            // SCL/Phase counter
            if (phase_tick) begin
                scl_cnt_q   <= 16'h0;
                scl_phase_q <= scl_phase_q + 1;
            end else if (i2c_state_q != I_IDLE) begin
                scl_cnt_q <= scl_cnt_q + 1;
            end

            // SCL value (faz 0,1=low, 2,3=high)
            if (i2c_state_q != I_IDLE && i2c_state_q != I_START && i2c_state_q != I_DONE) begin
                scl_value_q <= scl_phase_q[1];  // 0,1=0, 2,3=1
            end else begin
                scl_value_q <= 1'b1;
            end

            // Ana state machine
            case (i2c_state_q)
                I_IDLE: begin
                    sda_drive_q <= 1'b0;
                    sda_value_q <= 1'b1;
                    scl_value_q <= 1'b1;
                    scl_cnt_q   <= 16'h0;
                    scl_phase_q <= 2'h0;
                    if (tx_trigger || rx_trigger) begin
                        is_read_q   <= rx_trigger;
                        shift_tx_q  <= rx_trigger ? {adr_q, 1'b1} : {adr_q, 1'b0};  // ADDR + R/W
                        bit_cnt_q   <= 4'h7;  // MSB first, 8 bit
                        byte_cnt_q  <= 3'h0;
                        i2c_state_q <= I_START;
                    end
                end

                I_START: begin
                    // SDA high->low while SCL high
                    sda_drive_q <= 1'b1;
                    sda_value_q <= 1'b0;
                    if (phase_tick && scl_phase_q == 2'h3) begin
                        i2c_state_q <= I_ADDR;
                    end
                end

                I_ADDR: begin
                    // SDA: shift_tx_q[bit_cnt] (MSB first)
                    sda_drive_q <= 1'b1;
                    sda_value_q <= shift_tx_q[bit_cnt_q[2:0]];
                    if (phase_tick && scl_phase_q == 2'h3) begin
                        if (bit_cnt_q == 4'h0) begin
                            i2c_state_q <= I_ACK_ADDR;
                        end else begin
                            bit_cnt_q <= bit_cnt_q - 1;
                        end
                    end
                end

                I_ACK_ADDR: begin
                    // SDA release (slave ACK), 1 SCL period bekle
                    sda_drive_q <= 1'b0;
                    if (phase_tick && scl_phase_q == 2'h3) begin
                        // ACK alindi (sda_i kontrol etmeyelim, ideal slave varsay)
                        bit_cnt_q  <= 4'h7;
                        if (is_read_q) begin
                            i2c_state_q <= I_RX_DATA;
                        end else begin
                            shift_tx_q  <= tdr_q[7:0];  // ilk byte
                            i2c_state_q <= I_TX_DATA;
                        end
                    end
                end

                I_TX_DATA: begin
                    sda_drive_q <= 1'b1;
                    sda_value_q <= shift_tx_q[bit_cnt_q[2:0]];
                    if (phase_tick && scl_phase_q == 2'h3) begin
                        if (bit_cnt_q == 4'h0) begin
                            i2c_state_q <= I_ACK_TX;
                        end else begin
                            bit_cnt_q <= bit_cnt_q - 1;
                        end
                    end
                end

                I_ACK_TX: begin
                    sda_drive_q <= 1'b0;
                    if (phase_tick && scl_phase_q == 2'h3) begin
                        if ({1'b0, byte_cnt_q} == ({1'b0, nby_q} - 4'h1)) begin
                            i2c_state_q <= I_STOP;
                        end else begin
                            byte_cnt_q <= byte_cnt_q + 1;
                            bit_cnt_q  <= 4'h7;
                            // Sonraki byte tdr'den
                            case (byte_cnt_q)
                                3'h0: shift_tx_q <= tdr_q[15:8];
                                3'h1: shift_tx_q <= tdr_q[23:16];
                                3'h2: shift_tx_q <= tdr_q[31:24];
                                default: shift_tx_q <= 8'h0;
                            endcase
                            i2c_state_q <= I_TX_DATA;
                        end
                    end
                end

                I_RX_DATA: begin
                    sda_drive_q <= 1'b0;
                    // Sample SDA on rising edge (faz 1->2 transition)
                    if (phase_tick && scl_phase_q == 2'h1) begin
                        shift_rx_q <= {shift_rx_q[6:0], sda_i};
                    end
                    if (phase_tick && scl_phase_q == 2'h3) begin
                        if (bit_cnt_q == 4'h0) begin
                            // RX byte tamamlandi, rx_buf_q'ye yaz
                            case (byte_cnt_q)
                                3'h0: rx_buf_q[7:0]   <= shift_rx_q;
                                3'h1: rx_buf_q[15:8]  <= shift_rx_q;
                                3'h2: rx_buf_q[23:16] <= shift_rx_q;
                                3'h3: rx_buf_q[31:24] <= shift_rx_q;
                                default: ;
                            endcase
                            i2c_state_q <= I_ACK_RX;
                        end else begin
                            bit_cnt_q <= bit_cnt_q - 1;
                        end
                    end
                end

                I_ACK_RX: begin
                    // Master ACK/NACK
                    sda_drive_q <= 1'b1;
                    sda_value_q <= ({1'b0, byte_cnt_q} == ({1'b0, nby_q} - 4'h1));  // son byte ise NACK (1)
                    if (phase_tick && scl_phase_q == 2'h3) begin
                        if ({1'b0, byte_cnt_q} == ({1'b0, nby_q} - 4'h1)) begin
                            i2c_state_q <= I_STOP;
                        end else begin
                            byte_cnt_q <= byte_cnt_q + 1;
                            bit_cnt_q  <= 4'h7;
                            i2c_state_q <= I_RX_DATA;
                        end
                    end
                end

                I_STOP: begin
                    // SDA low->high while SCL high
                    sda_drive_q <= 1'b1;
                    sda_value_q <= 1'b0;
                    scl_value_q <= 1'b1;
                    if (phase_tick && scl_phase_q == 2'h3) begin
                        sda_drive_q <= 1'b0;
                        i2c_state_q <= I_DONE;
                    end
                end

                I_DONE: begin
                    // rdr_q burada yazilir (tek surucu); cfg_q bayraklari AXI
                    // blogunda i2c_done_pulse ile set edilir (MDRV-1 onlenir)
                    if (is_read_q) begin
                        rdr_q <= rx_buf_q;
                    end
                    i2c_state_q <= I_IDLE;
                end

                default: i2c_state_q <= I_IDLE;
            endcase
        end
    end

endmodule
