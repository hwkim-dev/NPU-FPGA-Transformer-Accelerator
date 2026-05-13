// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 pccxai
// =============================================================================
// system_top.v - minimal-bringup top for KV260 v002 NPU. RTL-only top
// (no BD). Instantiates Zynq UltraScale+ MPSoC (HPM0 reconfigured to 64-bit
// AXI4 full @ pl_clk0), Clocking Wizard (250->400 MHz), two proc_sys_reset
// blocks, and a single axi_protocol_converter v2.1 (AXI4 64 -> AXI4-Lite 64)
// feeding the NPU's AXI-Lite control interface. HP/ACP streams are tied off
// at this level (minimal bringup).
//
// Why this layout:
//   - SmartConnect has an internal block-design sub-cell that the standalone
//     Tcl synth flow leaves as a black box (Vivado 2025.2 sub-BD limitation).
//   - axi_interconnect v1.7 was removed; v2.1 has the same sub-BD issue.
//   - axi_protocol_converter v2.1 is a monolithic legacy IP - no sub-BD - and
//     when the PS HPM0 is set to 64-bit it can drive the NPU directly.
// =============================================================================
`timescale 1ns / 1ps

module system_top ();

  // ---------------------------------------------------------------------------
  // Internal nets
  // ---------------------------------------------------------------------------
  wire pl_clk0;
  wire pl_resetn0;
  wire clk_core_400;
  wire clk_wiz_locked;
  wire rst_axi_n;
  wire rst_core_n;

  // ---------------------------------------------------------------------------
  // PS HPM0 AXI4 full (64-bit) -> axi_protocol_converter slave
  // ---------------------------------------------------------------------------
  wire [15:0] ps_awid;
  wire [39:0] ps_awaddr;
  wire [7:0]  ps_awlen;
  wire [2:0]  ps_awsize;
  wire [1:0]  ps_awburst;
  wire        ps_awlock;
  wire [3:0]  ps_awcache;
  wire [2:0]  ps_awprot;
  wire        ps_awvalid;
  wire [15:0] ps_awuser;
  wire [3:0]  ps_awqos;
  wire        ps_awready;
  wire [63:0] ps_wdata;
  wire [7:0]  ps_wstrb;
  wire        ps_wlast;
  wire        ps_wvalid;
  wire        ps_wready;
  wire [15:0] ps_bid;
  wire [1:0]  ps_bresp;
  wire        ps_bvalid;
  wire        ps_bready;
  wire [15:0] ps_arid;
  wire [39:0] ps_araddr;
  wire [7:0]  ps_arlen;
  wire [2:0]  ps_arsize;
  wire [1:0]  ps_arburst;
  wire        ps_arlock;
  wire [3:0]  ps_arcache;
  wire [2:0]  ps_arprot;
  wire        ps_arvalid;
  wire [15:0] ps_aruser;
  wire [3:0]  ps_arqos;
  wire        ps_arready;
  wire [15:0] ps_rid;
  wire [63:0] ps_rdata;
  wire [1:0]  ps_rresp;
  wire        ps_rlast;
  wire        ps_rvalid;
  wire        ps_rready;

  // ---------------------------------------------------------------------------
  // axi_protocol_converter M00 (AXI4-Lite, 64-bit, 40-bit addr) -> NPU AXIL
  // ---------------------------------------------------------------------------
  wire [39:0] m_axil_awaddr;
  wire [2:0]  m_axil_awprot;
  wire        m_axil_awvalid;
  wire        m_axil_awready;
  wire [63:0] m_axil_wdata;
  wire [7:0]  m_axil_wstrb;
  wire        m_axil_wvalid;
  wire        m_axil_wready;
  wire [1:0]  m_axil_bresp;
  wire        m_axil_bvalid;
  wire        m_axil_bready;
  wire [39:0] m_axil_araddr;
  wire [2:0]  m_axil_arprot;
  wire        m_axil_arvalid;
  wire        m_axil_arready;
  wire [63:0] m_axil_rdata;
  wire [1:0]  m_axil_rresp;
  wire        m_axil_rvalid;
  wire        m_axil_rready;

  // NPU expects 12-bit address - take low bits from the converter output.
  wire [11:0] axil_awaddr = m_axil_awaddr[11:0];
  wire [11:0] axil_araddr = m_axil_araddr[11:0];

  // ---------------------------------------------------------------------------
  // Zynq UltraScale+ MPSoC (HPM0 = 64-bit AXI4 full)
  // ---------------------------------------------------------------------------
  zynq_ultra_ps_e_0 ps_inst (
    .pl_clk0           (pl_clk0),
    .pl_resetn0        (pl_resetn0),
    .maxihpm0_fpd_aclk (pl_clk0),

    .maxigp0_awid     (ps_awid),
    .maxigp0_awaddr   (ps_awaddr),
    .maxigp0_awlen    (ps_awlen),
    .maxigp0_awsize   (ps_awsize),
    .maxigp0_awburst  (ps_awburst),
    .maxigp0_awlock   (ps_awlock),
    .maxigp0_awcache  (ps_awcache),
    .maxigp0_awprot   (ps_awprot),
    .maxigp0_awvalid  (ps_awvalid),
    .maxigp0_awuser   (ps_awuser),
    .maxigp0_awready  (ps_awready),
    .maxigp0_wdata    (ps_wdata),
    .maxigp0_wstrb    (ps_wstrb),
    .maxigp0_wlast    (ps_wlast),
    .maxigp0_wvalid   (ps_wvalid),
    .maxigp0_wready   (ps_wready),
    .maxigp0_bid      (ps_bid),
    .maxigp0_bresp    (ps_bresp),
    .maxigp0_bvalid   (ps_bvalid),
    .maxigp0_bready   (ps_bready),
    .maxigp0_arid     (ps_arid),
    .maxigp0_araddr   (ps_araddr),
    .maxigp0_arlen    (ps_arlen),
    .maxigp0_arsize   (ps_arsize),
    .maxigp0_arburst  (ps_arburst),
    .maxigp0_arlock   (ps_arlock),
    .maxigp0_arcache  (ps_arcache),
    .maxigp0_arprot   (ps_arprot),
    .maxigp0_arvalid  (ps_arvalid),
    .maxigp0_aruser   (ps_aruser),
    .maxigp0_arready  (ps_arready),
    .maxigp0_rid      (ps_rid),
    .maxigp0_rdata    (ps_rdata),
    .maxigp0_rresp    (ps_rresp),
    .maxigp0_rlast    (ps_rlast),
    .maxigp0_rvalid   (ps_rvalid),
    .maxigp0_rready   (ps_rready),
    .maxigp0_awqos    (ps_awqos),
    .maxigp0_arqos    (ps_arqos)
  );

  // ---------------------------------------------------------------------------
  // Clocking Wizard 250 -> 400 MHz
  // ---------------------------------------------------------------------------
  clk_wiz_0 cw_inst (
    .clk_in1  (pl_clk0),
    .resetn   (pl_resetn0),
    .clk_out1 (clk_core_400),
    .locked   (clk_wiz_locked)
  );

  // ---------------------------------------------------------------------------
  // proc_sys_reset x 2 (one per clock domain)
  // ---------------------------------------------------------------------------
  proc_sys_reset_axi rst_axi_inst (
    .slowest_sync_clk   (pl_clk0),
    .ext_reset_in       (pl_resetn0),
    .aux_reset_in       (1'b1),
    .mb_debug_sys_rst   (1'b0),
    .dcm_locked         (1'b1),
    .peripheral_aresetn (rst_axi_n)
  );

  proc_sys_reset_core rst_core_inst (
    .slowest_sync_clk   (clk_core_400),
    .ext_reset_in       (pl_resetn0),
    .aux_reset_in       (1'b1),
    .mb_debug_sys_rst   (1'b0),
    .dcm_locked         (clk_wiz_locked),
    .peripheral_aresetn (rst_core_n)
  );

  // ---------------------------------------------------------------------------
  // axi_protocol_converter v2.1: AXI4 64-bit (S) -> AXI4-Lite 64-bit (M)
  //   - ID_WIDTH=16, AWUSER/ARUSER=16 to match ZynqMP HPM0 HPM_FPD widths.
  //   - WUSER/RUSER/BUSER=0.
  //   - Monolithic legacy IP, no sub-BD.
  // ---------------------------------------------------------------------------
  axi_pc_axil sc_inst (
    .aclk           (pl_clk0),
    .aresetn        (rst_axi_n),

    // ---- AXI4 full slave (from PS HPM0) ----
    .s_axi_awid     (ps_awid),
    .s_axi_awaddr   (ps_awaddr),
    .s_axi_awlen    (ps_awlen),
    .s_axi_awsize   (ps_awsize),
    .s_axi_awburst  (ps_awburst),
    .s_axi_awlock   (ps_awlock),
    .s_axi_awcache  (ps_awcache),
    .s_axi_awprot   (ps_awprot),
    .s_axi_awregion (4'b0),
    .s_axi_awqos    (ps_awqos),
    .s_axi_awvalid  (ps_awvalid),
    .s_axi_awready  (ps_awready),
    .s_axi_wdata    (ps_wdata),
    .s_axi_wstrb    (ps_wstrb),
    .s_axi_wlast    (ps_wlast),
    .s_axi_wvalid   (ps_wvalid),
    .s_axi_wready   (ps_wready),
    .s_axi_bid      (ps_bid),
    .s_axi_bresp    (ps_bresp),
    .s_axi_bvalid   (ps_bvalid),
    .s_axi_bready   (ps_bready),
    .s_axi_arid     (ps_arid),
    .s_axi_araddr   (ps_araddr),
    .s_axi_arlen    (ps_arlen),
    .s_axi_arsize   (ps_arsize),
    .s_axi_arburst  (ps_arburst),
    .s_axi_arlock   (ps_arlock),
    .s_axi_arcache  (ps_arcache),
    .s_axi_arprot   (ps_arprot),
    .s_axi_arregion (4'b0),
    .s_axi_arqos    (ps_arqos),
    .s_axi_arvalid  (ps_arvalid),
    .s_axi_arready  (ps_arready),
    .s_axi_rid      (ps_rid),
    .s_axi_rdata    (ps_rdata),
    .s_axi_rresp    (ps_rresp),
    .s_axi_rlast    (ps_rlast),
    .s_axi_rvalid   (ps_rvalid),
    .s_axi_rready   (ps_rready),

    // ---- AXI4-Lite master (to NPU) ----
    .m_axi_awaddr   (m_axil_awaddr),
    .m_axi_awprot   (m_axil_awprot),
    .m_axi_awvalid  (m_axil_awvalid),
    .m_axi_awready  (m_axil_awready),
    .m_axi_wdata    (m_axil_wdata),
    .m_axi_wstrb    (m_axil_wstrb),
    .m_axi_wvalid   (m_axil_wvalid),
    .m_axi_wready   (m_axil_wready),
    .m_axi_bresp    (m_axil_bresp),
    .m_axi_bvalid   (m_axil_bvalid),
    .m_axi_bready   (m_axil_bready),
    .m_axi_araddr   (m_axil_araddr),
    .m_axi_arprot   (m_axil_arprot),
    .m_axi_arvalid  (m_axil_arvalid),
    .m_axi_arready  (m_axil_arready),
    .m_axi_rdata    (m_axil_rdata),
    .m_axi_rresp    (m_axil_rresp),
    .m_axi_rvalid   (m_axil_rvalid),
    .m_axi_rready   (m_axil_rready)
  );

  // ---------------------------------------------------------------------------
  // NPU core wrapper - minimal bringup (HP/ACP tied off)
  // ---------------------------------------------------------------------------
  npu_core_wrapper #(
    .AXIL_ADDR_W (12),
    .AXIL_DATA_W (64),
    .HP_DATA_W   (128),
    .ACP_DATA_W  (128)
  ) npu_inst (
    .clk_core   (clk_core_400),
    .rst_n_core (rst_core_n),
    .clk_axi    (pl_clk0),
    .rst_axi_n  (rst_axi_n),
    .i_clear    (1'b0),

    .s_axil_awaddr  (axil_awaddr),
    .s_axil_awvalid (m_axil_awvalid),
    .s_axil_awready (m_axil_awready),
    .s_axil_wdata   (m_axil_wdata),
    .s_axil_wstrb   (m_axil_wstrb),
    .s_axil_wvalid  (m_axil_wvalid),
    .s_axil_wready  (m_axil_wready),
    .s_axil_bresp   (m_axil_bresp),
    .s_axil_bvalid  (m_axil_bvalid),
    .s_axil_bready  (m_axil_bready),
    .s_axil_araddr  (axil_araddr),
    .s_axil_arvalid (m_axil_arvalid),
    .s_axil_arready (m_axil_arready),
    .s_axil_rdata   (m_axil_rdata),
    .s_axil_rresp   (m_axil_rresp),
    .s_axil_rvalid  (m_axil_rvalid),
    .s_axil_rready  (m_axil_rready),

    .s_axis_hp0_tdata  (128'h0), .s_axis_hp0_tvalid (1'b0), .s_axis_hp0_tready (),
    .s_axis_hp1_tdata  (128'h0), .s_axis_hp1_tvalid (1'b0), .s_axis_hp1_tready (),
    .s_axis_hp2_tdata  (128'h0), .s_axis_hp2_tvalid (1'b0), .s_axis_hp2_tready (),
    .s_axis_hp3_tdata  (128'h0), .s_axis_hp3_tvalid (1'b0), .s_axis_hp3_tready (),

    .s_axis_acp_fmap_tdata  (128'h0),
    .s_axis_acp_fmap_tvalid (1'b0),
    .s_axis_acp_fmap_tready (),

    .m_axis_acp_result_tdata  (),
    .m_axis_acp_result_tvalid (),
    .m_axis_acp_result_tready (1'b1)
  );

endmodule
