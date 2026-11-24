module axi4_lite_gpio_wrapper(
        input clk,
        input rstn,
        if_axi4_lite.slave s0,
        inout   [15:0]  gpio,
        output  [15:0]  gpio_dir
    );

    axi4_lite_gpio u_axi4_lite_gpio(
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(rstn),

        /* write address channel */
        .S_AXI_AWADDR(s0.awaddr),
        .S_AXI_AWVALID(s0.awvalid),
        .S_AXI_AWREADY(s0.awready),
        // .S_AXI_AWPROT(s0.awprot),
        
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
        // .S_AXI_ARPROT(s0.arprot),     
        
        /* read data channel */
        .S_AXI_RDATA(s0.rdata),
        .S_AXI_RVALID(s0.rvalid),
        .S_AXI_RREADY(s0.rready),        
        .S_AXI_RRESP(s0.rresp),

        .gpio(gpio),
        .gpio_dir(gpio_dir)
        
    );

endmodule
