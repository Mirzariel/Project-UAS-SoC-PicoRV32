module axi4_lite_ram_wrapper (
        input         clk,
        input         rst_n,
        if_axi4_lite.slave s0
    );

    // diubah: dari template wrapper ini masih kosong.
    // Isinya dibuat dengan pola yang sama seperti axi4_lite_rom_wrapper:
    // tiap kabel di interface s0 disambung ke port axi4_lite_ram.

    axi4_lite_ram u_axi4_lite_ram(
        .clk(clk),
        .rst_n(rst_n),

        /* write address channel */
        .axi_awvalid(s0.awvalid),
        .axi_awready(s0.awready),
        .axi_awaddr(s0.awaddr),

        /* write data channel */
        .axi_wvalid(s0.wvalid),
        .axi_wready(s0.wready),
        .axi_wdata(s0.wdata),
        .axi_wstrb(s0.wstrb),

        /* write response channel */
        .axi_bvalid(s0.bvalid),
        .axi_bready(s0.bready),

        /* read address channel */
        .axi_arvalid(s0.arvalid),
        .axi_arready(s0.arready),
        .axi_araddr(s0.araddr),

        /* read data channel */
        .axi_rvalid(s0.rvalid),
        .axi_rready(s0.rready),
        .axi_rdata(s0.rdata)
    );

    // axi4_lite_ram tidak punya port bresp dan rresp,
    // jadi jawabannya selalu OKAY (2'b00)
    assign s0.bresp = 2'b00;
    assign s0.rresp = 2'b00;

endmodule
