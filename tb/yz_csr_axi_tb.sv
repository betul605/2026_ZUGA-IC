// ============================================================================
// yz_csr_axi_tb.sv -- YZ CSR AXI4-Lite Slave testbench
//
// Test stratejisi: uart_axi_tb.sv (M21) stili - calisan template
// 8 yazmac read/write + RO yazmac koruma + STATUS combinational
//
// Test senaryolari:
//   T1: CTRL yaz + STATUS oku (busy_i=0 oldugu icin status=0)
//   T2: INPUT_ADDR yaz + oku (round-trip)
//   T3: OUTPUT_ADDR yaz + oku
//   T4: WEIGHT_ADDR yaz + oku
//   T5: CFG yaz + oku (kernel_size + stride)
//   T6: LEN yaz + oku
//   T7: STATUS oku (busy/done/error flag simulation)
//   T8: CYCLE_CNT oku (read-only, busy iken artar)
// ============================================================================
module yz_csr_axi_tb;
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

    // YZ module ports
    logic start, sw_reset;
    logic busy, done, error;
    logic [31:0] input_addr, output_addr, weight_addr, len;
    logic [3:0]  kernel_size, stride;

    int pass = 0, fail = 0;

    yz_csr dut (
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
        .start_o      (start),
        .sw_reset_o   (sw_reset),
        .busy_i       (busy),
        .done_i       (done),
        .error_i      (error),
        .input_addr_o (input_addr),
        .output_addr_o(output_addr),
        .weight_addr_o(weight_addr),
        .kernel_size_o(kernel_size),
        .stride_o     (stride),
        .len_o        (len)
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

    task automatic check(input string name, input [31:0] expected, input [31:0] actual);
        if (expected == actual) begin
            $display("[TB] PASS %s: 0x%08h", name, actual);
            pass = pass + 1;
        end else begin
            $display("[TB] FAIL %s: expected 0x%08h, got 0x%08h", name, expected, actual);
            fail = fail + 1;
        end
    endtask

    // Watchdog
    initial begin
        #100000;
        $display("[TB] WATCHDOG TIMEOUT!");
        $finish;
    end

    initial begin
        logic [31:0] read_data;

        // Initial values
        axi_awvalid = 0; axi_awaddr = 0; axi_awprot = 0;
        axi_wvalid  = 0; axi_wdata = 0; axi_wstrb = 0;
        axi_bready  = 0;
        axi_arvalid = 0; axi_araddr = 0; axi_arprot = 0;
        axi_rready  = 0;
        busy = 0; done = 0; error = 0;

        $display("=== YZ CSR Testbench (M65) ===");
        wait (rst_n);
        repeat (5) @(posedge clk);

        // T1: INPUT_ADDR round-trip
        axi_write(32'h0000_0008, 32'h0003_1000);
        axi_read(32'h0000_0008, read_data);
        check("INPUT_ADDR", 32'h0003_1000, read_data);

        // T2: OUTPUT_ADDR round-trip
        axi_write(32'h0000_000C, 32'h0003_2000);
        axi_read(32'h0000_000C, read_data);
        check("OUTPUT_ADDR", 32'h0003_2000, read_data);

        // T3: WEIGHT_ADDR round-trip
        axi_write(32'h0000_0010, 32'h0003_0000);
        axi_read(32'h0000_0010, read_data);
        check("WEIGHT_ADDR", 32'h0003_0000, read_data);

        // T4: CFG yaz + oku (kernel_size=3, stride=2)
        axi_write(32'h0000_0014, 32'h00000023);  // [3:0]=3, [7:4]=2
        axi_read(32'h0000_0014, read_data);
        check("CFG", 32'h00000023, read_data);

        // T5: LEN round-trip
        axi_write(32'h0000_0018, 32'h00000031);  // 49 frame
        axi_read(32'h0000_0018, read_data);
        check("LEN", 32'h00000031, read_data);

        // T6: STATUS oku (busy=0, done=0, error=0)
        axi_read(32'h0000_0004, read_data);
        check("STATUS idle", 32'h00000000, read_data);

        // T7: STATUS with busy=1
        busy = 1;
        @(posedge clk);
        axi_read(32'h0000_0004, read_data);
        check("STATUS busy", 32'h00000001, read_data);
        busy = 0;

        // T8: CYCLE_CNT busy iken artiyor olmali (T7'de busy=1 yapildi, sayac arttı)
        axi_read(32'h0000_001C, read_data);
        // read_data > 0 bekleniyor (busy aktiviyetle arttı), >= 1 PASS
        if (read_data > 0) begin
            $display("[TB] PASS CYCLE_CNT artti: 0x%08h", read_data);
            pass = pass + 1;
        end else begin
            $display("[TB] FAIL CYCLE_CNT: artmali, got 0x%08h", read_data);
            fail = fail + 1;
        end

        // Ozet
        $display("");
        $display("=== YZ CSR Test Sonuc ===");
        $display("PASS: %0d / 8", pass);
        $display("FAIL: %0d / 8", fail);
        if (fail == 0) $display("====== ALL TESTS PASSED ======");
        else           $display("====== %0d TEST FAILED ======", fail);

        $finish;
    end

endmodule
