`timescale 1ns/1ps
module tb_top;
  logic clk  = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;

  logic [31:0] imem [0:4095];
  logic [31:0] dmem [0:4095];

  logic        instr_req;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;

  logic        data_req;
  logic        data_gnt;
  logic        data_rvalid;
  logic        data_we;
  logic [3:0]  data_be;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata;

  cv32e40p_core #(
    .COREV_PULP       (0),
    .COREV_CLUSTER    (0),
    .FPU              (0),
    .FPU_ADDMUL_LAT   (0),
    .FPU_OTHERS_LAT   (0),
    .ZFINX            (0),
    .NUM_MHPMCOUNTERS (1)
  ) u_core (
    .clk_i              (clk),
    .rst_ni             (rst_n),
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

  // ===================================================================
  //  INSTRUCTION MEMORY — adresi latch'le, rdata bir cycle gecikmeli
  // ===================================================================
  assign instr_gnt = instr_req;

  logic [31:0] instr_addr_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      instr_rvalid <= 1'b0;
      instr_addr_q <= 32'h0;
    end else begin
      instr_rvalid <= instr_req && instr_gnt;
      if (instr_req && instr_gnt) instr_addr_q <= instr_addr;
    end
  end
  assign instr_rdata = imem[instr_addr_q[13:2]];

  // ===================================================================
  //  DATA MEMORY + UART
  // ===================================================================
  assign data_gnt = data_req;

  logic [31:0] data_addr_q;
  logic        data_we_q;
  logic [31:0] data_wdata_q;

  wire is_uart_req   = data_req && data_we && (data_addr[31:28] == 4'h1);
  wire is_uart_latch = data_we_q && (data_addr_q[31:28] == 4'h1);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_rvalid  <= 1'b0;
      data_addr_q  <= 32'h0;
      data_we_q    <= 1'b0;
      data_wdata_q <= 32'h0;
    end else begin
      data_rvalid <= data_req && data_gnt;
      if (data_req && data_gnt) begin
        data_addr_q  <= data_addr;
        data_we_q    <= data_we;
        data_wdata_q <= data_wdata;
      end else begin
        data_we_q <= 1'b0;
      end

      // UART/memory işlemi: grant ile aynı cycle'da gerçekleşsin
      if (data_req && data_gnt && data_we) begin
        if (data_addr[31:28] == 4'h1) begin
          $write("%c", data_wdata[7:0]);
          $fflush();
        end else begin
          dmem[data_addr[13:2]] <= data_wdata;
        end
      end
    end
  end

  // Okuma: bir cycle gecikmeli
  always_ff @(posedge clk) begin
    if (rst_n && data_req && data_gnt && !data_we) begin
      data_rdata <= dmem[data_addr[13:2]];
    end
  end

  // ===================================================================
  //  DEBUG traces
  // ===================================================================
  int if_count = 0;
  always_ff @(posedge clk) begin
    if (rst_n && instr_req && instr_gnt && if_count < 30) begin
      $display("[%0t] IFETCH addr=0x%08h (fetched_next_cycle)",
               $time, instr_addr);
      if_count <= if_count + 1;
    end
  end

  int dw_count = 0;
  always_ff @(posedge clk) begin
    if (rst_n && data_req && data_gnt && data_we && dw_count < 30) begin
      $display("[%0t] DWRITE addr=0x%08h data=0x%08h",
               $time, data_addr, data_wdata);
      dw_count <= dw_count + 1;
    end
  end

  initial begin
    $readmemh("hello.hex", imem);
    $display("=== Hex (first 16) ===");
    for (int i = 0; i < 16; i++)
      $display("imem[%0d] = 0x%08h", i, imem[i]);
    $display("=======================");

    rst_n = 0;
    repeat(10) @(posedge clk);
    rst_n = 1;
    $display("Simulasyon basladi.");
    $write("UART output: ");

    repeat(400) @(posedge clk);

    $display("");
    $display("Simulasyon tamamlandi.");
    $finish;
  end
endmodule
