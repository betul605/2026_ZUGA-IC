`timescale 1ns/1ps

module tb_top;

    logic clk   = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;

    // GPIO test pinleri
    logic        uart_tx;
    logic [15:0] gpio_in  = 16'h1234;
    logic [15:0] gpio_out;

    soc_top u_soc (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .gpio_in_i  (gpio_in),
        .gpio_out_o (gpio_out),
        .uart_tx_o  (uart_tx)
    );

    // Debug: instruction fetch izle
    int if_count = 0;
    always_ff @(posedge clk) begin
        if (rst_n && u_soc.instr_req && u_soc.instr_gnt && if_count < 80) begin
            $display("[%0t] IFETCH addr=0x%08h",
                     $time, u_soc.instr_addr);
            if_count <= if_count + 1;
        end
    end

    // Debug: data yazma izle
    int dw_count = 0;
    always_ff @(posedge clk) begin
        if (rst_n && u_soc.data_req && u_soc.data_gnt && u_soc.data_we && dw_count < 40) begin
            $display("[%0t] DWRITE addr=0x%08h data=0x%08h",
                     $time, u_soc.data_addr, u_soc.data_wdata);
            dw_count <= dw_count + 1;
        end
    end

    // tx_o (UART serial out) izleyicisi - her degisikligi raporla
    logic uart_tx_prev = 1'b1;
    int   tx_edge_count = 0;
    always_ff @(posedge clk) begin
        if (rst_n && (uart_tx != uart_tx_prev) && tx_edge_count < 30) begin
            $display("[%0t] TX_PIN edge: %b -> %b", $time, uart_tx_prev, uart_tx);
            tx_edge_count <= tx_edge_count + 1;
        end
        uart_tx_prev <= uart_tx;
    end

    // Cycle sayaci — 1000 cycle sonra $finish
    int cycle_count = 0;
    always_ff @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count == 100) $display("[SIM] 100 cycle gecti...");
            if (cycle_count == 500) $display("[SIM] 500 cycle gecti...");
            if (cycle_count == 1000) begin
                $display("[SIM] 1000 cycle dolduruldu, cikis.");
                $finish;
            end
        end
    end

    initial begin
        $display("=== Simulasyon basliyor ===");
        rst_n = 0;
        #200;
        @(posedge clk);
        rst_n = 1;
        $display("[SIM] Reset kaldirildi");
        $write("UART output: ");
    end

// ========================================================================
    // SVA Protocol Check — OBI bus assertion'lari
    // soc_top icindeki data_* ve instr_* sinyallerine bind ile baglanir.
    // RTL'i degistirmeden protokol kurallarini kontrol eder.
    // ========================================================================
    bind soc_top obi_assertions #(.BUS_NAME("DATA")) u_assert_data (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .req_i    (data_req),
        .gnt_i    (data_gnt),
        .rvalid_i (data_rvalid),
        .we_i     (data_we),
        .addr_i   (data_addr),
        .wdata_i  (data_wdata),
        .rdata_i  (data_rdata)
    );

    bind soc_top obi_assertions #(.BUS_NAME("INSTR")) u_assert_instr (
        .clk_i    (clk_i),
        .rst_ni   (rst_ni),
        .req_i    (instr_req),
        .gnt_i    (instr_gnt),
        .rvalid_i (instr_rvalid),
        .we_i     (1'b0),
        .addr_i   (instr_addr),
        .wdata_i  (32'h0),
        .rdata_i  (instr_rdata)
    );

endmodule