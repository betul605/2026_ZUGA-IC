// ============================================================================
// uart_primitive.sv
// Simülasyon için basit "UART" — her yazma isteğinde gelen baytı
// $write ile terminale basar. Gerçek UART değil, placeholder.
// ============================================================================

module uart_primitive (
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        req_i,
    output logic        gnt_o,
    output logic        rvalid_o,
    input  logic        we_i,
    input  logic [3:0]  be_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o
);

    assign gnt_o   = req_i;
    assign rdata_o = 32'h0;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rvalid_o <= 1'b0;
        end else begin
            rvalid_o <= req_i && gnt_o;

            if (req_i && gnt_o && we_i) begin
                $write("%c", wdata_i[7:0]);
                $fflush();
            end
        end
    end

endmodule
