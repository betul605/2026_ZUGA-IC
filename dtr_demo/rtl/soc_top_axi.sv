// ============================================================================
// soc_top_axi.sv (Faz 7 - DTR Donemi M49)
// Tam AXI4-Lite SoC Top
// 
// Mimari:
//   CV32E40P core (OBI master)
//     - instr port -> ram_axi (IRAM, OBI->AXI bridge tek port)
//     - data port  -> obi_to_axi_lite Bridge -> AXI4-Lite Decoder
//                     -> 8 AXI4-Lite slave (Boot ROM, IRAM, DRAM, GPIO, Timer, UART-0, UART-1, I2C)
// 
// Memory map (OTR Tablo 1 birebir):
//   0x0000_0000 - 0x0000_01FF : Boot ROM (512 B, M29)
//   0x0001_0000 - 0x0001_1FFF : IRAM (8 KB, M18)
//   0x0002_0000 - 0x0002_1FFF : DRAM (8 KB, M18)
//   0x4000_0000 - 0x4000_0007 : GPIO (8 B, M19)
//   0x4000_1000 - 0x4000_101F : Timer (32 B, M20)
//   0x4000_2000 - 0x4000_2013 : UART-0 (20 B, M21)
//   0x4000_3000 - 0x4000_3013 : UART-1 (20 B, M31)
//   0x4000_4000 - 0x4000_4013 : I2C Master (20 B, M22)
// ============================================================================

