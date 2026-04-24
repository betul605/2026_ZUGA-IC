// ============================================================================
// gpio.sv
// ----------------------------------------------------------------------------
// ÖTR EK-2 uyumlu GPIO çevre birimi:
//   16 giris  (input,  GPIO_IDR'den okunur)
//   16 cikis  (output, GPIO_ODR'ye yazilir)
//
// Yazmaç haritası:
//   Offset 0x00  GPIO_IDR  RO  [15:0]=gpio_in, [31:16]=0
//   Offset 0x04  GPIO_ODR  RW  [15:0] cikis pinlerini siruyor
//
// Bus arayuzu: basit OBI slave (req/gnt/rvalid + addr/we/wdata/rdata)
// ============================================================================

module gpio (
    input  logic        clk_i,
    input  logic        rst_ni,

    // OBI slave arayuzu
    input  logic        req_i,
    output logic        gnt_o,
    output logic        rvalid_o,
    input  logic        we_i,
    input  logic [3:0]  be_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    // GPIO pinleri
    input  logic [15:0] gpio_in_i,
    output logic [15:0] gpio_out_o
);

    // Yazmaclar
    logic [15:0] gpio_odr_q;  // Cikis yazmaci

    // Grant: her istegi hemen kabul et
    assign gnt_o = req_i;

    // Cikis pinleri dogrudan ODR yazmacindan surulur
    assign gpio_out_o = gpio_odr_q;

    // Yazma ve okuma mantigi
    // Sadece addr_i[3:2] bitlerine bakiyoruz (offset 0x00 vs 0x04)
    wire is_idr = (addr_i[3:2] == 2'b00);  // offset 0x00
    wire is_odr = (addr_i[3:2] == 2'b01);  // offset 0x04

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            gpio_odr_q <= 16'h0;
            rvalid_o   <= 1'b0;
            rdata_o    <= 32'h0;
        end else begin
            rvalid_o <= req_i && gnt_o;

            // Yazma islemi
            if (req_i && gnt_o && we_i && is_odr) begin
                // Byte-enable ile yazma (daha dogru ama basit tutalim)
                if (be_i[0]) gpio_odr_q[ 7:0] <= wdata_i[ 7:0];
                if (be_i[1]) gpio_odr_q[15:8] <= wdata_i[15:8];
            end

            // Okuma islemi
            if (req_i && gnt_o && !we_i) begin
                if (is_idr) begin
                    rdata_o <= {16'h0, gpio_in_i};
                end else if (is_odr) begin
                    rdata_o <= {16'h0, gpio_odr_q};
                end else begin
                    rdata_o <= 32'h0;
                end
            end
        end
    end

endmodule
