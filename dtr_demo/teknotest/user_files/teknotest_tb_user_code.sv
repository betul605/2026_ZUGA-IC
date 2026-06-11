// ============================================================================
// teknotest_tb_user_code.sv  -- teknotest_tb.sv icine include edilir
//
// Boot ROM (instr_mem) icine test programini (helloworld.mem) yukler.
// soc_top_axi, TEKNOTEST_SIM define'i ile derlendiginden kendi bootloader.hex
// yuklemesi devre disidir; cakisma olmaz.
//
//   dut       : teknotest_tb icindeki wrapper instance
//   u_soc     : wrapper icindeki soc_top_axi instance
//   instr_mem : soc_top_axi icindeki birlesik instruction memory dizisi
//
// helloworld.mem, create_vivado_proj.tcl tarafindan projeye eklenir; bu yuzden
// dosya adi sabit kalmalidir.
// ============================================================================
initial begin
    $readmemh("helloworld.mem", dut.u_soc.instr_mem);
end
