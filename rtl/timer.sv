// ============================================================================
// timer.sv
// Basit Timer modulu — DTR icin minimal versiyon.
// ============================================================================

module timer (
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

    logic [31:0] cnt_q;
    logic        ena_q;

    assign gnt_o = req_i;

    wire is_clr = (addr_i[4:2] == 3'b010);
    wire is_ena = (addr_i[4:2] == 3'b011);
    wire is_cnt = (addr_i[4:2] == 3'b101);

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cnt_q    <= 32'h0;
            ena_q    <= 1'b0;
            rvalid_o <= 1'b0;
            rdata_o  <= 32'h0;
        end else begin
            rvalid_o <= req_i && gnt_o;

            if (req_i && gnt_o && we_i) begin
                if (is_clr) begin
                    cnt_q <= 32'h0;
                end else if (is_ena) begin
                    ena_q <= wdata_i[0];
                end else if (is_cnt) begin
                    cnt_q <= wdata_i;
                end
            end
            else if (ena_q) begin
                cnt_q <= cnt_q + 1;
            end

            if (req_i && gnt_o && !we_i) begin
                if (is_ena) begin
                    rdata_o <= {31'h0, ena_q};
                end else if (is_cnt) begin
                    rdata_o <= cnt_q;
                end else begin
                    rdata_o <= 32'h0;
                end
            end
        end
    end

endmodule
