/* verilator lint_off DECLFILENAME */
// ============================================================================
// axi_lite_assertions.sv  -- AXI4-Lite Protocol Check (SVA)
//
// Sartname §5.2 minimum kriter #3:
//   "AXI/AXI-Lite arayuzlerinin protocol check duzeyinde dogrulanmasi"
//
// Bu modul 5 ana AXI4-Lite spec kuralini SVA ile dogrular:
//   1. AW handshake stability   (AWVALID dustu mu AWREADY'siz?)
//   2. W handshake stability    (WVALID dustu mu WREADY'siz?)
//   3. B response stability     (BVALID + BRESP degisti mi BREADY'siz?)
//   4. AR handshake stability   (ARVALID dustu mu ARREADY'siz?)
//   5. R response stability     (RVALID + RDATA + RRESP degisti mi RREADY'siz?)
//
// Kullanim:
//   bind <slave_module> axi_lite_protocol_checker u_axi_check (
//       .clk_i(clk_i), .rst_ni(rst_ni),
//       .axi_awvalid_i(axi_awvalid_i), .axi_awready_o(axi_awready_o),
//       ... (tum AXI sinyalleri)
//   );
// ============================================================================

module axi_lite_protocol_checker (
    input  logic        clk_i,
    input  logic        rst_ni,

    // Write Address
    input  logic        axi_awvalid_i,
    input  logic        axi_awready_o,

    // Write Data
    input  logic        axi_wvalid_i,
    input  logic        axi_wready_o,

    // Write Response
    input  logic        axi_bvalid_o,
    input  logic        axi_bready_i,
    input  logic [1:0]  axi_bresp_o,

    // Read Address
    input  logic        axi_arvalid_i,
    input  logic        axi_arready_o,

    // Read Data
    input  logic        axi_rvalid_o,
    input  logic        axi_rready_i,
    input  logic [31:0] axi_rdata_o,
    input  logic [1:0]  axi_rresp_o
);

    // ------------------------------------------------------------------------
    // Assertion 1: AW handshake stability
    // AWVALID set edildikten sonra AWREADY gelene kadar dusmemelidir.
    // ------------------------------------------------------------------------
    property aw_valid_stable;
        @(posedge clk_i) disable iff (!rst_ni)
        (axi_awvalid_i && !axi_awready_o) |=> axi_awvalid_i;
    endproperty

    AW_VALID_STABLE: assert property (aw_valid_stable) else
        $error("[AXI-CHECK] AWVALID dustu, AWREADY gelmemis!");

    // ------------------------------------------------------------------------
    // Assertion 2: W handshake stability
    // WVALID set edildikten sonra WREADY gelene kadar dusmemelidir.
    // ------------------------------------------------------------------------
    property w_valid_stable;
        @(posedge clk_i) disable iff (!rst_ni)
        (axi_wvalid_i && !axi_wready_o) |=> axi_wvalid_i;
    endproperty

    W_VALID_STABLE: assert property (w_valid_stable) else
        $error("[AXI-CHECK] WVALID dustu, WREADY gelmemis!");

    // ------------------------------------------------------------------------
    // Assertion 3: B response stability
    // BVALID set edildikten sonra BREADY gelene kadar BVALID + BRESP
    // sabit kalmalidir.
    // ------------------------------------------------------------------------
    property b_resp_stable;
        @(posedge clk_i) disable iff (!rst_ni)
        (axi_bvalid_o && !axi_bready_i) |=> (axi_bvalid_o && $stable(axi_bresp_o));
    endproperty

    B_RESP_STABLE: assert property (b_resp_stable) else
        $error("[AXI-CHECK] BVALID/BRESP degisti, BREADY gelmemis!");

    // ------------------------------------------------------------------------
    // Assertion 4: AR handshake stability
    // ARVALID set edildikten sonra ARREADY gelene kadar dusmemelidir.
    // ------------------------------------------------------------------------
    property ar_valid_stable;
        @(posedge clk_i) disable iff (!rst_ni)
        (axi_arvalid_i && !axi_arready_o) |=> axi_arvalid_i;
    endproperty

    AR_VALID_STABLE: assert property (ar_valid_stable) else
        $error("[AXI-CHECK] ARVALID dustu, ARREADY gelmemis!");

    // ------------------------------------------------------------------------
    // Assertion 5: R response stability
    // RVALID set edildikten sonra RREADY gelene kadar RVALID + RDATA + RRESP
    // sabit kalmalidir.
    // ------------------------------------------------------------------------
    property r_resp_stable;
        @(posedge clk_i) disable iff (!rst_ni)
        (axi_rvalid_o && !axi_rready_i) |=>
        (axi_rvalid_o && $stable(axi_rdata_o) && $stable(axi_rresp_o));
    endproperty

    R_RESP_STABLE: assert property (r_resp_stable) else
        $error("[AXI-CHECK] RVALID/RDATA/RRESP degisti, RREADY gelmemis!");

    // ------------------------------------------------------------------------
    // Coverage: kac kez assertion tetiklendi (basarili kontrol)
    // ------------------------------------------------------------------------
    int aw_check_count = 0;
    int w_check_count  = 0;
    int b_check_count  = 0;
    int ar_check_count = 0;
    int r_check_count  = 0;

    always_ff @(posedge clk_i) begin
        if (rst_ni) begin
            if (axi_awvalid_i && axi_awready_o) aw_check_count <= aw_check_count + 1;
            if (axi_wvalid_i  && axi_wready_o ) w_check_count  <= w_check_count + 1;
            if (axi_bvalid_o  && axi_bready_i ) b_check_count  <= b_check_count + 1;
            if (axi_arvalid_i && axi_arready_o) ar_check_count <= ar_check_count + 1;
            if (axi_rvalid_o  && axi_rready_i ) r_check_count  <= r_check_count + 1;
        end
    end

    final begin
        $display("[AXI-CHECK] Sonuc raporu:");
        $display("[AXI-CHECK]   AW handshake count = %0d", aw_check_count);
        $display("[AXI-CHECK]   W  handshake count = %0d", w_check_count);
        $display("[AXI-CHECK]   B  response count  = %0d", b_check_count);
        $display("[AXI-CHECK]   AR handshake count = %0d", ar_check_count);
        $display("[AXI-CHECK]   R  response count  = %0d", r_check_count);
    end

endmodule
