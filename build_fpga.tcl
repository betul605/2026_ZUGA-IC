# ============================================================================
# build_fpga.tcl -- ZUGA-IC Nexys Video (XC7A200T) tam FPGA akisi (§4.3)
#
# Vivado non-project akisi: RTL oku -> sentez -> implementation -> raporlar -> bitstream.
# Uretir (build_fpga/ altinda):
#   - post_synth.dcp, post_route.dcp
#   - utilization_*.rpt, timing_*.rpt (STA), drc.rpt
#   - zuga_ic.bit (bitstream)
#
# Kullanim (repo kokunde):
#   vivado -mode batch -source build_fpga.tcl
# GUI icin:  vivado -source build_fpga.tcl
# ============================================================================

set PART   xc7a200tsbg484-1
set TOP    fpga_top_axi
set OUTDIR build_fpga
file mkdir $OUTDIR

# $readmemh("bootloader.hex") sentezde bulunabilsin diye cwd'ye kopyala
if {[file exists sw/bootloader.hex]} { file copy -force sw/bootloader.hex bootloader.hex }

# -------- RTL kaynaklari --------
# CV32E40P cekirdegi (paketler once)
set CORE {
    cv32e40p/rtl/include/cv32e40p_pkg.sv
    cv32e40p/rtl/include/cv32e40p_apu_core_pkg.sv
    cv32e40p/rtl/include/cv32e40p_fpu_pkg.sv
    cv32e40p/bhv/cv32e40p_sim_clock_gate.sv
    cv32e40p/rtl/cv32e40p_core.sv
    cv32e40p/rtl/cv32e40p_if_stage.sv
    cv32e40p/rtl/cv32e40p_id_stage.sv
    cv32e40p/rtl/cv32e40p_ex_stage.sv
    cv32e40p/rtl/cv32e40p_load_store_unit.sv
    cv32e40p/rtl/cv32e40p_controller.sv
    cv32e40p/rtl/cv32e40p_cs_registers.sv
    cv32e40p/rtl/cv32e40p_decoder.sv
    cv32e40p/rtl/cv32e40p_alu.sv
    cv32e40p/rtl/cv32e40p_mult.sv
    cv32e40p/rtl/cv32e40p_register_file_ff.sv
    cv32e40p/rtl/cv32e40p_sleep_unit.sv
    cv32e40p/rtl/cv32e40p_int_controller.sv
    cv32e40p/rtl/cv32e40p_obi_interface.sv
    cv32e40p/rtl/cv32e40p_prefetch_buffer.sv
    cv32e40p/rtl/cv32e40p_prefetch_controller.sv
    cv32e40p/rtl/cv32e40p_alu_div.sv
    cv32e40p/rtl/cv32e40p_ff_one.sv
    cv32e40p/rtl/cv32e40p_popcnt.sv
    cv32e40p/rtl/cv32e40p_compressed_decoder.sv
}
# ZUGA-IC bloklari + YZ + SoC + FPGA top
set ZUGA {
    rtl/obi_to_axi_lite.sv
    rtl/ram_axi.sv
    rtl/gpio_axi.sv
    rtl/timer_axi.sv
    rtl/uart_axi.sv
    rtl/i2c_master_axi.sv
    rtl/yz_csr.sv
    rtl/yz_accel.sv
    rtl/yz_top.sv
    rtl/soc_top_axi.sv
    rtl/fpga_top_axi.sv
}
read_verilog -sv [concat $CORE $ZUGA]
read_xdc constraints/nexys_video.xdc

# -------- Sentez --------
synth_design -top $TOP -part $PART \
    -include_dirs {cv32e40p/rtl/include cv32e40p/rtl cv32e40p/bhv}
write_checkpoint -force $OUTDIR/post_synth.dcp
report_utilization       -file $OUTDIR/utilization_synth.rpt
report_timing_summary    -file $OUTDIR/timing_synth.rpt

# -------- Implementation --------
opt_design
place_design
report_utilization       -file $OUTDIR/utilization_placed.rpt
phys_opt_design
route_design
write_checkpoint -force  $OUTDIR/post_route.dcp
report_timing_summary    -file $OUTDIR/timing_route.rpt
report_utilization       -file $OUTDIR/utilization_route.rpt
report_drc               -file $OUTDIR/drc.rpt

# -------- Bitstream --------
write_bitstream -force $OUTDIR/zuga_ic.bit

puts "==== FPGA AKISI TAMAM: $OUTDIR/zuga_ic.bit + raporlar ===="
# WNS kontrolu (pozitif slack = zamanlama kapandi)
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "==== WNS (setup slack) = $wns ns  (pozitif ise zamanlama KAPANDI) ===="
