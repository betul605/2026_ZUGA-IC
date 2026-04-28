// ============================================================================
// fpga_top.sv  -- Arty A7-100T FPGA top-level wrapper
//
// Bu modul soc_top'i sarar ve FPGA-ozgun mantigi ekler:
//   - Clock divider: 100 MHz sysclk -> 50 MHz cekirdek saati (basit /2)
//   - Reset debounce: push button basisini 16-bit sayici ile temizle
//   - UART TX: soc'un tx pinini Arty USB-UART kopru pinine baglar
//   - GPIO: 4 LED'i ve 4 switch'i SoC'nin gpio portuna baglar
//
// Sentez sirasinda kullanilacak top modul. Simulasyonda kullanilmaz
// (tb_top.sv direkt soc_top'i kosturur).
//
// Hedef cihaz: Xilinx Artix-7 XC7A100TCSG324-1 (Arty A7-100T)
// ============================================================================

module fpga_top (
    input  logic        sysclk,        // 100 MHz osilator (E3)
    input  logic        cpu_resetn,    // Reset push button (D9, active low)

    // UART (USB-UART kopru)
    output logic        uart_tx,       // FPGA -> PC (D10)

    // 4 LED ciktisi
    output logic [3:0]  led,           // H5, J5, T9, T10

    // 4 switch girisi
    input  logic [3:0]  sw,            // A8, C11, C10, A10

    // I2C Master pinleri (PMOD JD, open-drain mantigi)
    output logic        i2c_scl,       // D3 (JD1)
    output logic        i2c_sda        // D4 (JD0)
);

    // ------------------------------------------------------------------------
    // Clock divider: 100 MHz -> 50 MHz (basit /2)
    // ------------------------------------------------------------------------
    logic clk_50;
    initial clk_50 = 1'b0;

    always_ff @(posedge sysclk) begin
        clk_50 <= ~clk_50;
    end

    // ------------------------------------------------------------------------
    // Reset debounce: push button + senkronizasyon + 16-bit bekleme
    // ------------------------------------------------------------------------
    logic        rst_n_meta;
    logic        rst_n_sync;
    logic [15:0] rst_cnt;
    logic        rst_n_clean;

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

    // ------------------------------------------------------------------------
    // SoC GPIO baglantilari
    // 16-bit gpio_in: alt 4 bit switch, geri kalan 0
    // 16-bit gpio_out: alt 4 bit LED, geri kalan acik
    // ------------------------------------------------------------------------
    logic [15:0] gpio_in_full;
    logic [15:0] gpio_out_full;

    assign gpio_in_full = {12'h000, sw[3:0]};
    assign led          = gpio_out_full[3:0];

    // ------------------------------------------------------------------------
    // SoC top instance
    // ------------------------------------------------------------------------
    // I2C ic sinyaller (soc_top'tan gelen output enable'lar)
    logic i2c_scl_o_int, i2c_scl_oe_int;
    logic i2c_sda_o_int, i2c_sda_oe_int;

    // Open-drain mantigi: oe=1 -> pin=0 (cek), oe=0 -> pin=1 (high-Z, pull-up varsayim)
    assign i2c_scl = ~i2c_scl_oe_int;
    assign i2c_sda = ~i2c_sda_oe_int;

    soc_top u_soc (
        .clk_i       (clk_50),
        .rst_ni      (rst_n_clean),
        .gpio_in_i   (gpio_in_full),
        .gpio_out_o  (gpio_out_full),
        .uart_tx_o   (uart_tx),
        .i2c_scl_o   (i2c_scl_o_int),
        .i2c_scl_oe  (i2c_scl_oe_int),
        .i2c_sda_o   (i2c_sda_o_int),
        .i2c_sda_oe  (i2c_sda_oe_int)
    );

endmodule
