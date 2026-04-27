// ============================================================================
// i2c_master.sv  -- I2C Master Controller (Faz 1: davranissal iskelet)
//
// OpenCores I2C standartlarini referans alir, ama basitlestirilmistir.
// Sadece master mode, 100 kHz target hiz, 7-bit slave address.
//
// Yazmac haritasi (DTR'de aciklanacak, ONTR'de detay yoktu):
//   0x00 I2C_PRER  RW  Prescaler (clock divider)
//   0x04 I2C_CTR   RW  Control [0]=EN, [1]=IEN
//   0x08 I2C_TXR   RW  Transmit byte
//   0x0C I2C_RXR   RO  Receive byte
//   0x10 I2C_CMR   RW  Command [7]=STA, [6]=STO, [5]=RD, [4]=WR, [3]=ACK
//   0x14 I2C_SR    RO  Status [7]=RxACK, [6]=BUSY, [1]=TIP, [0]=IF
//
// Faz 1 davranisi: TXR'a yaz, CMR'a STA+WR set, master START + adres +
//   data + STOP urertir. Davranissal model (gerc0ek I2C timing'i Faz 2).
//
// Faz 2 (gelecek): tam state machine, ACK handling, RD operasyonu.
//
// Open-drain output: sda_oe=1 ise sda_o low cikari, oe=0 ise high-Z.
// ============================================================================

