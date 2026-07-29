// ============================================================================
// fpga_top_axi.sv  -- Nexys Video (XC7A200T) FPGA top-level wrapper
//
// soc_top_axi'yi (CV32E40P + AXI4-Lite cevre birimleri + YZ hizlandirici) sarar:
//   - Clock divider: 100 MHz sysclk -> 50 MHz cekirdek saati (basit /2)
//   - Reset debounce: cpu_resetn (aktif-dusuk) senkron + 16-bit bekleme
//   - UART-0 TX -> USB-UART kopru (host'a); UART-1 TX -> PMOD (YZ stream/debug)
//   - GPIO: 8 switch girisi, 8 LED cikisi
//   - I2C Master: acik-drenaj (open-drain) tristate (inout)
//
// Sentez top modulu (simulasyonda kullanilmaz; sim icin tb_top / tb_soc_top_axi).
// Hedef: Xilinx Artix-7 XC7A200T-1SBG484C (Nexys Video)
// ============================================================================
module fpga_top_axi (
    input  logic       sysclk,       // 100 MHz osilator (R4)
    input  logic       cpu_resetn,   // Reset butonu (aktif-dusuk)
    output logic       uart_tx,      // UART-0: FPGA -> host (USB-UART)
    output logic       uart1_tx,     // UART-1: YZ stream / debug (PMOD)
    output logic [7:0] led,          // 8 LED (gpio_out[7:0])
    input  logic [7:0] sw,           // 8 switch (gpio_in[7:0])
    inout  wire        i2c_scl,      // I2C SCL (open-drain, PMOD)
    inout  wire        i2c_sda       // I2C SDA (open-drain, PMOD)
);
    // -------- Clock divider: 100 MHz -> 50 MHz --------
    logic clk_50 = 1'b0;
    always_ff @(posedge sysclk) clk_50 <= ~clk_50;

    // -------- Reset debounce (cpu_resetn aktif-dusuk) --------
    logic rst_n_meta, rst_n_sync;
    logic [15:0] rst_cnt;
    logic rst_n_clean;
    always_ff @(posedge clk_50) begin
        rst_n_meta <= --------
 ;
        rst_n_sync <= rst_n_meta;
    end
    always_ff @(posedge clk_50 or negedge rst_n_sync) begin
        if (!rst_n_sync) begin
            rst_cnt <= 16'h0; rst_n_clean <= 1'b0;
        end else if (rst_cnt != 16'hFFFF) begin
            rst_cnt <= rst_cnt + 1; rst_n_clean <= 1'b0;
        end else begin
            rst_n_clean <= 1'b1;
        end
    end

    // -------- GPIO: switch -> gpio_in, gpio_out -> LED --------
    logic [15:0] gpio_in_full, gpio_out_full;
    assign gpio_in_full = {8'h00, sw};
    assign led          = gpio_out_full[7:0];

    // -------- I2C open-drain tristate (Vivado IOBUF cikarir) --------
    logic i2c_scl_o_int, i2c_scl_oe_int, i2c_sda_o_int, i2c_sda_oe_int, i2c_sda_i_int;
    assign i2c_scl     = i2c_scl_oe_int ? 1'b0 : 1'bz;   // master surer
    assign i2c_sda     = i2c_sda_oe_int ? 1'b0 : 1'bz;
    assign i2c_sda_i_int = i2c_sda;                        // pin geri okuma
    /* verilator lint_off PINCONNECTEMPTY */

    // -------- SoC (YZ dahil) --------
    soc_top_axi u_soc (
        .clk_i      (clk_50),
        .rst_ni     (rst_n_clean),
        .gpio_in_i  (gpio_in_full),
        .gpio_out_o (gpio_out_full),
        .uart0_tx_o (uart_tx),
        .uart1_tx_o (uart1_tx),
        .i2c_scl_o  (i2c_scl_o_int),
        .i2c_scl_oe (i2c_scl_oe_int),
        .i2c_sda_o  (i2c_sda_o_int),
        .i2c_sda_oe (i2c_sda_oe_int),
        .i2c_sda_i  (i2c_sda_i_int)
    );
    /* verilator lint_on PINCONNECTEMPTY */

endmodule
