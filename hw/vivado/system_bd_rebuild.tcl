# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 pccxai
# =============================================================================
# system_bd_rebuild.tcl - force-rerun synth + impl + write_bitstream against
# the existing BD project after an RTL change. Used when system_bd.tcl's
# default "reuse-existing-checkpoint" path picks up a stale synth_1.
# =============================================================================

set HW_ROOT [file normalize [file dirname [info script]]/..]
set XPR     $HW_ROOT/build/system_bd/pccx_v002_kv260_top.xpr

if {![file exists $XPR]} {
    puts "\[pccx\] no BD project at $XPR; run system_bd.tcl bitstream first to scaffold."
    exit 1
}

open_project $XPR
puts "\[pccx\] opened $XPR"

# Reset synth + impl so RTL changes are picked up
catch { reset_run synth_1 }
catch { reset_run impl_1 }
puts "\[pccx\] runs reset"

launch_runs synth_1 -jobs 1
wait_on_run synth_1
set st [get_property STATUS [get_runs synth_1]]
puts "\[pccx\] synth_1 status: $st"
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 did not complete: $st"
}

launch_runs impl_1 -to_step write_bitstream -jobs 1
wait_on_run impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[pccx\] impl_1 status: $st"

# Copy bitstream to the canonical location
set bit_src [glob -nocomplain $HW_ROOT/build/system_bd/pccx_v002_kv260_top.runs/impl_1/*.bit]
if {[llength $bit_src] > 0} {
    set bit_dst $HW_ROOT/build/pccx_v002_system_wrapper.bit
    file copy -force [lindex $bit_src 0] $bit_dst
    puts "\[pccx\] bitstream copied to $bit_dst"
}
