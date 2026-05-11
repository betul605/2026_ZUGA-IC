// ============================================================================
// uart_rx_axi_tb.sv -- UART RX (Faz 3, sartname §5.2 #1) testbench
// Stil: uart_axi_tb.sv (M21) ile birebir uyumlu
// Test: TX -> RX loopback (tx_o serial -> rx_i)
// ============================================================================
module uart_rx_axi_tb;
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

    wire serial_line;  // LOOPBACK: tx_o <-> rx_i

    int pass = 0, fail = 0;

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
        .tx_o         (serial_line),
        .rx_i         (serial_line)   // LOOPBACK!
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
    endtask

    task automatic send_and_check(input [7:0] tx_byte);
        logic [31:0] cfg_val;
        logic [31:0] rdr_val;
        int timeout;

        $display("[TB] -------- '%c' (0x%02h) gonderiliyor --------", tx_byte, tx_byte);

        // TDR'ye yaz (TX baslat)
        axi_write(32'h0000_000C, {24'h0, tx_byte});

        // TX + RX bitsin diye bekle (10 bit * 8 cycle + buffer)
        repeat (200) @(posedge clk);

        // CFG oku - RX_DONE = bit 1 mi?
        axi_read(32'h0000_0010, cfg_val);
        timeout = 0;
        while ((cfg_val & 32'h2) == 0 && timeout < 20) begin
            repeat (50) @(posedge clk);
            axi_read(32'h0000_0010, cfg_val);
            timeout = timeout + 1;
        end

        if ((cfg_val & 32'h2) == 0) begin
            $display("[TB] FAIL: RX_DONE timeout (cfg=0x%h)", cfg_val);
            fail = fail + 1;
            return;
        end

        // RDR oku
        axi_read(32'h0000_0008, rdr_val);

        if (rdr_val[7:0] == tx_byte) begin
            $display("[TB] PASS: TX 0x%02h -> RX 0x%02h", tx_byte, rdr_val[7:0]);
            pass = pass + 1;
        end else begin
            $display("[TB] FAIL: TX 0x%02h -> RX 0x%02h (beklenen 0x%02h)",
                     tx_byte, rdr_val[7:0], tx_byte);
            fail = fail + 1;
        end

        // RX_DONE flag temizle (CFG yazma, bit1=0)
        axi_write(32'h0000_0010, 32'h00000001);
    endtask

    // Watchdog
    initial begin
        #5000000;  // 5ms
        $display("[TB] WATCHDOG TIMEOUT - simulasyon kilitli!");
        $display("[TB] tx_state=%0d rx_state=%0d cfg=0x%h", dut.tx_state_q, dut.rx_state_q, dut.cfg_q);
        $finish;
    end

    initial begin
        // Initial values
        axi_awvalid = 0; axi_awaddr = 0; axi_awprot = 0;
        axi_wvalid  = 0; axi_wdata = 0; axi_wstrb = 0;
        axi_bready  = 0;
        axi_arvalid = 0; axi_araddr = 0; axi_arprot = 0;
        axi_rready  = 0;

        $display("=== UART RX Loopback Test (M53) ===");

        // Reset bekle
        wait (rst_n);
        repeat (5) @(posedge clk);

        // CPB ayarla (kucuk = hizli)
        $display("[TB] CPB yaziliyor...");
        axi_write(32'h0000_0000, 32'd8);
        $display("[TB] CPB yazildi, cpb_q=%0d", dut.cpb_q);

        // CFG: TX_EN=1
        axi_write(32'h0000_0010, 32'h00000001);
        $display("[TB] CFG yazildi, cfg=0x%h", dut.cfg_q);

        // 5 test
        send_and_check(8'h41);  // 'A'
        send_and_check(8'h42);  // 'B'
        send_and_check(8'hFF);
        send_and_check(8'h00);
        send_and_check(8'h55);

        $display("");
        $display("=== UART RX Sonuc ===");
        $display("PASS: %0d / 5", pass);
        $display("FAIL: %0d / 5", fail);
        if (fail == 0) $display("====== ALL TESTS PASSED ======");

        $finish;
    end

endmodule
