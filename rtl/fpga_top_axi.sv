// ============================================================================
// fpga_top_axi.sv : Nexys Video (XC7A200T) FPGA ust modulu
//
// soc_top_axi (CV32E40P + AXI4-Lite cevre birimleri + YZ hizlandirici) sarmalar.
// Saat bolucu (100 MHz -> 50 MHz), reset debounce, 8 LED / 8 switch,
// UART-0 (host) + UART-1 (PMOD), I2C acik drenaj (open drain) tristate.
// Sentez ust modulu; simulasyonda kullanilmaz.
// Hedef: Xilinx Artix-7 XC7A200T-1SBG484C (Nexys Video)
// ============================================================================
module fpga_top_axi (
    input  logic       sysclk,       // 100 MHz osilator
    input  logic       cpu_resetn,   // reset butonu (aktif dusuk)
    output logic       uart_tx,      // UART-0 : FPGA to host (USB UART)
    output logic       uart1_tx,     // UART-1 : YZ stream / debug (PMOD)
    output logic [7:0] led,          // 8 LED
    input  logic [7:0] sw,           // 8 switch
    inout  wire        i2c_scl,      // I2C SCL (acik drenaj)
    inout  wire        i2c_sda       // I2C SDA (acik drenaj)
);
    // Saat bolucu : 100 MHz ikiye bolunur, 50 MHz cekirdek saati
    logic clk_50 = 1'b0;
    always_ff @(posedge sysclk) begin
        clk_50 <= ~clk_50;
    end

    // Reset debounce : cpu_resetn senkronize edilir, 16 bit bekleme
    logic rst_n_meta, rst_n_sync;
    logic [15:0] rst_cnt;
    logic rst_n_clean;
    always_ff @(posedge clk_50) begin
        rst_n_meta <= cpu_resetn;
        rst_n_sync <= rst_n_meta;
    end
    always_ff @(posedge clk_50 or negedge rst_n_sync) begin
        if (!rst_n_sync) begin
            rst_cnt     <= 16'h0;
            rst_n_clean <= 1'b0;
        end else if (rst_cnt != 16'hFFFF) begin
            rst_cnt     <= rst_cnt + 1;
            rst_n_clean <= 1'b0;
        end else begin
            rst_n_clean <= 1'b1;
        end
    end

    // GPIO : switch girisleri, LED cikislari
    logic [15:0] gpio_in_full, gpio_out_full;
    assign gpio_in_full = {8'h00, sw};
    assign led          = gpio_out_full[7:0];

    // I2C acik drenaj tristate (Vivado IOBUF cikarir)
    logic i2c_scl_o_int, i2c_scl_oe_int, i2c_sda_o_int, i2c_sda_oe_int, i2c_sda_i_int;
    assign i2c_scl       = i2c_scl_oe_int ? 1'b0 : 1'bz;
    assign i2c_sda       = i2c_sda_oe_int ? 1'b0 : 1'bz;
    assign i2c_sda_i_int = i2c_sda;

    // SoC (YZ dahil)
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

endmodule
