`timescale 1ns/1ps

module tb_top;

    logic clk   = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;

    soc_top u_soc (
        .clk_i  (clk),
        .rst_ni (rst_n)
    );

    // Debug
    int if_count = 0;
    always_ff @(posedge clk) begin
        if (rst_n && u_soc.instr_req && u_soc.instr_gnt && if_count < 80) begin
            $display("[%0t] IFETCH addr=0x%08h",
                     $time, u_soc.instr_addr);
            if_count <= if_count + 1;
        end
    end

    int dw_count = 0;
    always_ff @(posedge clk) begin
        if (rst_n && u_soc.data_req && u_soc.data_gnt && u_soc.data_we && dw_count < 40) begin
            $display("[%0t] DWRITE addr=0x%08h data=0x%08h",
                     $time, u_soc.data_addr, u_soc.data_wdata);
            dw_count <= dw_count + 1;
        end
    end

    // Cycle sayici — 1000 cycle sonra $finish
    int cycle_count = 0;
    always_ff @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            if (cycle_count == 100) $display("[SIM] 100 cycle gecti...");
            if (cycle_count == 500) $display("[SIM] 500 cycle gecti...");
            if (cycle_count == 1000) begin
                $display("[SIM] 1000 cycle dolduruldu, cikis.");
                $finish;
            end
        end
    end

    initial begin
        $display("=== Simulasyon basliyor ===");
        rst_n = 0;
        #200;              // 200ns reset tut (20 cycle)
        @(posedge clk);
        rst_n = 1;
        $display("[SIM] Reset kaldirildi");
        $write("UART output: ");
        // Artik cycle_count sayaci simulasyonu bitirecek
    end

endmodule
