// ============================================================================
// ram.sv
// Dual-port RAM — OBI-uyumlu.
//   Port A: read-only  (instruction)
//   Port B: read/write (data)
// ============================================================================

module ram #(
    parameter int unsigned SIZE_WORDS = 4096,
    parameter string       MEM_FILE   = "hello.hex"
)(
    input  logic        clk_i,
    input  logic        rst_ni,

    input  logic        a_req_i,
    output logic        a_gnt_o,
    output logic        a_rvalid_o,
    input  logic [31:0] a_addr_i,
    output logic [31:0] a_rdata_o,

    input  logic        b_req_i,
    output logic        b_gnt_o,
    output logic        b_rvalid_o,
    input  logic        b_we_i,
    input  logic [3:0]  b_be_i,
    input  logic [31:0] b_addr_i,
    input  logic [31:0] b_wdata_i,
    output logic [31:0] b_rdata_o
);

    localparam int unsigned ADDR_WIDTH = $clog2(SIZE_WORDS);

    logic [31:0] mem [SIZE_WORDS];

    logic [ADDR_WIDTH-1:0] a_word_addr;
    logic [ADDR_WIDTH-1:0] b_word_addr;
    assign a_word_addr = a_addr_i[ADDR_WIDTH+1:2];
    assign b_word_addr = b_addr_i[ADDR_WIDTH+1:2];

    assign a_gnt_o = a_req_i;
    assign b_gnt_o = b_req_i;

    logic [ADDR_WIDTH-1:0] a_addr_q;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            a_rvalid_o <= 1'b0;
            a_addr_q   <= '0;
        end else begin
            a_rvalid_o <= a_req_i && a_gnt_o;
            if (a_req_i && a_gnt_o) a_addr_q <= a_word_addr;
        end
    end
    assign a_rdata_o = mem[a_addr_q];

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            b_rvalid_o <= 1'b0;
            b_rdata_o  <= '0;
        end else begin
            b_rvalid_o <= b_req_i && b_gnt_o;

            if (b_req_i && b_gnt_o && b_we_i) begin
                if (b_be_i[0]) mem[b_word_addr][ 7: 0] <= b_wdata_i[ 7: 0];
                if (b_be_i[1]) mem[b_word_addr][15: 8] <= b_wdata_i[15: 8];
                if (b_be_i[2]) mem[b_word_addr][23:16] <= b_wdata_i[23:16];
                if (b_be_i[3]) mem[b_word_addr][31:24] <= b_wdata_i[31:24];
            end
            if (b_req_i && b_gnt_o && !b_we_i) begin
                b_rdata_o <= mem[b_word_addr];
            end
        end
    end

    initial begin
        for (int i = 0; i < SIZE_WORDS; i++) mem[i] = 32'h0;
        if (MEM_FILE != "") begin
            $display("[ram] Loading memory from %s", MEM_FILE);
            $readmemh(MEM_FILE, mem);
        end
    end

endmodule
