// AXI4-Lite GPIO 16-bit bidirectional peripheral.
// Register map:
//   0x00 GPIO_DATA: write output latch; read current pin values
//   0x04 GPIO_DIR : bit=1 output, bit=0 input
// Pins are high-impedance in input mode. Reset defaults all pins to input.

module axi4_lite_gpio #(
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer C_S_AXI_DATA_WIDTH = 32
) (
    input  wire                              S_AXI_ACLK,
    input  wire                              S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    input  wire                              S_AXI_AWVALID,
    output wire                              S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire                              S_AXI_WVALID,
    output wire                              S_AXI_WREADY,
    output reg  [1:0]                        S_AXI_BRESP,
    output reg                               S_AXI_BVALID,
    input  wire                              S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    input  wire                              S_AXI_ARVALID,
    output wire                              S_AXI_ARREADY,
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    output reg  [1:0]                        S_AXI_RRESP,
    output reg                               S_AXI_RVALID,
    input  wire                              S_AXI_RREADY,
    inout  wire [15:0]                       gpio,
    output wire [15:0]                       gpio_dir
);

    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_GPIO_DATA = 'h00;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_GPIO_DIR  = 'h04;
    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    reg [15:0] gpio_out_reg;
    reg [15:0] gpio_dir_reg; // 1=output, 0=input

    assign gpio_dir = gpio_dir_reg;

    reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_reg;
    reg aw_pending, w_pending;
    reg [C_S_AXI_DATA_WIDTH-1:0] wdata_reg;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_reg;

    wire aw_hs = S_AXI_AWVALID && S_AXI_AWREADY;
    wire w_hs  = S_AXI_WVALID  && S_AXI_WREADY;
    wire b_hs  = S_AXI_BVALID  && S_AXI_BREADY;
    wire ar_hs = S_AXI_ARVALID && S_AXI_ARREADY;
    wire r_hs  = S_AXI_RVALID  && S_AXI_RREADY;

    assign S_AXI_AWREADY = S_AXI_ARESETN && !aw_pending && !S_AXI_BVALID;
    assign S_AXI_WREADY  = S_AXI_ARESETN && !w_pending  && !S_AXI_BVALID;
    assign S_AXI_ARREADY = S_AXI_ARESETN && !S_AXI_RVALID;

    genvar i;
    generate
        for (i=0; i<16; i=i+1) begin : GEN_GPIO
            assign gpio[i] = gpio_dir_reg[i] ? gpio_out_reg[i] : 1'bz;
        end
    endgenerate

    integer k;
    reg [C_S_AXI_ADDR_WIDTH-1:0] wr_addr;
    reg [C_S_AXI_DATA_WIDTH-1:0] wr_data;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wr_strb;

    always @* begin
        wr_addr = aw_pending ? awaddr_reg : S_AXI_AWADDR;
        wr_data = w_pending ? wdata_reg : S_AXI_WDATA;
        wr_strb = w_pending ? wstrb_reg : S_AXI_WSTRB;
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            gpio_out_reg <= 16'h0000;
            // diubah: 16'hFFFF -> 16'h0000 (semua input), sesuai komentar di
            // atas file ini. Kalau output, pin yang tersambung ke DIP switch
            // bisa "adu kuat" dengan switch.
            gpio_dir_reg <= 16'h0000;
            awaddr_reg   <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            aw_pending   <= 1'b0;
            w_pending    <= 1'b0;
            wdata_reg    <= {C_S_AXI_DATA_WIDTH{1'b0}};
            wstrb_reg    <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
            S_AXI_BRESP  <= RESP_OKAY;
            S_AXI_BVALID <= 1'b0;
            S_AXI_RDATA  <= {C_S_AXI_DATA_WIDTH{1'b0}};
            S_AXI_RRESP  <= RESP_OKAY;
            S_AXI_RVALID <= 1'b0;
        end else begin
            if (b_hs)
                S_AXI_BVALID <= 1'b0;

            if (aw_hs) begin
                awaddr_reg <= S_AXI_AWADDR;
                aw_pending <= 1'b1;
            end
            if (w_hs) begin
                wdata_reg <= S_AXI_WDATA;
                wstrb_reg <= S_AXI_WSTRB;
                w_pending <= 1'b1;
            end

            // Accept AW and W independently; perform write when both are available.
            if ((aw_pending || aw_hs) && (w_pending || w_hs) && !S_AXI_BVALID) begin
                if (wr_addr == ADDR_GPIO_DATA) begin
                    for (k=0; k<C_S_AXI_DATA_WIDTH/8; k=k+1) begin
                        if (k < 2 && wr_strb[k])
                            gpio_out_reg[k*8 +: 8] <= wr_data[k*8 +: 8];
                    end
                    S_AXI_BRESP <= RESP_OKAY;
                end else if (wr_addr == ADDR_GPIO_DIR) begin
                    for (k=0; k<C_S_AXI_DATA_WIDTH/8; k=k+1) begin
                        if (k < 2 && wr_strb[k])
                            gpio_dir_reg[k*8 +: 8] <= wr_data[k*8 +: 8];
                    end
                    S_AXI_BRESP <= RESP_OKAY;
                end else begin
                    S_AXI_BRESP <= RESP_SLVERR;
                end
                S_AXI_BVALID <= 1'b1;
                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
            end

            if (ar_hs) begin
                if (S_AXI_ARADDR == ADDR_GPIO_DATA) begin
                    S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-16){1'b0}}, gpio};
                    S_AXI_RRESP <= RESP_OKAY;
                end else if (S_AXI_ARADDR == ADDR_GPIO_DIR) begin
                    S_AXI_RDATA <= {{(C_S_AXI_DATA_WIDTH-16){1'b0}}, gpio_dir_reg};
                    S_AXI_RRESP <= RESP_OKAY;
                end else begin
                    S_AXI_RDATA <= {C_S_AXI_DATA_WIDTH{1'b0}};
                    S_AXI_RRESP <= RESP_SLVERR;
                end
                S_AXI_RVALID <= 1'b1;
            end
            if (r_hs)
                S_AXI_RVALID <= 1'b0;
        end
    end

endmodule
