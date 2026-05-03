// ============================================================================
// gpio_axi_tb.sv  -- AXI4-Lite GPIO Slave Testbench
//
// Senaryolar:
//   1. ODR'a 0xCAFE yaz, gpio_out kontrol
//   2. gpio_in = 0xBEEF ver, IDR oku, ust 16 bit 0 olmali
//   3. ODR'a 0xFFFF_FFFF yaz, sadece [15:0] etkili
//   4. Yanlis adres (0x08) okuma, 0 donmeli
// ============================================================================

// ============================================================================
// AXI4-Lite Protocol Check Bind (Faz 8)
// ============================================================================
bind gpio_axi axi_lite_protocol_checker u_axi_check (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .axi_awvalid_i(axi_awvalid_i),
    .axi_awready_o(axi_awready_o),
    .axi_wvalid_i (axi_wvalid_i),
    .axi_wready_o (axi_wready_o),
    .axi_bvalid_o (axi_bvalid_o),
    .axi_bready_i (axi_bready_i),
    .axi_bresp_o  (axi_bresp_o),
    .axi_arvalid_i(axi_arvalid_i),
    .axi_arready_o(axi_arready_o),
    .axi_rvalid_o (axi_rvalid_o),
    .axi_rready_i (axi_rready_i),
    .axi_rdata_o  (axi_rdata_o),
    .axi_rresp_o  (axi_rresp_o)
);