module i2c_master (
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

    // I2C pinleri (open-drain)
    output logic        scl_o,
    output logic        scl_oe,
    output logic        sda_o,
    output logic        sda_oe
);

    // ------------------------------------------------------------------------
    // EK yazmaclari (OpenCores tarzi)
    // ------------------------------------------------------------------------
    logic [31:0] prer_q;   // 0x00 Prescaler
    logic [31:0] ctr_q;    // 0x04 Control
    logic [31:0] txr_q;    // 0x08 Transmit byte
    logic [31:0] rxr_q;    // 0x0C Receive byte
    logic [31:0] cmr_q;    // 0x10 Command
    logic [31:0] sr_q;     // 0x14 Status

    // CTR yazmac biti yardimcilari
    wire en  = ctr_q[0];

    // CMR yazmac bit yardimcilari (one-shot)
    logic cmd_sta_pulse;   // START isteği
    logic cmd_sto_pulse;   // STOP isteği
    logic cmd_wr_pulse;    // WRITE isteği
    logic cmd_rd_pulse;    // READ isteği

    // Adres dekod (bit [4:2])
    wire is_prer = (addr_i[4:2] == 3'b000);
    wire is_ctr  = (addr_i[4:2] == 3'b001);
    wire is_txr  = (addr_i[4:2] == 3'b010);
    wire is_rxr  = (addr_i[4:2] == 3'b011);
    wire is_cmr  = (addr_i[4:2] == 3'b100);
    wire is_sr   = (addr_i[4:2] == 3'b101);

    assign gnt_o = req_i;

    // ------------------------------------------------------------------------
    // OBI yazma + okuma
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            prer_q   <= 32'd250;       // 100 kHz @ 50 MHz: 250 cycle/half
            ctr_q    <= 32'h00000001;  // EN=1 default
            txr_q    <= 32'h0;
            rxr_q    <= 32'h0;
            cmr_q    <= 32'h0;
            rvalid_o <= 1'b0;
            rdata_o  <= 32'h0;
        end else begin
            rvalid_o <= req_i && gnt_o;

            // CMR komut bitleri her cycle 0'a duser (one-shot)
            cmr_q    <= 32'h0;

            // YAZMA
            if (req_i && gnt_o && we_i) begin
                if      (is_prer) prer_q <= wdata_i;
                else if (is_ctr)  ctr_q  <= wdata_i;
                else if (is_txr)  txr_q  <= wdata_i;
                else if (is_cmr)  cmr_q  <= wdata_i;
                // RXR ve SR read-only
            end

            // OKUMA
            if (req_i && gnt_o && !we_i) begin
                if      (is_prer) rdata_o <= prer_q;
                else if (is_ctr)  rdata_o <= ctr_q;
                else if (is_txr)  rdata_o <= txr_q;
                else if (is_rxr)  rdata_o <= rxr_q;
                else if (is_cmr)  rdata_o <= cmr_q;
                else if (is_sr)   rdata_o <= sr_q;
                else              rdata_o <= 32'h0;
            end
        end
    end

    // CMR komut bit pulse'lari (1 cycle)
    assign cmd_sta_pulse = req_i && gnt_o && we_i && is_cmr && wdata_i[7];
    assign cmd_sto_pulse = req_i && gnt_o && we_i && is_cmr && wdata_i[6];
    assign cmd_rd_pulse  = req_i && gnt_o && we_i && is_cmr && wdata_i[5];
    assign cmd_wr_pulse  = req_i && gnt_o && we_i && is_cmr && wdata_i[4];

    // ------------------------------------------------------------------------
    // I2C State Machine (Faz 1: davranissal, ACK gormezden gelir)
    // ------------------------------------------------------------------------
    typedef enum logic [3:0] {
        I2C_IDLE   = 4'd0,
        I2C_START  = 4'd1,  // SDA: 1->0 while SCL=1
        I2C_BIT    = 4'd2,  // 9 bit cycle: 8 data + 1 ack
        I2C_STOP   = 4'd3,  // SDA: 0->1 while SCL=1
        I2C_DONE   = 4'd4   // TIP=0, IF=1
    } i2c_state_e;

    i2c_state_e  state_q;
    logic [15:0] clk_cnt_q;     // prescaler sayici
    logic [3:0]  bit_cnt_q;     // bit indeksi (0..8)
    logic [7:0]  shift_q;       // gonderilecek byte
    logic        scl_int_q;     // ic SCL sinyali
    logic        sda_int_q;     // ic SDA sinyali (output value)
    logic        sda_oe_q;      // SDA output enable

    // Half-bit timer: prescaler kadar cycle bekle
    wire half_tick = (clk_cnt_q >= prer_q[15:0] - 1);

    // Open-drain output mantik:
    // sda_oe=1 ise sda_o=0 (low), oe=0 ise sda_o=Z (high-Z, pull-up)
    // Faz 1'de sadece tek yon (master driving SDA), gerc0ek ack receive
    // Faz 2'de eklenecek.
    assign scl_o  = 1'b0;          // open-drain: hep low
    assign scl_oe = ~scl_int_q;    // SCL low yapmak icin oe=1
    assign sda_o  = 1'b0;          // open-drain: hep low
    assign sda_oe = sda_oe_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q   <= I2C_IDLE;
            clk_cnt_q <= 16'h0;
            bit_cnt_q <= 4'h0;
            shift_q   <= 8'h0;
            scl_int_q <= 1'b1;     // idle high
            sda_int_q <= 1'b1;
            sda_oe_q  <= 1'b0;     // idle: high-Z (slave pull-up)
            sr_q      <= 32'h0;
        end else begin
            case (state_q)
                I2C_IDLE: begin
                    scl_int_q <= 1'b1;
                    sda_oe_q  <= 1'b0;        // bus serbest
                    sr_q[6]   <= 1'b0;        // BUSY=0
                    sr_q[1]   <= 1'b0;        // TIP=0
                    if (en && cmd_sta_pulse) begin
                        shift_q   <= txr_q[7:0];
                        bit_cnt_q <= 4'h0;
                        clk_cnt_q <= 16'h0;
                        state_q   <= I2C_START;
                        sr_q[6]   <= 1'b1;    // BUSY=1
                        sr_q[1]   <= 1'b1;    // TIP=1
                    end
                end

                I2C_START: begin
                    // SDA 1->0 while SCL=1 (start condition)
                    sda_oe_q <= 1'b1;          // SDA cek (low)
                    if (half_tick) begin
                        clk_cnt_q <= 16'h0;
                        scl_int_q <= 1'b0;     // SCL low
                        state_q   <= I2C_BIT;
                    end else begin
                        clk_cnt_q <= clk_cnt_q + 1;
                    end
                end

                I2C_BIT: begin
                    // SCL low'da SDA degistir, SCL high'da bekle
                    if (half_tick) begin
                        clk_cnt_q <= 16'h0;
                        if (scl_int_q == 1'b0) begin
                            // SCL low -> SDA degistir, sonra SCL'i high yap
                            if (bit_cnt_q < 4'd8) begin
                                // Veri biti: shift_q[7] (MSB first)
                                sda_oe_q <= ~shift_q[7];
                                shift_q  <= {shift_q[6:0], 1'b0};
                            end else begin
                                // ACK biti: master serbest birakir, slave cekme
                                sda_oe_q <= 1'b0;     // high-Z
                            end
                            scl_int_q <= 1'b1;       // SCL high
                        end else begin
                            // SCL high'tan sonra low yap
                            scl_int_q <= 1'b0;
                            bit_cnt_q <= bit_cnt_q + 1;
                            if (bit_cnt_q == 4'd8) begin
                                // 9 bit (8 data + 1 ack) bitti
                                state_q <= I2C_STOP;
                            end
                        end
                    end else begin
                        clk_cnt_q <= clk_cnt_q + 1;
                    end
                end

                I2C_STOP: begin
                    // SDA 0->1 while SCL=1 (stop condition)
                    if (half_tick) begin
                        clk_cnt_q <= 16'h0;
                        if (scl_int_q == 1'b0) begin
                            sda_oe_q  <= 1'b1;        // SDA low
                            scl_int_q <= 1'b1;        // SCL high
                        end else begin
                            sda_oe_q  <= 1'b0;        // SDA serbest (high)
                            state_q   <= I2C_DONE;
                        end
                    end else begin
                        clk_cnt_q <= clk_cnt_q + 1;
                    end
                end

                I2C_DONE: begin
                    // 1 cycle pulse ve IDLE'a don
                    sr_q[0]   <= 1'b1;        // IF (interrupt flag) = 1
                    sr_q[1]   <= 1'b0;        // TIP=0
                    state_q   <= I2C_IDLE;
                end

                default: state_q <= I2C_IDLE;
            endcase
        end
    end

endmodule
