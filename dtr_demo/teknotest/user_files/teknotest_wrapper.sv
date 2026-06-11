// ============================================================================
// teknotest_wrapper.sv  -- ZUGA-IC tasarimini TEKNOFEST testbench'e baglar
//
// Testbench 4 pin bekler: clk_i, resetn_i (active-low), uart_rx_i, uart_tx_o.
// SoC top (soc_top_axi) bu 4 pin disindaki portlar burada 0/1'e baglanir.
//
//   soc_top_axi portu     Wrapper baglantisi
//   -----------------     ------------------
//   clk_i             <-  clk_i        (50 MHz, testbench'ten)
//   rst_ni            <-  resetn_i     (active-low reset)
//   uart0_rx_i        <-  uart_rx_i    (tb -> dut)
//   uart0_tx_o        ->  uart_tx_o    (dut -> tb)
//   gpio_in_i         <-  16'h0000
//   uart1_tx_o, gpio_out_o, i2c_* -> acik / 1'b1
// ============================================================================
module teknotest_wrapper(
    input  clk_i,       // Clock input (50 MHz)
    input  resetn_i,    // Reset input (active low)
    input  uart_rx_i,   // UART RX Input  (tb -> dut)
    output uart_tx_o    // UART TX Output (dut -> tb)
);

    soc_top_axi u_soc (
        .clk_i       (clk_i),
        .rst_ni      (resetn_i),
        .gpio_in_i   (16'h0000),
        .gpio_out_o  (),
        .uart0_rx_i  (uart_rx_i),
        .uart0_tx_o  (uart_tx_o),
        .uart1_tx_o  (),
        .i2c_scl_o   (),
        .i2c_scl_oe  (),
        .i2c_sda_o   (),
        .i2c_sda_oe  (),
        .i2c_sda_i   (1'b1)
    );

endmodule
