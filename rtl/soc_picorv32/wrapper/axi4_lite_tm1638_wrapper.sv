module axi4_lite_tm1638_wrapper(
        input clk,
        input rstn,
        if_axi4_lite.slave s0,
        output  tm_cs,
        output  tm_clk,
        output  tm_dio
    );

    // Pola sama dengan axi4_lite_gpio_wrapper: kabel interface s0
    // disambung satu per satu ke port axi4_lite_tm1638.

    axi4_lite_tm1638 u_axi4_lite_tm1638(
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(rstn),

        /* write address channel */
        .S_AXI_AWADDR(s0.awaddr),
        .S_AXI_AWVALID(s0.awvalid),
        .S_AXI_AWREADY(s0.awready),

        /* write data channel */
        .S_AXI_WDATA(s0.wdata),
        .S_AXI_WVALID(s0.wvalid),
        .S_AXI_WREADY(s0.wready),
        .S_AXI_WSTRB(s0.wstrb),

        /* write response channel */
        .S_AXI_BVALID(s0.bvalid),
        .S_AXI_BREADY(s0.bready),
        .S_AXI_BRESP(s0.bresp),

        /* read address channel */
        .S_AXI_ARADDR(s0.araddr),
        .S_AXI_ARVALID(s0.arvalid),
        .S_AXI_ARREADY(s0.arready),

        /* read data channel */
        .S_AXI_RDATA(s0.rdata),
        .S_AXI_RVALID(s0.rvalid),
        .S_AXI_RREADY(s0.rready),
        .S_AXI_RRESP(s0.rresp),

        /* pin ke modul TM1638 */
        .tm_cs(tm_cs),
        .tm_clk(tm_clk),
        .tm_dio(tm_dio)
    );

endmodule
