// ============================================================================
// soc_top.sv
// Sistem üst modülü:
//   CV32E40P çekirdeği + RAM + primitive UART
//   Basit adres decoder ile data bus dallanır.
// ============================================================================

module soc_top (
    input  logic clk_i,
    input  logic rst_ni
);

    // ----- Çekirdek OBI instruction port -----
    logic        instr_req;
    logic        instr_gnt;
    logic        instr_rvalid;
    logic [31:0] instr_addr;
    logic [31:0] instr_rdata;

    // ----- Çekirdek OBI data port -----
    logic        data_req;
    logic        data_gnt;
    logic        data_rvalid;
    logic        data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;

    // ----- CV32E40P çekirdeği -----
    cv32e40p_core #(
        .COREV_PULP       (0),
        .COREV_CLUSTER    (0),
        .FPU              (0),
        .FPU_ADDMUL_LAT   (0),
        .FPU_OTHERS_LAT   (0),
        .ZFINX            (0),
        .NUM_MHPMCOUNTERS (1)
    ) u_core (
        .clk_i              (clk_i),
        .rst_ni             (rst_ni),
        .pulp_clock_en_i    (1'b1),
        .scan_cg_en_i       (1'b0),
        .boot_addr_i        (32'h00000000),
        .mtvec_addr_i       (32'h00000000),
        .dm_halt_addr_i     (32'h1A110800),
        .hart_id_i          (32'h0),
        .dm_exception_addr_i(32'h0),

        .instr_req_o        (instr_req),
        .instr_gnt_i        (instr_gnt),
        .instr_rvalid_i     (instr_rvalid),
        .instr_addr_o       (instr_addr),
        .instr_rdata_i      (instr_rdata),

        .data_req_o         (data_req),
        .data_gnt_i         (data_gnt),
        .data_rvalid_i      (data_rvalid),
        .data_we_o          (data_we),
        .data_be_o          (data_be),
        .data_addr_o        (data_addr),
        .data_wdata_o       (data_wdata),
        .data_rdata_i       (data_rdata),

        .apu_busy_o         (),
        .apu_req_o          (),
        .apu_gnt_i          (1'b0),
        .apu_operands_o     (),
        .apu_op_o           (),
        .apu_flags_o        (),
        .apu_rvalid_i       (1'b0),
        .apu_result_i       (32'h0),
        .apu_flags_i        (5'h0),

        .irq_i              (32'b0),
        .irq_ack_o          (),
        .irq_id_o           (),

        .debug_req_i        (1'b0),
        .debug_havereset_o  (),
        .debug_running_o    (),
        .debug_halted_o     (),

        .fetch_enable_i     (1'b1),
        .core_sleep_o       ()
    );

    // ========================================================================
    // Adres decoder: data bus dallanır
    //   addr[31:28] == 4'h1  → UART
    //   diğer                → RAM data port
    // ========================================================================
    wire sel_uart_req = (data_addr[31:28] == 4'h1);
    wire sel_ram_req  = ~sel_uart_req;

    // RAM data port sinyalleri
    logic        ram_b_req, ram_b_gnt, ram_b_rvalid;
    logic [31:0] ram_b_rdata;

    // UART sinyalleri
    logic        uart_req, uart_gnt, uart_rvalid;
    logic [31:0] uart_rdata;

    // Req'i uygun modüle yonlendir
    assign ram_b_req = data_req & sel_ram_req;
    assign uart_req  = data_req & sel_uart_req;

    // Gnt hemen doner — request cycle'da
    assign data_gnt = sel_uart_req ? uart_gnt : ram_b_gnt;

    // rvalid icin SELECT'i bir cycle GECIKMELI kullan
    // cunku rvalid req'ten bir cycle sonra gelir ve o cycle'da
    // data_addr baska bir seye donmus olabilir.
    logic sel_uart_q;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) sel_uart_q <= 1'b0;
        else if (data_req && data_gnt) sel_uart_q <= sel_uart_req;
    end

    assign data_rvalid = sel_uart_q ? uart_rvalid : ram_b_rvalid;
    assign data_rdata  = sel_uart_q ? uart_rdata  : ram_b_rdata;

    // ========================================================================
    // RAM — 4K word = 16 KB
    // Port A: instruction
    // Port B: data (yalnızca RAM adreslerinde)
    // ========================================================================
    ram #(
        .SIZE_WORDS (4096),
        .MEM_FILE   ("hello.hex")
    ) u_ram (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),

        .a_req_i    (instr_req),
        .a_gnt_o    (instr_gnt),
        .a_rvalid_o (instr_rvalid),
        .a_addr_i   (instr_addr),
        .a_rdata_o  (instr_rdata),

        .b_req_i    (ram_b_req),
        .b_gnt_o    (ram_b_gnt),
        .b_rvalid_o (ram_b_rvalid),
        .b_we_i     (data_we),
        .b_be_i     (data_be),
        .b_addr_i   (data_addr),
        .b_wdata_i  (data_wdata),
        .b_rdata_o  (ram_b_rdata)
    );

    // ========================================================================
    // UART — 0x10000000 bölgesi
    // ========================================================================
    uart_primitive u_uart (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),

        .req_i      (uart_req),
        .gnt_o      (uart_gnt),
        .rvalid_o   (uart_rvalid),
        .we_i       (data_we),
        .be_i       (data_be),
        .addr_i     (data_addr),
        .wdata_i    (data_wdata),
        .rdata_o    (uart_rdata)
    );

endmodule
