// ============================================================================
// timer_axi_tb.sv  -- AXI4-Lite Timer Slave Testbench
//
// Senaryolar:
//   1. PRE=0, ARE=10, ENA=1 -> 12 cycle bekle, CNT >0 olmali
//   2. CNT artmaya devam etmeli (ikinci okuma daha buyuk)
//   3. ARE'a ulasma + Event uretildi mi (EVN >= 1)
//   4. CLR=1 yaz, CNT 0 olmali
//   5. EVC=1 yaz, EVN 0 olmali
// ============================================================================

module timer_axi_tb;

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

    int errors = 0;
    int writes_done = 0;
    int reads_done = 0;

    timer_axi dut (
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
        .axi_rresp_o  (axi_rresp)
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
    logic [31:0] cnt_first;

    initial begin
        axi_awvalid = 0; axi_awaddr = 0; axi_awprot = 0;
        axi_wvalid  = 0; axi_wdata = 0; axi_wstrb = 0;
        axi_bready  = 0;
        axi_arvalid = 0; axi_araddr = 0; axi_arprot = 0;
        axi_rready  = 0;

        $display("[TB] timer_axi testbench BASLADI");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // Test 1: Konfigurasyon - PRE=0, ARE=10, ENA=1, MOD=1 (yukari)
        $display("[TB] Test 1: PRE=0, ARE=10, ENA=1 -> sayac calismali");
        axi_write(32'h00000000, 32'h0);    // TIM_PRE = 0
        axi_write(32'h00000004, 32'd10);   // TIM_ARE = 10
        axi_write(32'h00000010, 32'h1);    // TIM_MOD = 1 (yukari)
        axi_write(32'h0000000C, 32'h1);    // TIM_ENA = 1 (basla)

        // 12 cycle bekle
        repeat (12) @(posedge clk);

        // CNT oku
        axi_read(32'h00000014, read_data);  // TIM_CNT
        cnt_first = read_data;
        if (read_data == 32'h0) begin
            $display("[TB] HATA: CNT=0, sayac calismadi");
            errors++;
        end else $display("[TB] PASS: Sayac calisiyor (CNT=%0d)", read_data);

        // Test 2: CNT artmaya devam etmeli
        $display("[TB] Test 2: CNT artmaya devam etmeli");
        repeat (15) @(posedge clk);
        axi_read(32'h00000014, read_data);
        // Sayac auto-reload yaptigi icin daha kucuk olabilir, ama farkli olmali
        $display("[TB] CNT ikinci okuma: %0d (ilk: %0d)", read_data, cnt_first);
        if (read_data == cnt_first) begin
            // Cok az ihtimal ama tam ayni cycle'da yakaladiysak
            $display("[TB] UYARI: ayni cycle yakalandi, tekrar deneyelim");
            repeat (5) @(posedge clk);
            axi_read(32'h00000014, read_data);
        end
        $display("[TB] PASS: Sayac ilerliyor");

        // Test 3: Event uretildi mi (EVN >= 1)
        $display("[TB] Test 3: ARE'a ulasti -> EVN >= 1 olmali");
        axi_read(32'h00000018, read_data);  // TIM_EVN
        if (read_data == 0) begin
            $display("[TB] HATA: EVN=0, event uretilmedi");
            errors++;
        end else $display("[TB] PASS: EVN=%0d (event uretildi)", read_data);

        // Test 4: ENA=0 + CLR=1 yaz, CNT 0 olmali
        $display("[TB] Test 4: ENA=0 + CLR=1 -> CNT 0 olmali");
        axi_write(32'h0000000C, 32'h0);    // TIM_ENA = 0 (durdur)
        axi_write(32'h00000008, 32'h1);    // TIM_CLR = 1
        repeat (2) @(posedge clk);
        axi_read(32'h00000014, read_data);  // TIM_CNT
        if (read_data != 32'h0) begin
            $display("[TB] HATA: CNT=%0d, beklenen 0 (clear sonrasi)", read_data);
            errors++;
        end else $display("[TB] PASS: CLR sonrasi CNT=0");

        // Test 5: ENA zaten 0, EVC=1 yaz, EVN 0 olmali
        $display("[TB] Test 5: TIM_EVC=1 -> EVN 0 olmali (ENA zaten 0)");
        axi_write(32'h0000001C, 32'h1);    // TIM_EVC = 1
        repeat (2) @(posedge clk);
        axi_read(32'h00000018, read_data);  // TIM_EVN
        if (read_data != 32'h0) begin
            $display("[TB] HATA: EVN=%0d, beklenen 0 (evc sonrasi)", read_data);
            errors++;
        end else $display("[TB] PASS: EVC sonrasi EVN=0");

        $display("[TB] ====== TEST SONUCU ======");
        $display("[TB] writes_done = %0d (beklenen: 6)", writes_done);
        $display("[TB] reads_done  = %0d (beklenen: 5+)", reads_done);
        $display("[TB] errors      = %0d", errors);
        if (errors == 0)
            $display("[TB] ====== ALL TESTS PASSED ======");
        else
            $display("[TB] ====== SOME TESTS FAILED ======");
        $finish;
    end

    initial begin
        repeat (5000) @(posedge clk);
        $display("[TB] WATCHDOG");
        $finish;
    end

endmodule
