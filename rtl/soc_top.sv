// ============================================================================
// soc_top.sv
// Sistem üst modülü:
//   CV32E40P çekirdeği + RAM + primitive UART
//   Basit adres decoder ile data bus dallanır.
// ============================================================================

module soc_top (
    input  logic        clk_i,
    input  logic        rst_ni,

    // GPIO harici pinleri (SoC disina)
    input  logic [15:0] gpio_in_i,
    output logic [15:0] gpio_out_o,

    // UART serial output (FPGA pin)
    output logic        uart_tx_o,

    // I2C Master pinleri (open-drain, FPGA pin'lerine baglanir)
    output logic        i2c_scl_o,
    output logic        i2c_scl_oe,
    output logic        i2c_sda_o,
    output logic        i2c_sda_oe
);

    // ----- Çekirdek OBI instruction port -----
    logic        instr_req;
    logic        instr_gnt;
    logic        instr_rvalid;
    logic [31:0] instr_addr;
    logic [31:0] instr_rdata;

    // ----- Çekirdek OBI data port -----
    logic        data_req;
    logic        data_gnt;
    logic        data_rvalid;
    logic        data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;

    // ----- CV32E40P çekirdeği -----
    cv32e40p_core #(
        .COREV_PULP       (0),
        .COREV_CLUSTER    (0),
        .FPU              (0),
        .FPU_ADDMUL_LAT   (0),
        .FPU_OTHERS_LAT   (0),
        .ZFINX            (0),
        .NUM_MHPMCOUNTERS (1)
    ) u_core (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .pulp_clock_en_i    (1'b1),
        .scan_cg_en_i       (1'b0),
        .boot_addr_i        (32'h00000000),
        .mtvec_addr_i       (32'h00000000),
        .dm_halt_addr_i     (32'h1A110800),
        .hart_id_i          (32'h0),
        .dm_exception_addr_i(32'h0),

        .instr_req_o        (instr_req),
        .instr_gnt_i        (instr_gnt),
        .instr_rvalid_i     (instr_rvalid),
        .instr_addr_o       (instr_addr),
        .instr_rdata_i      (instr_rdata),

        .data_req_o         (data_req),
        .data_gnt_i         (data_gnt),
        .data_rvalid_i      (data_rvalid),
        .data_we_o          (data_we),
        .data_be_o          (data_be),
        .data_addr_o        (data_addr),
        .data_wdata_o       (data_wdata),
        .data_rdata_i       (data_rdata),

        .apu_busy_o         (),
        .apu_req_o          (),
        .apu_gnt_i          (1'b0),
        .apu_operands_o     (),
        .apu_op_o           (),
        .apu_flags_o        (),
        .apu_rvalid_i       (1'b0),
        .apu_result_i       (32'h0),
        .apu_flags_i        (5'h0),

        .irq_i              (32'b0),
        .irq_ack_o          (),
        .irq_id_o           (),

        .debug_req_i        (1'b0),
        .debug_havereset_o  (),
        .debug_running_o    (),
        .debug_halted_o     (),

        .fetch_enable_i     (1'b1),
        .core_sleep_o       ()
    );

    // ========================================================================
    // Adres decoder: data bus dallanır
    //   addr[31:28] == 4'h1  → UART
    //   diğer                → RAM data port
    // ========================================================================
    // Adres dekoderi — 4 slave
    //   0x1xxxxxxx        -> UART
    //   0x40000xxx        -> GPIO
    //   0x40001xxx        -> Timer
    //   diger              -> RAM data port
    wire sel_uart_req  = (data_addr[31:28] == 4'h4) && (data_addr[14] == 1'b0) && (data_addr[13] == 1'b1) && (data_addr[12] == 1'b0);
    wire sel_gpio_req  = (data_addr[31:28] == 4'h4) && (data_addr[14] == 1'b0) && (data_addr[13] == 1'b0) && (data_addr[12] == 1'b0);
    wire sel_timer_req = (data_addr[31:28] == 4'h4) && (data_addr[14] == 1'b0) && (data_addr[13] == 1'b0) && (data_addr[12] == 1'b1);
    wire sel_i2c_req   = (data_addr[31:28] == 4'h4) && (data_addr[14] == 1'b1);
    wire sel_dram_req  = (data_addr[31:24] == 8'h00) && (data_addr[17] == 1'b1);
    wire sel_ram_req   = ~(sel_uart_req | sel_gpio_req | sel_timer_req | sel_dram_req | sel_i2c_req);

    // RAM data port sinyalleri
    logic        ram_b_req, ram_b_gnt, ram_b_rvalid;
    logic [31:0] ram_b_rdata;

    // UART sinyalleri
    logic        uart_req, uart_gnt, uart_rvalid;
    logic [31:0] uart_rdata;
    logic        i2c_req, i2c_gnt, i2c_rvalid;
    logic [31:0] i2c_rdata;

    // GPIO sinyalleri
    logic        gpio_req, gpio_gnt, gpio_rvalid;
    logic [31:0] gpio_rdata;

    // Timer sinyalleri
    logic        timer_req, timer_gnt, timer_rvalid;
    logic [31:0] timer_rdata;

    // DRAM sinyalleri
    logic        dram_req, dram_gnt, dram_rvalid;
    logic [31:0] dram_rdata;

    // Req'i uygun module yonlendir
    assign ram_b_req  = data_req & sel_ram_req;
    assign uart_req   = data_req & sel_uart_req;
    assign i2c_req    = data_req & sel_i2c_req;
    assign gpio_req   = data_req & sel_gpio_req;
    assign timer_req  = data_req & sel_timer_req;
    assign dram_req   = data_req & sel_dram_req;

    // Gnt hemen doner — request cycle'da
    assign data_gnt = sel_i2c_req   ? i2c_gnt   :
                      sel_uart_req  ? uart_gnt  :
                      sel_gpio_req  ? gpio_gnt  :
                      sel_timer_req ? timer_gnt :
                      sel_dram_req  ? dram_gnt  :
                                      ram_b_gnt;

    // rvalid ve rdata icin select'i latch'le (OBI timing)
    logic sel_uart_q, sel_gpio_q, sel_timer_q, sel_dram_q, sel_i2c_q;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            sel_uart_q  <= 1'b0;
            sel_i2c_q   <= 1'b0;
            sel_gpio_q  <= 1'b0;
            sel_timer_q <= 1'b0;
            sel_dram_q  <= 1'b0;
        end else if (data_req && data_gnt) begin
            sel_uart_q  <= sel_uart_req;
            sel_i2c_q   <= sel_i2c_req;
            sel_gpio_q  <= sel_gpio_req;
            sel_timer_q <= sel_timer_req;
            sel_dram_q  <= sel_dram_req;
        end
    end

    assign data_rvalid = sel_i2c_q   ? i2c_rvalid   :
                         sel_uart_q  ? uart_rvalid  :
                         sel_gpio_q  ? gpio_rvalid  :
                         sel_timer_q ? timer_rvalid :
                         sel_dram_q  ? dram_rvalid  :
                                       ram_b_rvalid;

    assign data_rdata  = sel_i2c_q   ? i2c_rdata   :
                         sel_uart_q  ? uart_rdata  :
                         sel_gpio_q  ? gpio_rdata  :
                         sel_timer_q ? timer_rdata :
                         sel_dram_q  ? dram_rdata  :
                                       ram_b_rdata;

    // ========================================================================
    // IRAM — 8 KB instruction RAM (mevcut, geriye uyumluluk icin data fallback)
    //   Port A: instruction (CV32E40P fetch)
    //   Port B: data (RAM adres araligi disinda kalan fallback erisim)
    // ========================================================================
    ram #(
        .SIZE_WORDS (2048),
        .MEM_FILE   ("hello.hex")
    ) u_iram (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),

        .a_req_i    (instr_req),
        .a_gnt_o    (instr_gnt),
        .a_rvalid_o (instr_rvalid),
        .a_addr_i   (instr_addr),
        .a_rdata_o  (instr_rdata),

        .b_req_i    (ram_b_req),
        .b_gnt_o    (ram_b_gnt),
        .b_rvalid_o (ram_b_rvalid),
        .b_we_i     (data_we),
        .b_be_i     (data_be),
        .b_addr_i   (data_addr),
        .b_wdata_i  (data_wdata),
        .b_rdata_o  (ram_b_rdata)
    );

    // ========================================================================
    // DRAM — 8 KB veri RAM (0x00020000-0x00021FFF)
    //   Sadece data port; instruction port tie-off.
    // ========================================================================
    ram #(
        .SIZE_WORDS (2048),
        .MEM_FILE   ("")
    ) u_dram (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),

        // Instruction port: kullanilmiyor, tie-off
        .a_req_i    (1'b0),
        .a_gnt_o    (),
        .a_rvalid_o (),
        .a_addr_i   ('0),
        .a_rdata_o  (),

        // Data port: DRAM erisimi
        .b_req_i    (dram_req),
        .b_gnt_o    (dram_gnt),
        .b_rvalid_o (dram_rvalid),
        .b_we_i     (data_we),
        .b_be_i     (data_be),
        .b_addr_i   (data_addr),
        .b_wdata_i  (data_wdata),
        .b_rdata_o  (dram_rdata)
    );

    // ========================================================================
    // UART — 0x40002000 bolgesi (EK-2 uyumlu, CPB/STP/RDR/TDR/CFG)
    // ========================================================================
    uart u_uart (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),

        .req_i      (uart_req),
        .gnt_o      (uart_gnt),
        .rvalid_o   (uart_rvalid),
        .we_i       (data_we),
        .be_i       (data_be),
        .addr_i     (data_addr),
        .wdata_i    (data_wdata),
        .rdata_o    (uart_rdata),
        .tx_o       (uart_tx_o)
    );

    // ========================================================================
    // I2C Master — 0x40004000 bolgesi (PRER/CTR/TXR/RXR/CMR/SR)
    // ========================================================================
    i2c_master u_i2c (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .req_i    (i2c_req),
        .gnt_o    (i2c_gnt),
        .rvalid_o (i2c_rvalid),
        .we_i     (data_we),
        .be_i     (data_be),
        .addr_i   (data_addr),
        .wdata_i  (data_wdata),
        .rdata_o  (i2c_rdata),
        .scl_o    (i2c_scl_o),
        .scl_oe   (i2c_scl_oe),
        .sda_o    (i2c_sda_o),
        .sda_oe   (i2c_sda_oe)
    );

    // ========================================================================
    // GPIO — 0x4xxxxxxx bolgesi
    // ========================================================================
    gpio u_gpio (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),

        .req_i      (gpio_req),
        .gnt_o      (gpio_gnt),
        .rvalid_o   (gpio_rvalid),
        .we_i       (data_we),
        .be_i       (data_be),
        .addr_i     (data_addr),
        .wdata_i    (data_wdata),
        .rdata_o    (gpio_rdata),

        .gpio_in_i  (gpio_in_i),
        .gpio_out_o (gpio_out_o)
    );

    // ========================================================================
    // Timer — 0x40001xxx bolgesi
    // ========================================================================
    timer u_timer (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),

        .req_i      (timer_req),
        .gnt_o      (timer_gnt),
        .rvalid_o   (timer_rvalid),
        .we_i       (data_we),
        .be_i       (data_be),
        .addr_i     (data_addr),
        .wdata_i    (data_wdata),
        .rdata_o    (timer_rdata)
    );

endmodule
