open_hw_manager
connect_hw_server -url localhost:3121
refresh_hw_server
set tgt [lindex [get_hw_targets] 0]
puts "TARGET: $tgt"
current_hw_target $tgt
set_property PARAM.FREQUENCY 5000000 $tgt
open_hw_target
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices] 0]
puts "DEVICES: [get_hw_devices]"
current_hw_device [lindex [get_hw_devices] 0]
set_property PROGRAM.FILE {build_fpga/zuga_ic.bit} [current_hw_device]
program_hw_devices [current_hw_device]
puts "==== KART PROGRAMLANDI ===="
close_hw_target
disconnect_hw_server
close_hw_manager