module gpio_axi_tb;

    logic clk;
    logic rst_n;

    // AXI4-Lite master sinyalleri
    logic        axi_awvalid;
    logic        axi_awready;
    logic [31:0] axi_awaddr;
    logic [2:0]  axi_awprot;
    logic        axi_wvalid;
    logic        axi_wready;
    logic [31:0] axi_wdata;
    logic [3:0]  axi_wstrb;
    logic        axi_bvalid;
    logic        axi_bready;
    logic [1:0]  axi_bresp;
    logic        axi_arvalid;
    logic        axi_arready;
    logic [31:0] axi_araddr;
    logic [2:0]  axi_arprot;
    logic        axi_rvalid;
    logic        axi_rready;
    logic [31:0] axi_rdata;
    logic [1:0]  axi_rresp;

    // GPIO pinleri
    logic [15:0] gpio_in;
    logic [15:0] gpio_out;

    int errors = 0;
    int writes_done = 0;
    int reads_done = 0;

    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------
    gpio_axi dut (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .axi_awvalid_i(axi_awvalid),
        .axi_awready_o(axi_awready),
        .axi_awaddr_i (axi_awaddr),
        .axi_awprot_i (axi_awprot),
        .axi_wvalid_i (axi_wvalid),
        .axi_wready_o (axi_wready),
        .axi_wdata_i  (axi_wdata),
        .axi_wstrb_i  (axi_wstrb),
        .axi_bvalid_o (axi_bvalid),
        .axi_bready_i (axi_bready),
        .axi_bresp_o  (axi_bresp),
        .axi_arvalid_i(axi_arvalid),
        .axi_arready_o(axi_arready),
        .axi_araddr_i (axi_araddr),
        .axi_arprot_i (axi_arprot),
        .axi_rvalid_o (axi_rvalid),
        .axi_rready_i (axi_rready),
        .axi_rdata_o  (axi_rdata),
        .axi_rresp_o  (axi_rresp),
        .gpio_in_i    (gpio_in),
        .gpio_out_o   (gpio_out)
    );

    // ------------------------------------------------------------------------
    // Clock & Reset
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

    // ------------------------------------------------------------------------
    // AXI Master Tasks
    // ------------------------------------------------------------------------
    task automatic axi_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        axi_awvalid = 1;
        axi_awaddr  = addr;
        axi_awprot  = 0;
        axi_wvalid  = 1;
        axi_wdata   = data;
        axi_wstrb   = 4'b1111;
        wait (axi_awready && axi_wready);
        @(posedge clk);
        axi_awvalid = 0;
        axi_wvalid  = 0;
        axi_bready = 1;
        wait (axi_bvalid);
        @(posedge clk);
        axi_bready = 0;
        writes_done++;
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        axi_arvalid = 1;
        axi_araddr  = addr;
        axi_arprot  = 0;
        wait (axi_arready);
        @(posedge clk);
        axi_arvalid = 0;
        axi_rready = 1;
        wait (axi_rvalid);
        data = axi_rdata;
        @(posedge clk);
        axi_rready = 0;
        reads_done++;
    endtask

    // ------------------------------------------------------------------------
    // Test
    // ------------------------------------------------------------------------
    logic [31:0] read_data;

    initial begin
        // Init
        axi_awvalid = 0; axi_awaddr = 0; axi_awprot = 0;
        axi_wvalid  = 0; axi_wdata = 0; axi_wstrb = 0;
        axi_bready  = 0;
        axi_arvalid = 0; axi_araddr = 0; axi_arprot = 0;
        axi_rready  = 0;
        gpio_in = 16'h0;

        $display("[TB] gpio_axi testbench BASLADI");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 1: ODR'a 0xCAFE yaz, gpio_out kontrol");
        axi_write(32'h00000004, 32'h0000_CAFE);  // ODR @ 0x04
        repeat (2) @(posedge clk);
        if (gpio_out !== 16'hCAFE) begin
            $display("[TB] HATA: gpio_out=%h, beklenen CAFE", gpio_out);
            errors++;
        end else $display("[TB] PASS: gpio_out = CAFE");

        // ----------------------------------------------------------
        $display("[TB] Test 2: gpio_in=BEEF, IDR oku");
        gpio_in = 16'hBEEF;
        repeat (2) @(posedge clk);
        axi_read(32'h00000000, read_data);  // IDR @ 0x00
        if (read_data !== 32'h0000_BEEF) begin
            $display("[TB] HATA: IDR=%h, beklenen 0000BEEF", read_data);
            errors++;
        end else $display("[TB] PASS: IDR = 0000BEEF (ust 16 bit 0)");

        // ----------------------------------------------------------
        $display("[TB] Test 3: ODR'a 0xFFFFFFFF yaz, sadece [15:0] etkili");
        axi_write(32'h00000004, 32'hFFFF_FFFF);
        repeat (2) @(posedge clk);
        if (gpio_out !== 16'hFFFF) begin
            $display("[TB] HATA: gpio_out=%h, beklenen FFFF", gpio_out);
            errors++;
        end else $display("[TB] PASS: gpio_out = FFFF (ust 16 bit yok sayildi)");

        // ODR oku, sadece [15:0]=FFFF olmali
        axi_read(32'h00000004, read_data);
        if (read_data !== 32'h0000_FFFF) begin
            $display("[TB] HATA: ODR oku=%h, beklenen 0000FFFF", read_data);
            errors++;
        end else $display("[TB] PASS: ODR okundu = 0000FFFF");

        // ----------------------------------------------------------
        $display("[TB] Test 4: Yanlis adres (0x08) okuma, 0 donmeli");
        axi_read(32'h00000008, read_data);
        if (read_data !== 32'h0) begin
            $display("[TB] HATA: yanlis adres okumasi=%h, beklenen 0", read_data);
            errors++;
        end else $display("[TB] PASS: Yanlis adres 0 donduruldu");

        // ----------------------------------------------------------
        $display("[TB] ====== TEST SONUCU ======");
        $display("[TB] writes_done = %0d (beklenen: 2)", writes_done);
        $display("[TB] reads_done  = %0d (beklenen: 3)", reads_done);
        $display("[TB] errors      = %0d", errors);
        if (writes_done == 2 && reads_done == 3 && errors == 0)
            $display("[TB] ====== ALL TESTS PASSED ======");
        else
            $display("[TB] ====== SOME TESTS FAILED ======");
        $finish;
    end

    initial begin
        repeat (3000) @(posedge clk);
        $display("[TB] WATCHDOG");
        $finish;
    end

endmodule
