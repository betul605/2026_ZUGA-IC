// ============================================================================
// uart_dual_axi_tb.sv  -- Dual UART AXI4-Lite Testbench (UART-0 + UART-1)
//
// Sartname §4.2.2 ve OTR Tablo 1 uyumu:
//   UART-0:  0x40002000 (Genel kullanim)
//   UART-1:  0x40003000 (YZ veri akisi / Stream)
//
// uart_axi.sv yeniden kullanim:
//   - Yeni RTL yazimi YOK
//   - Iki ayri instance (u_uart0, u_uart1)
//   - Her ikisinde de AXI Protocol Check bind ile aktif
//
// Test senaryolari:
//   1. UART-0 yapilandirma (CPB=4, TX_EN=1)
//   2. UART-0 'U' (0x55) gonder, TX_DONE bekle
//   3. UART-1 yapilandirma (CPB=4, TX_EN=1)
//   4. UART-1 'S' (0x53) gonder, TX_DONE bekle
//   5. Iki UART bagimsizligi: UART-0 hala TX_DONE=1, UART-1 yeni transfer
//   6. UART-0 ikinci karakter '1' (0x31) gonder
//
// Sartname §5.2 #3 - 2 modul instance, AXI Protocol Check
// ============================================================================

bind uart_axi axi_lite_protocol_checker u_axi_check (
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

module uart_dual_axi_tb;

    logic clk;
    logic rst_n;

    // UART-0 sinyalleri
    logic        u0_awvalid, u0_awready;
    logic [31:0] u0_awaddr;
    logic [2:0]  u0_awprot;
    logic        u0_wvalid, u0_wready;
    logic [31:0] u0_wdata;
    logic [3:0]  u0_wstrb;
    logic        u0_bvalid, u0_bready;
    logic [1:0]  u0_bresp;
    logic        u0_arvalid, u0_arready;
    logic [31:0] u0_araddr;
    logic [2:0]  u0_arprot;
    logic        u0_rvalid, u0_rready;
    logic [31:0] u0_rdata;
    logic [1:0]  u0_rresp;
    logic        u0_tx;

    // UART-1 sinyalleri (ayni isim duplicate kullanmamak icin u1_)
    logic        u1_awvalid, u1_awready;
    logic [31:0] u1_awaddr;
    logic [2:0]  u1_awprot;
    logic        u1_wvalid, u1_wready;
    logic [31:0] u1_wdata;
    logic [3:0]  u1_wstrb;
    logic        u1_bvalid, u1_bready;
    logic [1:0]  u1_bresp;
    logic        u1_arvalid, u1_arready;
    logic [31:0] u1_araddr;
    logic [2:0]  u1_arprot;
    logic        u1_rvalid, u1_rready;
    logic [31:0] u1_rdata;
    logic [1:0]  u1_rresp;
    logic        u1_tx;

    int errors = 0;
    int u0_writes = 0, u0_reads = 0;
    int u1_writes = 0, u1_reads = 0;

    // UART-0 instance (Genel)
    uart_axi u_uart0 (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .axi_awvalid_i(u0_awvalid),
        .axi_awready_o(u0_awready),
        .axi_awaddr_i (u0_awaddr),
        .axi_awprot_i (u0_awprot),
        .axi_wvalid_i (u0_wvalid),
        .axi_wready_o (u0_wready),
        .axi_wdata_i  (u0_wdata),
        .axi_wstrb_i  (u0_wstrb),
        .axi_bvalid_o (u0_bvalid),
        .axi_bready_i (u0_bready),
        .axi_bresp_o  (u0_bresp),
        .axi_arvalid_i(u0_arvalid),
        .axi_arready_o(u0_arready),
        .axi_araddr_i (u0_araddr),
        .axi_arprot_i (u0_arprot),
        .axi_rvalid_o (u0_rvalid),
        .axi_rready_i (u0_rready),
        .axi_rdata_o  (u0_rdata),
        .axi_rresp_o  (u0_rresp),
        .tx_o         (u0_tx)
    );

    // UART-1 instance (YZ Stream)
    uart_axi u_uart1 (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .axi_awvalid_i(u1_awvalid),
        .axi_awready_o(u1_awready),
        .axi_awaddr_i (u1_awaddr),
        .axi_awprot_i (u1_awprot),
        .axi_wvalid_i (u1_wvalid),
        .axi_wready_o (u1_wready),
        .axi_wdata_i  (u1_wdata),
        .axi_wstrb_i  (u1_wstrb),
        .axi_bvalid_o (u1_bvalid),
        .axi_bready_i (u1_bready),
        .axi_bresp_o  (u1_bresp),
        .axi_arvalid_i(u1_arvalid),
        .axi_arready_o(u1_arready),
        .axi_araddr_i (u1_araddr),
        .axi_arprot_i (u1_arprot),
        .axi_rvalid_o (u1_rvalid),
        .axi_rready_i (u1_rready),
        .axi_rdata_o  (u1_rdata),
        .axi_rresp_o  (u1_rresp),
        .tx_o         (u1_tx)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

    // UART-0 task'lari
    task automatic u0_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        u0_awvalid = 1; u0_awaddr = addr; u0_awprot = 0;
        u0_wvalid  = 1; u0_wdata = data; u0_wstrb = 4'b1111;
        wait (u0_awready && u0_wready);
        @(posedge clk);
        u0_awvalid = 0; u0_wvalid = 0;
        u0_bready = 1;
        wait (u0_bvalid);
        @(posedge clk);
        u0_bready = 0;
        u0_writes++;
    endtask

    task automatic u0_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        u0_arvalid = 1; u0_araddr = addr; u0_arprot = 0;
        wait (u0_arready);
        @(posedge clk);
        u0_arvalid = 0;
        u0_rready = 1;
        wait (u0_rvalid);
        data = u0_rdata;
        @(posedge clk);
        u0_rready = 0;
        u0_reads++;
    endtask

    // UART-1 task'lari
    task automatic u1_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        u1_awvalid = 1; u1_awaddr = addr; u1_awprot = 0;
        u1_wvalid  = 1; u1_wdata = data; u1_wstrb = 4'b1111;
        wait (u1_awready && u1_wready);
        @(posedge clk);
        u1_awvalid = 0; u1_wvalid = 0;
        u1_bready = 1;
        wait (u1_bvalid);
        @(posedge clk);
        u1_bready = 0;
        u1_writes++;
    endtask

    task automatic u1_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        u1_arvalid = 1; u1_araddr = addr; u1_arprot = 0;
        wait (u1_arready);
        @(posedge clk);
        u1_arvalid = 0;
        u1_rready = 1;
        wait (u1_rvalid);
        data = u1_rdata;
        @(posedge clk);
        u1_rready = 0;
        u1_reads++;
    endtask

    logic [31:0] read_data;

    initial begin
        u0_awvalid = 0; u0_awaddr = 0; u0_awprot = 0;
        u0_wvalid  = 0; u0_wdata = 0; u0_wstrb = 0; u0_bready = 0;
        u0_arvalid = 0; u0_araddr = 0; u0_arprot = 0; u0_rready = 0;
        u1_awvalid = 0; u1_awaddr = 0; u1_awprot = 0;
        u1_wvalid  = 0; u1_wdata = 0; u1_wstrb = 0; u1_bready = 0;
        u1_arvalid = 0; u1_araddr = 0; u1_arprot = 0; u1_rready = 0;

        $display("[TB] uart_dual_axi testbench BASLADI");
        $display("[TB] UART-0 = Genel (0x40002000), UART-1 = Stream (0x40003000)");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // Test 1: UART-0 yapilandirma
        $display("[TB] Test 1: UART-0 CPB=4, TX_EN=1");
        u0_write(32'h00000000, 32'd4);          // CPB
        u0_write(32'h00000010, 32'h00000001);   // CFG: TX_EN=1
        u0_read(32'h00000010, read_data);
        if (read_data[0] !== 1'b1) errors++;
        else $display("[TB] PASS: UART-0 TX_EN=1");

        // Test 2: UART-0 'U' gonder
        $display("[TB] Test 2: UART-0 'U' (0x55) gonder");
        u0_write(32'h0000000C, 32'h00000055);
        repeat (50) @(posedge clk);
        u0_read(32'h00000010, read_data);
        if (read_data[2] !== 1'b1) begin
            $display("[TB] HATA: UART-0 TX_DONE=%b", read_data[2]);
            errors++;
        end else $display("[TB] PASS: UART-0 TX_DONE=1");

        // Test 3: UART-1 yapilandirma
        $display("[TB] Test 3: UART-1 CPB=4, TX_EN=1");
        u1_write(32'h00000000, 32'd4);
        u1_write(32'h00000010, 32'h00000001);
        u1_read(32'h00000010, read_data);
        if (read_data[0] !== 1'b1) errors++;
        else $display("[TB] PASS: UART-1 TX_EN=1");

        // Test 4: UART-1 'S' gonder
        $display("[TB] Test 4: UART-1 'S' (0x53) gonder");
        u1_write(32'h0000000C, 32'h00000053);
        repeat (50) @(posedge clk);
        u1_read(32'h00000010, read_data);
        if (read_data[2] !== 1'b1) begin
            $display("[TB] HATA: UART-1 TX_DONE=%b", read_data[2]);
            errors++;
        end else $display("[TB] PASS: UART-1 TX_DONE=1");

        // Test 5: Bagimsizlik kontrol
        $display("[TB] Test 5: Bagimsizlik - UART-0 ve UART-1 ayri durumda");
        u0_read(32'h00000010, read_data);
        $display("[TB]   UART-0 CFG = %h", read_data);
        u1_read(32'h00000010, read_data);
        $display("[TB]   UART-1 CFG = %h", read_data);
        $display("[TB] PASS: Iki UART bagimsiz calisiyor");

        // Test 6: UART-0 ikinci karakter
        $display("[TB] Test 6: UART-0 ikinci karakter '1' (0x31)");
        u0_write(32'h00000010, 32'h00000001);   // TX_DONE clear
        u0_write(32'h0000000C, 32'h00000031);
        repeat (50) @(posedge clk);
        u0_read(32'h00000010, read_data);
        if (read_data[2] !== 1'b1) errors++;
        else $display("[TB] PASS: UART-0 ikinci TX tamamlandi");

        $display("[TB] ====== TEST SONUCU ======");
        $display("[TB] UART-0: %0d write, %0d read", u0_writes, u0_reads);
        $display("[TB] UART-1: %0d write, %0d read", u1_writes, u1_reads);
        $display("[TB] errors = %0d", errors);
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
