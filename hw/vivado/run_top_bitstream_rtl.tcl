# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 pccxai
# =============================================================================
# run_top_bitstream_rtl.tcl — RTL-only top wrapper full bitstream flow.
#
# Bypasses BD / IP packaging (blocked by NPU IF_queue modport names not
# being IP-XACT compliant). Instead, system_top.v is a plain-Verilog top
# that directly instantiates the Zynq PS, Clocking Wizard, proc_sys_reset,
# and the AXI protocol converter as IP-XACT cores from ip_create.tcl.
#
# Output:
#   build/pccx_v002_kv260/project.runs/impl_1/system_top.bit
#   build/reports/top_*.rpt
# =============================================================================

set HW_ROOT   [file normalize [file dirname [info script]]/..]
set REPORTS   $HW_ROOT/build/reports
set PROJ_DIR  $HW_ROOT/build/pccx_v002_kv260
set PROJ_NAME pccx_v002_kv260
file mkdir $REPORTS

# ----------------------------------------------------------------------------
# 1) Open/create project. Re-use the OOC project; we will add new sources
#    and change the top.
# ----------------------------------------------------------------------------
if {[file exists $PROJ_DIR/$PROJ_NAME.xpr]} {
    puts "\[pccx\] re-opening existing project $PROJ_DIR/$PROJ_NAME.xpr"
    open_project $PROJ_DIR/$PROJ_NAME.xpr
} else {
    puts "\[pccx\] creating project via create_project.tcl"
    source $HW_ROOT/vivado/create_project.tcl
}

# Disable any OOC settings inherited from synth_1
set_property -name "STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS" -value "" \
    -objects [get_runs synth_1] -quiet

# ----------------------------------------------------------------------------
# 2) Add system_top.v + npu_core_wrapper.sv as plain RTL
# ----------------------------------------------------------------------------
set top_v   [file normalize $HW_ROOT/vivado/system_top.v]
set wrap_sv [file normalize $HW_ROOT/vivado/npu_core_wrapper.sv]
foreach f [list $top_v $wrap_sv] {
    if {[llength [get_files -quiet $f]] == 0} {
        add_files -norecurse $f
    }
}
set_property file_type SystemVerilog [get_files $wrap_sv]
set_property top system_top [current_fileset]

# ----------------------------------------------------------------------------
# 3) Generate the platform IPs (Zynq PS, clk_wiz, proc_sys_reset, smartconnect)
# ----------------------------------------------------------------------------
source $HW_ROOT/vivado/ip_create.tcl

update_compile_order -fileset sources_1

# ----------------------------------------------------------------------------
# 4) Reset old OOC synth_1 and re-run as top-level (not out-of-context)
# ----------------------------------------------------------------------------
catch { reset_run synth_1 }
catch { reset_run impl_1 }

set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]

# axi_interconnect v1.7 is a monolithic legacy IP (no sub-BD). All platform
# IPs may use OOC checkpoint synthesis - their synth_1 runs are launched by
# ip_create.tcl before top synth, so DCPs are ready at link-design time.

launch_runs synth_1 -jobs 1
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "\[pccx\] top synth_1 status: $synth_status"
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "top synth_1 did not complete: $synth_status"
}

launch_runs impl_1 -to_step write_bitstream -jobs 1
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "\[pccx\] top impl_1 status: $impl_status"
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "top impl_1 did not complete: $impl_status"
}

# ----------------------------------------------------------------------------
# 5) Export reports + bitstream
# ----------------------------------------------------------------------------
open_run impl_1

report_timing_summary -file $REPORTS/top_timing_summary.rpt
report_utilization    -file $REPORTS/top_utilization.rpt
report_drc            -file $REPORTS/top_drc.rpt
report_power          -file $REPORTS/top_power.rpt

set bit_src [glob -nocomplain $PROJ_DIR/$PROJ_NAME.runs/impl_1/system_top.bit]
set bit_dst $REPORTS/pccx_v002_kv260.bit
if {[llength $bit_src] > 0 && [file exists [lindex $bit_src 0]]} {
    file copy -force [lindex $bit_src 0] $bit_dst
    puts "\[pccx\] bitstream at $bit_dst"
} else {
    puts "\[pccx\] WARNING: bitstream not found"
}

# ----------------------------------------------------------------------------
# 6) Status file
# ----------------------------------------------------------------------------
set fp [open $REPORTS/top_status.txt w]
puts $fp "implementation_scope=FULL_TOP_LEVEL_RTL"
puts $fp "mode=run_top_bitstream_rtl"
puts $fp "synth_status=$synth_status"
puts $fp "impl_status=$impl_status"
puts $fp "bitstream_path=$bit_dst"
puts $fp "next_step=copy bitstream + DTBO to KV260 /lib/firmware/xilinx/pccx_npu/ and run xmutil loadapp"
close $fp

puts "\[pccx\] run_top_bitstream_rtl.tcl complete. Reports in $REPORTS."
