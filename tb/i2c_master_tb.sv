// ============================================================================
// i2c_master_tb.sv  -- I2C Master bagimsiz testbench
//
// Test akisi:
//   1. Reset
//   2. PRER = 4 (hizli simulasyon icin)
//   3. CTR = 1 (EN=1)
//   4. TXR = 0xA5 (test byte)
//   5. CMR = 0x90 (STA + WR)
//   6. State machine'in I2C trafik urettigini gozle
//   7. SDA ve SCL pinlerinin degisimini izle
// ============================================================================

`timescale 1ns/1ps

module i2c_master_tb;
    logic        clk;
    logic        rst_n;

    // OBI master signals (testbench drives)
    logic        req;
    logic        gnt;
    logic        rvalid;
    logic        we;
    logic [3:0]  be;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    // I2C output pins
    logic        scl_o, scl_oe;
    logic        sda_o, sda_oe;

    // DUT
    i2c_master u_dut (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .req_i    (req),
        .gnt_o    (gnt),
        .rvalid_o (rvalid),
        .we_i     (we),
        .be_i     (be),
        .addr_i   (addr),
        .wdata_i  (wdata),
        .rdata_o  (rdata),
        .scl_o    (scl_o),
        .scl_oe   (scl_oe),
        .sda_o    (sda_o),
        .sda_oe   (sda_oe)
    );

    // Clock 50 MHz
    initial clk = 0;
    always #10 clk = ~clk;

    // Pin gozlemcisi: scl_oe ve sda_oe degisimleri
    logic scl_oe_prev = 0;
    logic sda_oe_prev = 0;
    int   edge_count  = 0;
    always_ff @(posedge clk) begin
        if (rst_n && (scl_oe != scl_oe_prev) && edge_count < 60) begin
            $display("[%0t] SCL_OE: %b -> %b", $time, scl_oe_prev, scl_oe);
            edge_count <= edge_count + 1;
        end
        if (rst_n && (sda_oe != sda_oe_prev) && edge_count < 60) begin
            $display("[%0t] SDA_OE: %b -> %b", $time, sda_oe_prev, sda_oe);
            edge_count <= edge_count + 1;
        end
        scl_oe_prev <= scl_oe;
        sda_oe_prev <= sda_oe;
    end

    // OBI yazma helper task (basit, blocking)
    task obi_write(input [31:0] a, input [31:0] d);
        begin
            @(posedge clk);
            req   <= 1'b1;
            we    <= 1'b1;
            be    <= 4'hF;
            addr  <= a;
            wdata <= d;
            @(posedge clk);
            req   <= 1'b0;
            $display("[%0t] OBI WR addr=0x%h data=0x%h", $time, a, d);
        end
    endtask

    initial begin
        // Init
        rst_n = 0;
        req   = 0;
        we    = 0;
        be    = 0;
        addr  = 0;
        wdata = 0;
        $display("=== I2C Master Testbench Basliyor ===");
        #100;
        rst_n = 1;
        $display("[%0t] Reset kaldirildi", $time);

        // PRER = 4 (hizli simulasyon icin, gerc0ek 250)
        #50;
        obi_write(32'h00, 32'd4);

        // CTR = 1 (EN=1, default zaten ama reread)
        #50;
        obi_write(32'h04, 32'h00000001);

        // TXR = 0xA5 (test byte: 1010_0101)
        #50;
        obi_write(32'h08, 32'h000000A5);

        // CMR = STA + WR -> Start I2C transaction
        #50;
        obi_write(32'h10, 32'h00000090);

        // 9 bit transaction + start + stop = ~20 half-tick * 4 cycle = ~80 cycle
        // + ekstra margin
        #5000;
        $display("[%0t] Simulasyon bitti. Toplam edge: %0d", $time, edge_count);
        $finish;
    end

endmodule
