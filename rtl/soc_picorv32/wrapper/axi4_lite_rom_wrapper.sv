module axi4_lite_rom_wrapper (
        input         clk,
        input         rst_n,
        if_axi4_lite.slave s0
    );

    axi4_lite_rom u_axi4_lite_rom(
        .clk(clk),
        .rst_n(rst_n),
        .axi_araddr(s0.araddr),
        .axi_arvalid(s0.arvalid),
        .axi_arready(s0.arready),
        .axi_rdata(s0.rdata),
        .axi_rvalid(s0.rvalid),
        .axi_rready(s0.rready) 
    );


endmodule
