# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 pccxai
# =============================================================================
# ip_create.tcl - instantiate KV260 platform IPs as Vivado IP-XACT cores so
# they can be referenced as plain modules from system_top.v.
#
# IPs created:
#   - zynq_ultra_ps_e_0      Zynq UltraScale+ MPSoC, KV260 preset.
#                            HPM0 reconfigured to 64-bit AXI4 full so we can
#                            chain it through a single axi_protocol_converter
#                            into the NPU's 64-bit AXI4-Lite slave (no width
#                            converter needed).
#   - clk_wiz_0              Clocking Wizard: 250 MHz -> 400 MHz
#   - proc_sys_reset_axi     proc_sys_reset for 250 MHz axi domain
#   - proc_sys_reset_core    proc_sys_reset for 400 MHz core domain
#   - axi_pc_axil            axi_protocol_converter v2.1 (AXI4 64 -> AXI4-Lite 64)
#
# Note on interconnect IP choice:
#   - SmartConnect (Vivado 2025.2) instantiates an internal block-design
#     sub-cell (bd_<hash>) that the standalone Tcl synth flow cannot expand,
#     leaving the IP a black box at impl/DRC.
#   - axi_interconnect v1.7 was removed in Vivado 2025.2; v2.1 is the
#     SmartConnect-style replacement and exhibits the same sub-BD limitation.
#   - axi_protocol_converter v2.1 is a legacy monolithic IP (no sub-BD), so
#     a single instance is the cleanest standalone-RTL flow.
# =============================================================================

# ---------------------------------------------------------------------------
# 0) Sweep stale SmartConnect / axi_interconnect IPs left over from earlier
#    attempts so they do not collide with the new flow.
# ---------------------------------------------------------------------------
foreach old_name {smartconnect_axil axi_interconnect_axil axi_pc_test} {
    foreach old [get_ips -quiet $old_name] {
        catch {
            set ipf [get_property IP_FILE $old]
            export_ip_user_files -of_objects [get_files $ipf] -no_script -reset -force
            remove_files [get_files $ipf]
        }
        puts "\[pccx\] removed stale IP $old_name"
    }
}

# ---------------------------------------------------------------------------
# 1) Zynq UltraScale+ MPSoC - KV260 preset, HPM0 forced to 64-bit AXI4 full.
# ---------------------------------------------------------------------------
if {[llength [get_ips zynq_ultra_ps_e_0]] == 0} {
    create_ip -name zynq_ultra_ps_e -vendor xilinx.com -library ip \
        -module_name zynq_ultra_ps_e_0
}

set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0             {1} \
    CONFIG.PSU__USE__M_AXI_GP2             {0} \
    CONFIG.PSU__USE__S_AXI_GP0             {0} \
    CONFIG.PSU__USE__S_AXI_GP2             {0} \
    CONFIG.PSU__USE__S_AXI_GP3             {0} \
    CONFIG.PSU__USE__S_AXI_GP4             {0} \
    CONFIG.PSU__USE__S_AXI_GP5             {0} \
    CONFIG.PSU__USE__S_AXI_ACP             {0} \
    CONFIG.PSU__USE__S_AXI_ACE             {0} \
    CONFIG.PSU__USE__IRQ0                  {0} \
    CONFIG.PSU__USE__IRQ1                  {0} \
    CONFIG.PSU__FPGA_PL0_ENABLE            {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {250} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH        {64} \
] [get_ips zynq_ultra_ps_e_0]

# ---------------------------------------------------------------------------
# 2) Clocking Wizard - 250 MHz -> 400 MHz
# ---------------------------------------------------------------------------
if {[llength [get_ips clk_wiz_0]] == 0} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip \
        -module_name clk_wiz_0
}

set_property -dict [list \
    CONFIG.PRIMITIVE                  {MMCM} \
    CONFIG.PRIM_IN_FREQ               {250.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {400.000} \
    CONFIG.USE_RESET                  {true} \
    CONFIG.RESET_TYPE                 {ACTIVE_LOW} \
    CONFIG.RESET_PORT                 {resetn} \
    CONFIG.USE_LOCKED                 {true} \
] [get_ips clk_wiz_0]

# ---------------------------------------------------------------------------
# 3) proc_sys_reset blocks (one per clock domain)
# ---------------------------------------------------------------------------
foreach ip {proc_sys_reset_axi proc_sys_reset_core} {
    if {[llength [get_ips $ip]] == 0} {
        create_ip -name proc_sys_reset -vendor xilinx.com -library ip \
            -module_name $ip
    }
}

# ---------------------------------------------------------------------------
# 4) axi_protocol_converter v2.1: AXI4 (64-bit) -> AXI4-Lite (64-bit)
# ---------------------------------------------------------------------------
if {[llength [get_ips axi_pc_axil]] == 0} {
    create_ip -name axi_protocol_converter -vendor xilinx.com -library ip \
        -module_name axi_pc_axil
}

set_property -dict [list \
    CONFIG.SI_PROTOCOL    {AXI4} \
    CONFIG.MI_PROTOCOL    {AXI4LITE} \
    CONFIG.DATA_WIDTH     {64} \
    CONFIG.ADDR_WIDTH     {40} \
    CONFIG.ID_WIDTH       {16} \
    CONFIG.AWUSER_WIDTH   {16} \
    CONFIG.ARUSER_WIDTH   {16} \
    CONFIG.WUSER_WIDTH    {0}  \
    CONFIG.RUSER_WIDTH    {0}  \
    CONFIG.BUSER_WIDTH    {0}  \
] [get_ips axi_pc_axil]

# ---------------------------------------------------------------------------
# Generate output products + launch IP synth runs.
# ---------------------------------------------------------------------------
foreach ip [list zynq_ultra_ps_e_0 clk_wiz_0 proc_sys_reset_axi proc_sys_reset_core axi_pc_axil] {
    set core [get_ips $ip]
    if {[llength $core] > 0} {
        generate_target -force all $core
        catch { create_ip_run $core }
    }
}

set ip_runs [get_runs -quiet *_synth_1]
if {[llength $ip_runs] > 0} {
    foreach r $ip_runs {
        catch { reset_run $r }
    }
    launch_runs -jobs 1 $ip_runs
    foreach r $ip_runs {
        wait_on_run $r
        puts "\[pccx\] IP run $r status: [get_property STATUS $r]"
    }
}

puts "\[pccx\] ip_create.tcl complete - KV260 platform IPs synthesised."
