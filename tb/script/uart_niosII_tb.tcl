#!/usr/bin/tclsh

##############################################################################
## No need to adapt anything in these first procedures. They automatically add
## signals to the display. Check for [TO ADAPT] to see where the script needs
## to be adapted to your specific VHDL code.
##############################################################################

#-----------------------------------------------------------------------------
# proc: inst_scan
#
# Scanning instances in the design
#-----------------------------------------------------------------------------
proc inst_scan {inst_name} {
  set sub_inst_list [lsort [find instances -recursive "$inst_name/*"]]
  set inst ""
  foreach inst $sub_inst_list {
    puts "Instance found: $inst"
    add_group $inst
    # inst_scan $inst
  }
}

#-----------------------------------------------------------------------------
# proc: add_wave
#
# Adding wave in waveform window
#-----------------------------------------------------------------------------
proc add_wave {group_def inst_name} {
 set obj_type_list  {
  {-ports} {"I/O ports"}
  {-internal} {Internals}
  }
  foreach {obj_type obj_group_name} $obj_type_list {
    set sig_list [lsort [find signals $inst_name/*]]
    foreach sig $sig_list {
       set CMD "add wave -noupdate -hex $group_def -group $obj_group_name $obj_type $sig"
       # puts $CMD
       if { [catch {eval $CMD} fid] } {
       }
    }
  }
}

#-----------------------------------------------------------------------------
# proc: add_group
#
# Adding group in waveform window
#-----------------------------------------------------------------------------
proc add_group {inst_name} {
  set ggg [split $inst_name "\ "]
  set inst_path [lindex $ggg 0]
  set group_list [split $inst_path "/"]
  # puts "group_list: $group_list"
  # puts "ggg: [lindex $ggg 0]"
  set group_def ""
  foreach i $group_list {
    if {$i != ""} {
      # puts "group: $i"
      append group_def "\-group\ \"$i\" "
    }
  }
  # puts "group_def: $group_def"
  add_wave $group_def $inst_path
}

#-----------------------------------------------------------------------------
# proc: auto_vaves
#
# Populate waveform window
#-----------------------------------------------------------------------------
proc auto_waves {} {
	# Scan instances in current directory and add all waves
	inst_scan ""

	# Wave display configuration
	configure wave -namecolwidth 220
	configure wave -valuecolwidth 100
	configure wave -justifyvalue left
	configure wave -signalnamewidth 1
	configure wave -snapdistance 10
	configure wave -datasetprefix 0
	configure wave -rowmargin 4
	configure wave -childrowmargin 2
	configure wave -gridoffset 0
	configure wave -gridperiod 1
	configure wave -griddelta 40
	configure wave -timeline 0
	configure wave -timelineunits us
}

##############################################################################
## [TO ADAPT] Put here references to your VHDL files from testbench to down.
##############################################################################

#-----------------------------------------------------------------------------
# proc: c
#
# Launch hdl compilation
#-----------------------------------------------------------------------------
proc c {} {
  set current_path [pwd]
  set project_path "$current_path/../.."

	vlib work
	vmap work work
	vcom -2008 -work work $project_path/tb/pkg/simu_pkg.vhd
	vcom -2008 -work work $project_path/tb/uart_niosII_tb.vhd
	vcom -2008 -work work $project_path/src/uart_niosII.vhd
	vcom -2008 -work work $project_path/src/uart.vhd
	vcom -2008 -work work $project_path/src/uart_tx.vhd
	vcom -2008 -work work $project_path/src/uart_rx.vhd
	vcom -2008 -work work $project_path/src/axi_stream_fifo.vhd
}

##############################################################################
## [TO ADAPT] Replace here "testbench" by the name of your testbech and
## "description" by the name of the architecture of your testbench.
## Also, replace "200 us" by the time span of the desired simulation.
##############################################################################

#-----------------------------------------------------------------------------
# proc: s
#
# Launch simulation
#-----------------------------------------------------------------------------
proc s {} {
	#vsim -gMY_GENERIC=255 -novopt -t 10ps work.testbench(behavioral)
	vsim -novopt -t 10ps work.testbench(description) -assertdebug -msgmode both
	auto_waves
  run -all
	# run 10 ms
}

proc clean {} {
	vmap -del work
	vdel -all -lib work
}

#-----------------------------------------------------------------------------
# proc: cs
#
# Launch compil & simulation
#-----------------------------------------------------------------------------
proc cs {} {
	c
	s
}

##############################################################################
## [TO ADAPT] Replace "200 us" by the time span of the desired simulation.
##############################################################################
proc rs {} {
	restart
	# TODO: Change time if needed
	run 30 ms 
}

#-----------------------------------------------------------------------------
# proc: clean
#
# Removes intermediate data
#-----------------------------------------------------------------------------
proc clean {} {

vmap -del work
vdel -all -lib work

}

#default call
cs
