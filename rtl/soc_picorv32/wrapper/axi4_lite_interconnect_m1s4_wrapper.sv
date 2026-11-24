module axi4_lite_interconnect_m1s4_wrapper (
    input iCLK, iRST,

    /* axi4_lite slave interface 0 */
    if_axi4_lite.slave s0,

    /* axi4_lite master interface 0 */
    if_axi4_lite.master m0,
    if_axi4_lite.master m1,
    if_axi4_lite.master m2,
    if_axi4_lite.master m3

);

axi4_lite_interconnect_m1s4 u_axi4_lite_interconnect_m1s4 (
    .iCLK(iCLK),
    .iRST(iRST),

    /* axi4_lite slave interface 0 */
        /* write address channel */
        .m0_AWVALID(s0.awvalid),
        .m0_AWADDR(s0.awaddr),
        .m0_AWREADY(s0.awready),

        /* write data channel */
        .m0_WVALID(s0.wvalid),
        .m0_WSTRB(s0.wstrb),
        .m0_WDATA(s0.wdata),
        .m0_WREADY(s0.wready),

        /* write response channel */
        .m0_BREADY(s0.bready),
        .m0_BVALID(s0.bvalid),
        .m0_BRESP(s0.bresp),

        /* read address channel */
        .m0_ARVALID(s0.arvalid),
        .m0_ARADDR(s0.araddr),
        .m0_ARREADY(s0.arready),

        /* read data channel */
        .m0_RREADY(s0.rready),
        .m0_RVALID(s0.rvalid),
        .m0_RRESP(s0.rresp),
        .m0_RDATA(s0.rdata),

    /* axi4_lite master interface 0 */
        /* write address channel */
        .s0_AWVALID(m0.awvalid),
        .s0_AWADDR(m0.awaddr),
        .s0_AWREADY(m0.awready),

        /* write data channel */
        .s0_WVALID(m0.wvalid),
        .s0_WSTRB(m0.wstrb),
        .s0_WDATA(m0.wdata),
        .s0_WREADY(m0.wready),

        /* write response channel */
        .s0_BREADY(m0.bready),
        .s0_BVALID(m0.bvalid),
        .s0_BRESP(m0.bresp),

        /* read address channel */
        .s0_ARVALID(m0.arvalid),
        .s0_ARADDR(m0.araddr),
        .s0_ARREADY(m0.arready),

        /* read data channel */
        .s0_RREADY(m0.rready),
        .s0_RVALID(m0.rvalid),
        .s0_RRESP(m0.rresp),
        .s0_RDATA(m0.rdata),

    /* axi4_lite master interface 1 */
        /* write address channel */
        .s1_AWVALID(m1.awvalid),
        .s1_AWADDR(m1.awaddr),
        .s1_AWREADY(m1.awready),

        /* write data channel */
        .s1_WVALID(m1.wvalid),
        .s1_WSTRB(m1.wstrb),
        .s1_WDATA(m1.wdata),
        .s1_WREADY(m1.wready),

        /* write response channel */
        .s1_BREADY(m1.bready),
        .s1_BVALID(m1.bvalid),
        .s1_BRESP(m1.bresp),

        /* read address channel */
        .s1_ARVALID(m1.arvalid),
        .s1_ARADDR(m1.araddr),
        .s1_ARREADY(m1.arready),

        /* read data channel */
        .s1_RREADY(m1.rready),
        .s1_RVALID(m1.rvalid),
        .s1_RRESP(m1.rresp),
        .s1_RDATA(m1.rdata),

    /* axi4_lite master interface 2 */
        /* write address channel */
        .s2_AWVALID(m2.awvalid),
        .s2_AWADDR(m2.awaddr),
        .s2_AWREADY(m2.awready),

        /* write data channel */
        .s2_WVALID(m2.wvalid),
        .s2_WSTRB(m2.wstrb),
        .s2_WDATA(m2.wdata),
        .s2_WREADY(m2.wready),

        /* write response channel */
        .s2_BREADY(m2.bready),
        .s2_BVALID(m2.bvalid),
        .s2_BRESP(m2.bresp),

        /* read address channel */
        .s2_ARVALID(m2.arvalid),
        .s2_ARADDR(m2.araddr),
        .s2_ARREADY(m2.arready),

        /* read data channel */
        .s2_RREADY(m2.rready),
        .s2_RVALID(m2.rvalid),
        .s2_RRESP(m2.rresp),
        .s2_RDATA(m2.rdata),

    /* axi4_lite master interface 3 */
        /* write address channel */
        .s3_AWVALID(m3.awvalid),
        .s3_AWADDR(m3.awaddr),
        .s3_AWREADY(m3.awready),

        /* write data channel */
        .s3_WVALID(m3.wvalid),
        .s3_WSTRB(m3.wstrb),
        .s3_WDATA(m3.wdata),
        .s3_WREADY(m3.wready),

        /* write response channel */
        .s3_BREADY(m3.bready),
        .s3_BVALID(m3.bvalid),
        .s3_BRESP(m3.bresp),

        /* read address channel */
        .s3_ARVALID(m3.arvalid),
        .s3_ARADDR(m3.araddr),
        .s3_ARREADY(m3.arready),

        /* read data channel */
        .s3_RREADY(m3.rready),
        .s3_RVALID(m3.rvalid),
        .s3_RRESP(m3.rresp),
        .s3_RDATA(m3.rdata)

);


endmodule