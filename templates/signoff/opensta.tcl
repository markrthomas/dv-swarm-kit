# opensta.tcl — canonical STA driver (T2 collateral). Set LIB + NETLIST (a liberty-
# mapped netlist) + TOP in the env; reads the repo's syn/constraints/*.sdc. Runs on
# OpenSTA (open pathfind) or PrimeTime (sign-off). Skips if LIB/NETLIST unset.
if {![info exists ::env(LIB)] || ![info exists ::env(NETLIST)] || ![info exists ::env(TOP)]} {
  puts "SKIP: set LIB + NETLIST + TOP (liberty-mapped netlist)."; exit 0 }
read_liberty $::env(LIB)
read_verilog  $::env(NETLIST)
link_design   $::env(TOP)
foreach f [glob -nocomplain [file join [file dirname [info script]] .. constraints *.sdc]] { read_sdc $f }
report_checks -path_delay max -digits 4
report_checks -path_delay min -digits 4
report_worst_slack -max ; report_worst_slack -min
report_tns ; report_wns ; report_check_types -violators
