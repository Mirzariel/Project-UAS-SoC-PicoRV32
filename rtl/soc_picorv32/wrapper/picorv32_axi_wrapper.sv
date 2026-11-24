`timescale 1ns / 1ps

module picorv32_axi_wrapper(
    input clk,
    input rstn,
    if_axi4_lite.master m0
    );
    
    picorv32_axi u_picorv32_axi (
	.clk(clk),
    .resetn(rstn),

    // AXI-4 LITE INTERFACE
    /* write address */
    .mem_axi_awaddr(m0.awaddr),
    .mem_axi_awvalid(m0.awvalid),
    .mem_axi_awready(m0.awready),
    .mem_axi_awprot(m0.awprot),

    /* write data */
    .mem_axi_wdata(m0.wdata),
    .mem_axi_wstrb(m0.wstrb),
    .mem_axi_wvalid(m0.wvalid),
    .mem_axi_wready(m0.wready),

    /* write response */
    .mem_axi_bvalid(m0.bvalid),
    .mem_axi_bready(m0.bready),

    /* read address */
    .mem_axi_araddr(m0.araddr),
    .mem_axi_arvalid(m0.arvalid),
    .mem_axi_arready(m0.arready),
    .mem_axi_arprot(m0.arprot),

    /* read data */
    .mem_axi_rdata(m0.rdata),
    .mem_axi_rvalid(m0.rvalid),
    .mem_axi_rready(m0.rready),

    // IRQ interface
    .irq(),
    .eoi(),
    .trap(),

	// Trace Interface
	.trace_valid(),
	.trace_data()
    );

endmodule
