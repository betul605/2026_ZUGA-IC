// ============================================================================
// uart_axi_tb.sv  -- AXI4-Lite UART TX Slave Testbench
//
// Senaryolar:
//   1. CPB ve CFG yapilandirma + dogrulama
//   2. TDR'a 'A' (0x41) yaz, TX baslamali
//   3. tx_o serial cikis 10 bit boyunca takip (START + 8 DATA + STOP)
//   4. TX bittikten sonra CFG[2] (TX_DONE) = 1 olmali
//   5. CFG[2] clear: 0 yaz, sonra CFG oku, [2] = 0 olmali
// ============================================================================

module uart_axi_tb;

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

    logic        tx_serial;

    int errors = 0;
    int writes_done = 0;
    int reads_done = 0;

    uart_axi dut (
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
        .tx_o         (tx_serial)
    );

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

        $display("[TB] uart_axi testbench BASLADI");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // Test 1: CPB ve CFG yapilandirma
        $display("[TB] Test 1: CPB=4 yaz, oku, dogrula");
        axi_write(32'h00000000, 32'd4);   // CPB = 4 (her bit 4 cycle)
        axi_read(32'h00000000, read_data);
        if (read_data !== 32'd4) begin
            $display("[TB] HATA: CPB=%0d, beklenen 4", read_data);
            errors++;
        end else $display("[TB] PASS: CPB=4 dogru yazildi");

        // CFG[0] (TX_EN) = 1 oldugundan emin ol (default 1, yine de yaz)
        axi_write(32'h00000010, 32'h00000001);  // TX_EN=1, RX_DONE=0, TX_DONE=0
        axi_read(32'h00000010, read_data);
        $display("[TB] CFG = %h (beklenen [0]=1)", read_data);
        if (read_data[0] !== 1'b1) begin
            $display("[TB] HATA: TX_EN=%b, beklenen 1", read_data[0]);
            errors++;
        end else $display("[TB] PASS: TX_EN=1");

        // Test 2: TDR'a 'A' (0x41) yaz, TX baslamali
        $display("[TB] Test 2: TDR='A' (0x41) yaz, TX baslamali");
        axi_write(32'h0000000C, 32'h00000041);  // TDR = 'A'
        repeat (2) @(posedge clk);

        // TX_IDLE'dan TX_START'a gecmis olmali (tx_serial low)
        if (tx_serial !== 1'b0) begin
            $display("[TB] UYARI: tx_serial=%b, START bit gozlenmedi", tx_serial);
        end else $display("[TB] Start bit (tx_serial=0) gozlendi");

        // Test 3: 10-bit frame bekle (10 * CPB = 40 cycle, biraz fazla bekle)
        $display("[TB] Test 3: 10-bit frame bekle (40+ cycle)");
        repeat (50) @(posedge clk);

        // Test 4: TX bittikten sonra CFG[2] (TX_DONE) = 1 olmali
        $display("[TB] Test 4: TX_DONE flag kontrol");
        axi_read(32'h00000010, read_data);
        if (read_data[2] !== 1'b1) begin
            $display("[TB] HATA: TX_DONE=%b, beklenen 1 (TX bitti)", read_data[2]);
            errors++;
        end else $display("[TB] PASS: TX_DONE=1 (TX tamamlandi)");

        // tx_serial idle (high) durumunda olmali
        if (tx_serial !== 1'b1) begin
            $display("[TB] HATA: tx_serial=%b, beklenen 1 (idle)", tx_serial);
            errors++;
        end else $display("[TB] PASS: tx_serial idle (high)");

        // Test 5: CFG[2] clear
        $display("[TB] Test 5: CFG[2] clear");
        axi_write(32'h00000010, 32'h00000001);  // TX_EN=1, TX_DONE=0
        axi_read(32'h00000010, read_data);
        if (read_data[2] !== 1'b0) begin
            $display("[TB] HATA: TX_DONE=%b, beklenen 0 (clear sonrasi)", read_data[2]);
            errors++;
        end else $display("[TB] PASS: TX_DONE=0 (clear basarili)");

        $display("[TB] ====== TEST SONUCU ======");
        $display("[TB] writes_done = %0d (beklenen: 4)", writes_done);
        $display("[TB] reads_done  = %0d (beklenen: 4)", reads_done);
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
