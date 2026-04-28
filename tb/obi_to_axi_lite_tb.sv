// ============================================================================
// obi_to_axi_lite_tb.sv  -- OBI -> AXI4-Lite Bridge Testbench
//
// Bridge'i izole test eder:
//   - OBI master rolu: req/addr/we/wdata gonder
//   - AXI4-Lite slave rolu: awready/wready/bvalid/arready/rvalid uret
//   - Bridge ortada
//
// Senaryolar:
//   1. Write transaction (1 islem)
//   2. Read transaction (1 islem)
//   3. Back-to-back: 5 write + 5 read
//   4. Coverage: state gecisleri gorulmesi
// ============================================================================

module obi_to_axi_lite_tb;

    logic clk;
    logic rst_n;

    // OBI tarafi (testbench OBI master)
    logic        obi_req;
    logic        obi_gnt;
    logic        obi_rvalid;
    logic        obi_we;
    logic [3:0]  obi_be;
    logic [31:0] obi_addr;
    logic [31:0] obi_wdata;
    logic [31:0] obi_rdata;

    // AXI4-Lite tarafi (testbench AXI4-Lite slave)
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

    // Coverage sayaclari
    int writes_done = 0;
    int reads_done = 0;
    int errors = 0;

    // ------------------------------------------------------------------------
    // DUT: Bridge instance
    // ------------------------------------------------------------------------
    obi_to_axi_lite #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) dut (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .obi_req_i    (obi_req),
        .obi_gnt_o    (obi_gnt),
        .obi_rvalid_o (obi_rvalid),
        .obi_we_i     (obi_we),
        .obi_be_i     (obi_be),
        .obi_addr_i   (obi_addr),
        .obi_wdata_i  (obi_wdata),
        .obi_rdata_o  (obi_rdata),
        .axi_awvalid_o(axi_awvalid),
        .axi_awready_i(axi_awready),
        .axi_awaddr_o (axi_awaddr),
        .axi_awprot_o (axi_awprot),
        .axi_wvalid_o (axi_wvalid),
        .axi_wready_i (axi_wready),
        .axi_wdata_o  (axi_wdata),
        .axi_wstrb_o  (axi_wstrb),
        .axi_bvalid_i (axi_bvalid),
        .axi_bready_o (axi_bready),
        .axi_bresp_i  (axi_bresp),
        .axi_arvalid_o(axi_arvalid),
        .axi_arready_i(axi_arready),
        .axi_araddr_o (axi_araddr),
        .axi_arprot_o (axi_arprot),
        .axi_rvalid_i (axi_rvalid),
        .axi_rready_o (axi_rready),
        .axi_rdata_i  (axi_rdata),
        .axi_rresp_i  (axi_rresp)
    );

    // ------------------------------------------------------------------------
    // Clock & Reset
    // ------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    initial begin
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
    end

    // ------------------------------------------------------------------------
    // AXI4-Lite Slave Model (Testbench tarafi)
    //
    // Bridge'in AXI master'ini bekleyip dummy slave gibi davranir:
    //   - awready: 1 cycle bekledikten sonra ack
    //   - wready:  1 cycle bekledikten sonra ack
    //   - bvalid:  AW + W tamamlandiktan sonra 2 cycle
    //   - arready: 1 cycle bekledikten sonra ack
    //   - rvalid:  AR'dan 2 cycle sonra, dummy data ile
    // ------------------------------------------------------------------------
    logic [31:0] last_wdata;       // Yazilan datayi tut, read'de geri ver
    logic [31:0] last_waddr;

    initial begin
        axi_awready = 0;
        axi_wready  = 0;
        axi_bvalid  = 0;
        axi_bresp   = 2'b00;
        axi_arready = 0;
        axi_rvalid  = 0;
        axi_rdata   = 32'h0;
        axi_rresp   = 2'b00;
    end

    // AW kanali: awvalid'den 1 cycle sonra awready
    always @(posedge clk) begin
        if (!rst_n) begin
            axi_awready <= 0;
        end else begin
            if (axi_awvalid && !axi_awready) begin
                axi_awready <= 1;
                last_waddr  <= axi_awaddr;
            end else begin
                axi_awready <= 0;
            end
        end
    end

    // W kanali: wvalid'den 1 cycle sonra wready
    always @(posedge clk) begin
        if (!rst_n) begin
            axi_wready <= 0;
        end else begin
            if (axi_wvalid && !axi_wready) begin
                axi_wready <= 1;
                last_wdata <= axi_wdata;
            end else begin
                axi_wready <= 0;
            end
        end
    end

    // B kanali: AW+W tamamlandiktan 2 cycle sonra bvalid
    int bvalid_delay = 0;
    always @(posedge clk) begin
        if (!rst_n) begin
            axi_bvalid   <= 0;
            bvalid_delay <= 0;
        end else begin
            if (axi_awready && axi_wready && bvalid_delay == 0) begin
                bvalid_delay <= 2;
            end else if (bvalid_delay > 1) begin
                bvalid_delay <= bvalid_delay - 1;
            end else if (bvalid_delay == 1) begin
                axi_bvalid   <= 1;
                bvalid_delay <= 0;
            end else if (axi_bvalid && axi_bready) begin
                axi_bvalid <= 0;
                writes_done <= writes_done + 1;
            end
        end
    end

    // AR kanali: arvalid'den 1 cycle sonra arready
    always @(posedge clk) begin
        if (!rst_n) begin
            axi_arready <= 0;
        end else begin
            if (axi_arvalid && !axi_arready) begin
                axi_arready <= 1;
            end else begin
                axi_arready <= 0;
            end
        end
    end

    // R kanali: AR'dan 2 cycle sonra rvalid + dummy data
    int rvalid_delay = 0;
    always @(posedge clk) begin
        if (!rst_n) begin
            axi_rvalid   <= 0;
            rvalid_delay <= 0;
            axi_rdata    <= 32'h0;
        end else begin
            if (axi_arready && rvalid_delay == 0) begin
                rvalid_delay <= 2;
                axi_rdata    <= 32'hCAFE0000 | {16'h0, axi_araddr[15:0]};
            end else if (rvalid_delay > 1) begin
                rvalid_delay <= rvalid_delay - 1;
            end else if (rvalid_delay == 1) begin
                axi_rvalid   <= 1;
                rvalid_delay <= 0;
            end else if (axi_rvalid && axi_rready) begin
                axi_rvalid <= 0;
                reads_done <= reads_done + 1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Test Senaryolari
    // ------------------------------------------------------------------------
    task automatic obi_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        obi_req   = 1;
        obi_we    = 1;
        obi_addr  = addr;
        obi_wdata = data;
        obi_be    = 4'b1111;
        // gnt bekle
        wait (obi_gnt);
        @(posedge clk);
        obi_req = 0;
        // rvalid bekle
        wait (obi_rvalid);
        @(posedge clk);
    endtask

    task automatic obi_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        obi_req   = 1;
        obi_we    = 0;
        obi_addr  = addr;
        obi_wdata = 32'h0;
        obi_be    = 4'b1111;
        wait (obi_gnt);
        @(posedge clk);
        obi_req = 0;
        wait (obi_rvalid);
        data = obi_rdata;
        @(posedge clk);
    endtask

    logic [31:0] read_data;

    initial begin
        obi_req   = 0;
        obi_we    = 0;
        obi_addr  = 32'h0;
        obi_wdata = 32'h0;
        obi_be    = 4'b0000;

        $display("[TB] Bridge testbench BASLADI");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 1: Tek WRITE transaction");
        obi_write(32'h4000_0000, 32'hDEAD_BEEF);
        if (last_wdata !== 32'hDEAD_BEEF) begin
            $display("[TB] HATA: last_wdata=%h, beklenen DEAD_BEEF", last_wdata);
            errors++;
        end else $display("[TB] PASS: WRITE data dogru");
        repeat (3) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 2: Tek READ transaction");
        obi_read(32'h4000_1234, read_data);
        if (read_data !== 32'hCAFE_1234) begin
            $display("[TB] HATA: read_data=%h, beklenen CAFE_1234", read_data);
            errors++;
        end else $display("[TB] PASS: READ data dogru (CAFE_1234)");
        repeat (3) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 3: Back-to-back 5 WRITE");
        for (int i = 0; i < 5; i++) begin
            obi_write(32'h4000_2000 + (i*4), 32'hA000_0000 + i);
        end
        $display("[TB] 5 WRITE tamamlandi (writes_done=%0d)", writes_done);
        repeat (3) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] Test 4: Back-to-back 5 READ");
        for (int i = 0; i < 5; i++) begin
            obi_read(32'h4000_3000 + (i*4), read_data);
        end
        $display("[TB] 5 READ tamamlandi (reads_done=%0d)", reads_done);
        repeat (3) @(posedge clk);

        // ----------------------------------------------------------
        $display("[TB] ====== TEST SONUCU ======");
        $display("[TB] writes_done = %0d (beklenen: 6)", writes_done);
        $display("[TB] reads_done  = %0d (beklenen: 6)", reads_done);
        $display("[TB] errors      = %0d", errors);
        if (writes_done == 6 && reads_done == 6 && errors == 0)
            $display("[TB] ====== ALL TESTS PASSED ======");
        else
            $display("[TB] ====== SOME TESTS FAILED ======");
        $finish;
    end

    // Watchdog: 10000 cycle gecerse simulasyon takildi demektir
    initial begin
        repeat (10000) @(posedge clk);
        $display("[TB] WATCHDOG: 10000 cycle gecti, sim takildi");
        $finish;
    end

endmodule
