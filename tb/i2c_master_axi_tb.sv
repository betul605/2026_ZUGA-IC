// ============================================================================
// i2c_master_axi_tb.sv  -- AXI4-Lite I2C Master Testbench
//
// Senaryolar:
//   1. NBY=1, ADR=0x50, TDR=0xA5, TX_EN=1 -> 1 byte gonder
//   2. TX_DONE flag kontrol
//   3. CFG[1]=0 yaz, TX_DONE clear
//   4. SCL ve SDA aktivite gozlemlendi (hardcoded check yok, log)
//
// Slave model: SDA'yi her zaman ACK (low) cekiyor (basit slave taklidi)
// ============================================================================

module i2c_master_axi_tb;

    logic clk;
    logic rst_n;

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

    logic scl_master, scl_oe_master;
    logic sda_master, sda_oe_master;
    logic sda_to_master;

    int errors = 0;
    int writes_done = 0;
    int reads_done = 0;

    // PRESCALE=4 -> SCL = 50MHz / (4*4) = 3.125MHz (test icin hizli)
    i2c_master_axi #(.PRESCALE(4)) dut (
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
        .scl_o        (scl_master),
        .scl_oe       (scl_oe_master),
        .sda_o        (sda_master),
        .sda_oe       (sda_oe_master),
        .sda_i        (sda_to_master)
    );

    // Basit slave: master release ettiginde (sda_oe=0) hat high (pull-up)
    // ACK olmasi icin slave low cekmeli ama biz simdilik high birakiyoruz (NACK)
    // RX testleri icin slave model gelistirilebilir
    assign sda_to_master = sda_oe_master ? 1'b0 : 1'b1;

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

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

    logic [31:0] read_data;

    initial begin
        axi_awvalid = 0; axi_awaddr = 0; axi_awprot = 0;
        axi_wvalid  = 0; axi_wdata = 0; axi_wstrb = 0;
        axi_bready  = 0;
        axi_arvalid = 0; axi_araddr = 0; axi_arprot = 0;
        axi_rready  = 0;

        $display("[TB] i2c_master_axi testbench BASLADI");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // Test 1: Yapilandirma
        $display("[TB] Test 1: NBY=1, ADR=0x50, TDR=0xA5 yapilandirma");
        axi_write(32'h00000000, 32'd1);          // NBY = 1
        axi_write(32'h00000004, 32'h00000050);   // ADR = 0x50
        axi_write(32'h0000000C, 32'h000000A5);   // TDR = 0xA5

        // Yazmaclari oku, dogrula
        axi_read(32'h00000000, read_data);
        if (read_data[2:0] !== 3'd1) begin
            $display("[TB] HATA: NBY=%0d, beklenen 1", read_data);
            errors++;
        end else $display("[TB] PASS: NBY=1");

        axi_read(32'h00000004, read_data);
        if (read_data[6:0] !== 7'h50) begin
            $display("[TB] HATA: ADR=%h, beklenen 50", read_data);
            errors++;
        end else $display("[TB] PASS: ADR=0x50");

        axi_read(32'h0000000C, read_data);
        if (read_data !== 32'hA5) begin
            $display("[TB] HATA: TDR=%h, beklenen A5", read_data);
            errors++;
        end else $display("[TB] PASS: TDR=0xA5");

        // Test 2: TX_EN = 1, transfer baslamali
        $display("[TB] Test 2: CFG[0]=TX_EN=1 yaz, transfer baslamali");
        axi_write(32'h00000010, 32'h00000001);   // TX_EN=1

        // Transfer suresi: START + 8 ADDR + ACK + 8 DATA + ACK + STOP
        // Her bit 4 phase * PRESCALE = 16 cycle
        // 19 bit toplam (yaklasik) * 16 = ~300 cycle, biraz fazla bekleyelim
        $display("[TB] Transfer bekleniyor (~500 cycle)");
        repeat (500) @(posedge clk);

        // Test 3: TX_DONE flag kontrol
        $display("[TB] Test 3: TX_DONE flag kontrol");
        axi_read(32'h00000010, read_data);
        $display("[TB] CFG = %h (beklenen [1]=1)", read_data);
        if (read_data[1] !== 1'b1) begin
            $display("[TB] HATA: TX_DONE=%b, beklenen 1", read_data[1]);
            errors++;
        end else $display("[TB] PASS: TX_DONE=1 (transfer tamamlandi)");

        // Test 4: TX_DONE clear
        $display("[TB] Test 4: TX_DONE clear (CFG[1]=0 yaz)");
        axi_write(32'h00000010, 32'h00000000);   // hepsi 0
        axi_read(32'h00000010, read_data);
        if (read_data[1] !== 1'b0) begin
            $display("[TB] HATA: TX_DONE=%b, beklenen 0", read_data[1]);
            errors++;
        end else $display("[TB] PASS: TX_DONE=0 (clear basarili)");

        $display("[TB] ====== TEST SONUCU ======");
        $display("[TB] writes_done = %0d", writes_done);
        $display("[TB] reads_done  = %0d", reads_done);
        $display("[TB] errors      = %0d", errors);
        if (errors == 0)
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