module soc_top_axi (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [15:0] gpio_in_i,
    output logic [15:0] gpio_out_o,
    input  logic        uart0_rx_i,   // TEKNOTEST: UART-0 RX girisi (eklendi)
    output logic        uart0_tx_o,
    output logic        uart1_tx_o,
    output logic        i2c_scl_o,
    output logic        i2c_scl_oe,
    output logic        i2c_sda_o,
    output logic        i2c_sda_oe,
    input  logic        i2c_sda_i
);

    // ------------------------------------------------------------------------
    // CV32E40P OBI sinyalleri
    // ------------------------------------------------------------------------
    logic        instr_req, instr_gnt, instr_rvalid;
    logic [31:0] instr_addr, instr_rdata;

    logic        data_req, data_gnt, data_rvalid, data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr, data_wdata, data_rdata;

    // ------------------------------------------------------------------------
    // CV32E40P core
    // ------------------------------------------------------------------------
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
        .boot_addr_i        (32'h00000000),  // Boot ROM
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

    // ------------------------------------------------------------------------
    // Data port: OBI -> AXI4-Lite Bridge (M17)
    // ------------------------------------------------------------------------
    logic        m_awvalid, m_awready;
    logic [31:0] m_awaddr;
    logic [2:0]  m_awprot;
    logic        m_wvalid,  m_wready;
    logic [31:0] m_wdata;
    logic [3:0]  m_wstrb;
    logic        m_bvalid,  m_bready;
    logic [1:0]  m_bresp;
    logic        m_arvalid, m_arready;
    logic [31:0] m_araddr;
    logic [2:0]  m_arprot;
    logic        m_rvalid,  m_rready;
    logic [31:0] m_rdata;
    logic [1:0]  m_rresp;

    obi_to_axi_lite u_bridge (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        // OBI slave (data port)
        .obi_req_i   (data_req),
        .obi_gnt_o   (data_gnt),
        .obi_we_i    (data_we),
        .obi_be_i    (data_be),
        .obi_addr_i  (data_addr),
        .obi_wdata_i (data_wdata),
        .obi_rvalid_o(data_rvalid),
        .obi_rdata_o (data_rdata),
        // AXI4-Lite master
        .axi_awvalid_o (m_awvalid),
        .axi_awready_i (m_awready),
        .axi_awaddr_o  (m_awaddr),
        .axi_awprot_o  (m_awprot),
        .axi_wvalid_o  (m_wvalid),
        .axi_wready_i  (m_wready),
        .axi_wdata_o   (m_wdata),
        .axi_wstrb_o   (m_wstrb),
        .axi_bvalid_i  (m_bvalid),
        .axi_bready_o  (m_bready),
        .axi_bresp_i   (m_bresp),
        .axi_arvalid_o (m_arvalid),
        .axi_arready_i (m_arready),
        .axi_araddr_o  (m_araddr),
        .axi_arprot_o  (m_arprot),
        .axi_rvalid_i  (m_rvalid),
        .axi_rready_o  (m_rready),
        .axi_rdata_i   (m_rdata),
        .axi_rresp_i   (m_rresp)
    );

    // ------------------------------------------------------------------------
    // Instr port: Direct OBI -> Instr Memory (Boot ROM + IRAM birlesik BRAM)
    // Harvard mimarisi: instr fetch icin ayri bellek (sentez dostu, BRAM inferred)
    // 0x0000_0000 - 0x0000_01FF : Boot ROM (128 word, bootloader.hex)
    // 0x0001_0000 - 0x0001_1FFF : IRAM (2048 word, ana program)
    // 
    // Sartname §4.1: "Peripheral'ler AXI4-Lite" - instr memory peripheral degil
    // OTR Tablo 1: Boot ROM ve IRAM "instruction memory" olarak siniflandirilmis
    // ------------------------------------------------------------------------
    // Basit instr memory: BRAM olarak sentezlenir
    // Boot ROM (128 word) + IRAM (2048 word) = 8.5 KB, ~3 BRAM tile
    logic [31:0] instr_mem [0:2175];  // 128 + 2048 = 2176 word

    // TEKNOTEST_SIM tanimliyken bootloader.hex YUKLENMEZ; bunun yerine
    // teknotest_tb_user_code.sv icinden helloworld.mem instr_mem'e yuklenir.
`ifndef TEKNOTEST_SIM
    initial begin
        $readmemh("bootloader.hex", instr_mem, 0, 127);
        // IRAM 128'den itibaren bos baslar (program runtime'da yuklenir)
    end
`endif

    // Instr fetch: 1 cycle latency, daima grant
    assign instr_gnt = instr_req;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            instr_rvalid <= 1'b0;
            instr_rdata  <= 32'h0;
        end else begin
            instr_rvalid <= instr_req;
            if (instr_req) begin
                // Boot ROM: 0x0000_0000 - 0x0000_01FF (word index 0-127)
                if (instr_addr[31:9] == 23'h0) begin
                    instr_rdata <= instr_mem[instr_addr[8:2]];
                end
                // IRAM: 0x0001_0000 - 0x0001_1FFF (word index 128-2175)
                else if (instr_addr[31:13] == 19'h8) begin
                    instr_rdata <= instr_mem[128 + {3'b0, instr_addr[12:2]}];
                end
                else begin
                    instr_rdata <= 32'h00000013;  // NOP (addi x0,x0,0)
                end
            end
        end
    end

    // ========================================================================
    // AXI4-Lite Decoder + 7 Slave Instance
    // ========================================================================
    // Slave secimleri (data port AXI4-Lite uzerinden)
    //   0x0000_0000 - 0x0000_01FF : Boot ROM read (sadece data debug, optional)
    //   0x0002_0000 - 0x0002_1FFF : DRAM
    //   0x4000_0000 - 0x4000_0007 : GPIO
    //   0x4000_1000 - 0x4000_101F : Timer
    //   0x4000_2000 - 0x4000_2013 : UART-0
    //   0x4000_3000 - 0x4000_3013 : UART-1
    //   0x4000_4000 - 0x4000_4013 : I2C Master

    // Adres dekoder (data port master sinyallerinden)
    wire sel_dram   = (m_awaddr[31:24] == 8'h00 && m_awaddr[17] == 1'b1) ||
                      (m_araddr[31:24] == 8'h00 && m_araddr[17] == 1'b1);
    wire sel_gpio   = (m_awaddr[31:12] == 20'h40000) || (m_araddr[31:12] == 20'h40000);
    wire sel_timer  = (m_awaddr[31:12] == 20'h40001) || (m_araddr[31:12] == 20'h40001);
    wire sel_uart0  = (m_awaddr[31:12] == 20'h40002) || (m_araddr[31:12] == 20'h40002);
    wire sel_uart1  = (m_awaddr[31:12] == 20'h40003) || (m_araddr[31:12] == 20'h40003);
    wire sel_i2c    = (m_awaddr[31:12] == 20'h40004) || (m_araddr[31:12] == 20'h40004);

    // Her slave icin AXI4-Lite sinyalleri
    // DRAM
    logic        s_dram_awvalid, s_dram_awready, s_dram_wvalid, s_dram_wready, s_dram_bvalid, s_dram_bready;
    logic [1:0]  s_dram_bresp;
    logic        s_dram_arvalid, s_dram_arready, s_dram_rvalid, s_dram_rready;
    logic [31:0] s_dram_rdata;
    logic [1:0]  s_dram_rresp;

    // GPIO
    logic        s_gpio_awvalid, s_gpio_awready, s_gpio_wvalid, s_gpio_wready, s_gpio_bvalid, s_gpio_bready;
    logic [1:0]  s_gpio_bresp;
    logic        s_gpio_arvalid, s_gpio_arready, s_gpio_rvalid, s_gpio_rready;
    logic [31:0] s_gpio_rdata;
    logic [1:0]  s_gpio_rresp;

    // Timer
    logic        s_timer_awvalid, s_timer_awready, s_timer_wvalid, s_timer_wready, s_timer_bvalid, s_timer_bready;
    logic [1:0]  s_timer_bresp;
    logic        s_timer_arvalid, s_timer_arready, s_timer_rvalid, s_timer_rready;
    logic [31:0] s_timer_rdata;
    logic [1:0]  s_timer_rresp;

    // UART-0
    logic        s_u0_awvalid, s_u0_awready, s_u0_wvalid, s_u0_wready, s_u0_bvalid, s_u0_bready;
    logic [1:0]  s_u0_bresp;
    logic        s_u0_arvalid, s_u0_arready, s_u0_rvalid, s_u0_rready;
    logic [31:0] s_u0_rdata;
    logic [1:0]  s_u0_rresp;

    // UART-1
    logic        s_u1_awvalid, s_u1_awready, s_u1_wvalid, s_u1_wready, s_u1_bvalid, s_u1_bready;
    logic [1:0]  s_u1_bresp;
    logic        s_u1_arvalid, s_u1_arready, s_u1_rvalid, s_u1_rready;
    logic [31:0] s_u1_rdata;
    logic [1:0]  s_u1_rresp;

    // I2C
    logic        s_i2c_awvalid, s_i2c_awready, s_i2c_wvalid, s_i2c_wready, s_i2c_bvalid, s_i2c_bready;
    logic [1:0]  s_i2c_bresp;
    logic        s_i2c_arvalid, s_i2c_arready, s_i2c_rvalid, s_i2c_rready;
    logic [31:0] s_i2c_rdata;
    logic [1:0]  s_i2c_rresp;

    // AXI Master sinyallerini slave'lere dagit (AWVALID broadcast, sadece secilen slave AWREADY uretir)
    assign s_dram_awvalid  = m_awvalid & sel_dram;
    assign s_gpio_awvalid  = m_awvalid & sel_gpio;
    assign s_timer_awvalid = m_awvalid & sel_timer;
    assign s_u0_awvalid    = m_awvalid & sel_uart0;
    assign s_u1_awvalid    = m_awvalid & sel_uart1;
    assign s_i2c_awvalid   = m_awvalid & sel_i2c;

    assign s_dram_wvalid   = m_wvalid & sel_dram;
    assign s_gpio_wvalid   = m_wvalid & sel_gpio;
    assign s_timer_wvalid  = m_wvalid & sel_timer;
    assign s_u0_wvalid     = m_wvalid & sel_uart0;
    assign s_u1_wvalid     = m_wvalid & sel_uart1;
    assign s_i2c_wvalid    = m_wvalid & sel_i2c;

    assign s_dram_arvalid  = m_arvalid & sel_dram;
    assign s_gpio_arvalid  = m_arvalid & sel_gpio;
    assign s_timer_arvalid = m_arvalid & sel_timer;
    assign s_u0_arvalid    = m_arvalid & sel_uart0;
    assign s_u1_arvalid    = m_arvalid & sel_uart1;
    assign s_i2c_arvalid   = m_arvalid & sel_i2c;

    assign s_dram_bready   = m_bready & sel_dram;
    assign s_gpio_bready   = m_bready & sel_gpio;
    assign s_timer_bready  = m_bready & sel_timer;
    assign s_u0_bready     = m_bready & sel_uart0;
    assign s_u1_bready     = m_bready & sel_uart1;
    assign s_i2c_bready    = m_bready & sel_i2c;

    assign s_dram_rready   = m_rready & sel_dram;
    assign s_gpio_rready   = m_rready & sel_gpio;
    assign s_timer_rready  = m_rready & sel_timer;
    assign s_u0_rready     = m_rready & sel_uart0;
    assign s_u1_rready     = m_rready & sel_uart1;
    assign s_i2c_rready    = m_rready & sel_i2c;

    // Slave -> Master cevap mux
    assign m_awready = sel_dram  ? s_dram_awready  :
                       sel_gpio  ? s_gpio_awready  :
                       sel_timer ? s_timer_awready :
                       sel_uart0 ? s_u0_awready    :
                       sel_uart1 ? s_u1_awready    :
                       sel_i2c   ? s_i2c_awready   : 1'b0;

    assign m_wready  = sel_dram  ? s_dram_wready  :
                       sel_gpio  ? s_gpio_wready  :
                       sel_timer ? s_timer_wready :
                       sel_uart0 ? s_u0_wready    :
                       sel_uart1 ? s_u1_wready    :
                       sel_i2c   ? s_i2c_wready   : 1'b0;

    assign m_bvalid  = sel_dram  ? s_dram_bvalid  :
                       sel_gpio  ? s_gpio_bvalid  :
                       sel_timer ? s_timer_bvalid :
                       sel_uart0 ? s_u0_bvalid    :
                       sel_uart1 ? s_u1_bvalid    :
                       sel_i2c   ? s_i2c_bvalid   : 1'b0;

    assign m_bresp   = sel_dram  ? s_dram_bresp  :
                       sel_gpio  ? s_gpio_bresp  :
                       sel_timer ? s_timer_bresp :
                       sel_uart0 ? s_u0_bresp    :
                       sel_uart1 ? s_u1_bresp    :
                       sel_i2c   ? s_i2c_bresp   : 2'b00;

    assign m_arready = sel_dram  ? s_dram_arready  :
                       sel_gpio  ? s_gpio_arready  :
                       sel_timer ? s_timer_arready :
                       sel_uart0 ? s_u0_arready    :
                       sel_uart1 ? s_u1_arready    :
                       sel_i2c   ? s_i2c_arready   : 1'b0;

    assign m_rvalid  = sel_dram  ? s_dram_rvalid  :
                       sel_gpio  ? s_gpio_rvalid  :
                       sel_timer ? s_timer_rvalid :
                       sel_uart0 ? s_u0_rvalid    :
                       sel_uart1 ? s_u1_rvalid    :
                       sel_i2c   ? s_i2c_rvalid   : 1'b0;

    assign m_rdata   = sel_dram  ? s_dram_rdata  :
                       sel_gpio  ? s_gpio_rdata  :
                       sel_timer ? s_timer_rdata :
                       sel_uart0 ? s_u0_rdata    :
                       sel_uart1 ? s_u1_rdata    :
                       sel_i2c   ? s_i2c_rdata   : 32'h0;

    assign m_rresp   = sel_dram  ? s_dram_rresp  :
                       sel_gpio  ? s_gpio_rresp  :
                       sel_timer ? s_timer_rresp :
                       sel_uart0 ? s_u0_rresp    :
                       sel_uart1 ? s_u1_rresp    :
                       sel_i2c   ? s_i2c_rresp   : 2'b00;


    // ========================================================================
    // Slave Instances
    // ========================================================================

    // ----- DRAM (ram_axi, R/W, 8 KB) -----
    ram_axi #(
        .SIZE_WORDS   (2048),    // 8 KB
        .MEM_FILE     (""),      // Bos baslar
        .WRITE_ENABLE (1'b1)     // R/W
    ) u_dram (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .axi_awvalid_i (s_dram_awvalid),
        .axi_awready_o (s_dram_awready),
        .axi_awaddr_i  (m_awaddr),
        .axi_awprot_i  (m_awprot),
        .axi_wvalid_i  (s_dram_wvalid),
        .axi_wready_o  (s_dram_wready),
        .axi_wdata_i   (m_wdata),
        .axi_wstrb_i   (m_wstrb),
        .axi_bvalid_o  (s_dram_bvalid),
        .axi_bready_i  (s_dram_bready),
        .axi_bresp_o   (s_dram_bresp),
        .axi_arvalid_i (s_dram_arvalid),
        .axi_arready_o (s_dram_arready),
        .axi_araddr_i  (m_araddr),
        .axi_arprot_i  (m_arprot),
        .axi_rvalid_o  (s_dram_rvalid),
        .axi_rready_i  (s_dram_rready),
        .axi_rdata_o   (s_dram_rdata),
        .axi_rresp_o   (s_dram_rresp)
    );

    // ----- GPIO (M19, 32-bit, EK-2) -----
    gpio_axi u_gpio (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .axi_awvalid_i (s_gpio_awvalid),
        .axi_awready_o (s_gpio_awready),
        .axi_awaddr_i  (m_awaddr),
        .axi_awprot_i  (m_awprot),
        .axi_wvalid_i  (s_gpio_wvalid),
        .axi_wready_o  (s_gpio_wready),
        .axi_wdata_i   (m_wdata),
        .axi_wstrb_i   (m_wstrb),
        .axi_bvalid_o  (s_gpio_bvalid),
        .axi_bready_i  (s_gpio_bready),
        .axi_bresp_o   (s_gpio_bresp),
        .axi_arvalid_i (s_gpio_arvalid),
        .axi_arready_o (s_gpio_arready),
        .axi_araddr_i  (m_araddr),
        .axi_arprot_i  (m_arprot),
        .axi_rvalid_o  (s_gpio_rvalid),
        .axi_rready_i  (s_gpio_rready),
        .axi_rdata_o   (s_gpio_rdata),
        .axi_rresp_o   (s_gpio_rresp),
        .gpio_in_i     (gpio_in_i),
        .gpio_out_o    (gpio_out_o)
    );

    // ----- Timer (M20, 8 yazmac, EK-2) -----
    timer_axi u_timer (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .axi_awvalid_i (s_timer_awvalid),
        .axi_awready_o (s_timer_awready),
        .axi_awaddr_i  (m_awaddr),
        .axi_awprot_i  (m_awprot),
        .axi_wvalid_i  (s_timer_wvalid),
        .axi_wready_o  (s_timer_wready),
        .axi_wdata_i   (m_wdata),
        .axi_wstrb_i   (m_wstrb),
        .axi_bvalid_o  (s_timer_bvalid),
        .axi_bready_i  (s_timer_bready),
        .axi_bresp_o   (s_timer_bresp),
        .axi_arvalid_i (s_timer_arvalid),
        .axi_arready_o (s_timer_arready),
        .axi_araddr_i  (m_araddr),
        .axi_arprot_i  (m_arprot),
        .axi_rvalid_o  (s_timer_rvalid),
        .axi_rready_i  (s_timer_rready),
        .axi_rdata_o   (s_timer_rdata),
        .axi_rresp_o   (s_timer_rresp)
    );

    // ----- UART-0 (M21, 0x4000_2000) - TEKNOTEST uyumlu (uart_tek_axi) + RX -----
    uart_tek_axi u_uart0 (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .axi_awvalid_i (s_u0_awvalid),
        .axi_awready_o (s_u0_awready),
        .axi_awaddr_i  (m_awaddr),
        .axi_awprot_i  (m_awprot),
        .axi_wvalid_i  (s_u0_wvalid),
        .axi_wready_o  (s_u0_wready),
        .axi_wdata_i   (m_wdata),
        .axi_wstrb_i   (m_wstrb),
        .axi_bvalid_o  (s_u0_bvalid),
        .axi_bready_i  (s_u0_bready),
        .axi_bresp_o   (s_u0_bresp),
        .axi_arvalid_i (s_u0_arvalid),
        .axi_arready_o (s_u0_arready),
        .axi_araddr_i  (m_araddr),
        .axi_arprot_i  (m_arprot),
        .axi_rvalid_o  (s_u0_rvalid),
        .axi_rready_i  (s_u0_rready),
        .axi_rdata_o   (s_u0_rdata),
        .axi_rresp_o   (s_u0_rresp),
        .rx_i          (uart0_rx_i),
        .tx_o          (uart0_tx_o)
    );

    // ----- UART-1 (M31, 0x4000_3000, YZ stream) -----
    uart_axi u_uart1 (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .axi_awvalid_i (s_u1_awvalid),
        .axi_awready_o (s_u1_awready),
        .axi_awaddr_i  (m_awaddr),
        .axi_awprot_i  (m_awprot),
        .axi_wvalid_i  (s_u1_wvalid),
        .axi_wready_o  (s_u1_wready),
        .axi_wdata_i   (m_wdata),
        .axi_wstrb_i   (m_wstrb),
        .axi_bvalid_o  (s_u1_bvalid),
        .axi_bready_i  (s_u1_bready),
        .axi_bresp_o   (s_u1_bresp),
        .axi_arvalid_i (s_u1_arvalid),
        .axi_arready_o (s_u1_arready),
        .axi_araddr_i  (m_araddr),
        .axi_arprot_i  (m_arprot),
        .axi_rvalid_o  (s_u1_rvalid),
        .axi_rready_i  (s_u1_rready),
        .axi_rdata_o   (s_u1_rdata),
        .axi_rresp_o   (s_u1_rresp),
        .rx_i          (1'b1),
        .tx_o          (uart1_tx_o)
    );

    // ----- I2C Master (M22, 5 yazmac, 400 kHz) -----
    i2c_master_axi u_i2c (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .axi_awvalid_i (s_i2c_awvalid),
        .axi_awready_o (s_i2c_awready),
        .axi_awaddr_i  (m_awaddr),
        .axi_awprot_i  (m_awprot),
        .axi_wvalid_i  (s_i2c_wvalid),
        .axi_wready_o  (s_i2c_wready),
        .axi_wdata_i   (m_wdata),
        .axi_wstrb_i   (m_wstrb),
        .axi_bvalid_o  (s_i2c_bvalid),
        .axi_bready_i  (s_i2c_bready),
        .axi_bresp_o   (s_i2c_bresp),
        .axi_arvalid_i (s_i2c_arvalid),
        .axi_arready_o (s_i2c_arready),
        .axi_araddr_i  (m_araddr),
        .axi_arprot_i  (m_arprot),
        .axi_rvalid_o  (s_i2c_rvalid),
        .axi_rready_i  (s_i2c_rready),
        .axi_rdata_o   (s_i2c_rdata),
        .axi_rresp_o   (s_i2c_rresp),
        .scl_o         (i2c_scl_o),
        .scl_oe        (i2c_scl_oe),
        .sda_o         (i2c_sda_o),
        .sda_oe        (i2c_sda_oe),
        .sda_i         (i2c_sda_i)
    );

endmodule
