// ============================================================================
// axi4_lite_tm1638  (TM1638 LED & KEY controller di bus AXI4-Lite)
//
// Modul ini punya SATU register yang bisa ditulis CPU:
//
//   alamat 0x00 : ANGKA (32 bit)
//                 - 7-segment menampilkan ANGKA dalam heksadesimal (8 digit,
//                   digit paling kiri = 4 bit paling atas)
//                 - LED1..LED8 menampilkan ANGKA[24:17] (LED1 = bit 24),
//                   dipilih supaya kedipnya kelihatan mata (lihat makalah)
//
// Program dari dosen (firmware.hex) menulis counter ke alamat 0x0003_0000.
// Di SoC UAS alamat itu adalah slave m3 = TM1638, jadi counter itu langsung
// tampil di modul LED&KEY tanpa mengubah programnya.
//
// Isi modul ada 3 bagian:
//   1. Bagian AXI      : disalin dari pola axi4_lite_gpio.v milik dosen
//   2. Bagian tampilan : urutan perintah ke TM1638, diambil dari bagian
//                        DISPLAY di top.v dosen (project ABJ)
//   3. tm1638.v dosen  : mesin pengirim 1 byte (tidak diubah isinya)
//
// Tombol S1..S8 tidak dibaca (tidak dibutuhkan untuk demo ini).
// ============================================================================

module axi4_lite_tm1638 #(
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

    // pin ke modul TM1638
    output reg                               tm_cs,     // STB, aktif rendah
    output wire                              tm_clk,
    output wire                              tm_dio
);

    // ========================================================================
    // 1. Bagian AXI (pola sama dengan axi4_lite_gpio.v)
    // ========================================================================
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_ANGKA = 'h00;
    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;

    reg [31:0] angka;               // register ANGKA yang ditulis CPU

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
            angka        <= 32'h0000_0000;
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

            // tulis dilakukan kalau alamat dan data sudah sama-sama datang
            if ((aw_pending || aw_hs) && (w_pending || w_hs) && !S_AXI_BVALID) begin
                if (wr_addr == ADDR_ANGKA) begin
                    for (k=0; k<4; k=k+1) begin
                        if (wr_strb[k])
                            angka[k*8 +: 8] <= wr_data[k*8 +: 8];
                    end
                    S_AXI_BRESP <= RESP_OKAY;
                end else begin
                    S_AXI_BRESP <= RESP_SLVERR;
                end
                S_AXI_BVALID <= 1'b1;
                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
            end

            // baca: CPU boleh membaca balik ANGKA
            if (ar_hs) begin
                if (S_AXI_ARADDR == ADDR_ANGKA) begin
                    S_AXI_RDATA <= angka;
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

    // ========================================================================
    // 2. Bagian tampilan: urutan perintah ke TM1638
    //    (diambil dari langkah 12..36 di top.v dosen)
    //
    //    langkah 0..2  : perintah 0x40 = tulis data, alamat naik otomatis
    //    langkah 3..21 : perintah 0xC0 = mulai dari alamat 0, lalu 16 byte:
    //                    alamat genap = segmen digit, alamat ganjil = LED
    //    langkah 22..24: perintah 0x8F = display nyala, terang maksimum
    //    lalu kembali ke langkah 0 (display di-refresh terus-menerus)
    //
    //    Satu langkah baru dikerjakan setiap 16 clock (dan tm1638 tidak
    //    sibuk). Jadi STB pasti tinggi minimal 16 clock = 1,3 us di 12 MHz.
    // ========================================================================
    reg  [4:0]  langkah;        // nomor langkah 0..24
    reg  [3:0]  jeda;           // penghitung 16 clock antar langkah
    reg         kirim;          // pulsa 1 clock: suruh tm1638 kirim 1 byte
    reg  [7:0]  byte_kirim;     // byte yang dikirim
    reg  [31:0] angka_foto;     // salinan ANGKA, diambil sekali per refresh
                                // supaya 8 digit berasal dari angka yang sama
    wire        sibuk;

    // nomor byte data (0..15) saat langkah 5..20
    wire [3:0]  nomor_byte = langkah - 5'd5;
    wire [2:0]  nomor_digit = nomor_byte[3:1];   // 0 = digit paling kiri

    // LED1..LED8 = ANGKA[24:17]
    wire [7:0]  led = angka_foto[24:17];

    // ambil 4 bit (1 digit heksa) dari angka_foto
    reg  [3:0]  nibble;
    always @* begin
        case (nomor_digit)
            3'd0: nibble = angka_foto[31:28];
            3'd1: nibble = angka_foto[27:24];
            3'd2: nibble = angka_foto[23:20];
            3'd3: nibble = angka_foto[19:16];
            3'd4: nibble = angka_foto[15:12];
            3'd5: nibble = angka_foto[11:8];
            3'd6: nibble = angka_foto[7:4];
            default: nibble = angka_foto[3:0];
        endcase
    end

    // dekoder heksa ke 7-segment (bit 0 = segmen a ... bit 6 = segmen g)
    // pola angka 1..8 sama dengan S_1..S_8 di top.v dosen
    reg  [6:0]  segmen;
    always @* begin
        case (nibble)
            4'h0: segmen = 7'b0111111;
            4'h1: segmen = 7'b0000110;
            4'h2: segmen = 7'b1011011;
            4'h3: segmen = 7'b1001111;
            4'h4: segmen = 7'b1100110;
            4'h5: segmen = 7'b1101101;
            4'h6: segmen = 7'b1111101;
            4'h7: segmen = 7'b0000111;
            4'h8: segmen = 7'b1111111;
            4'h9: segmen = 7'b1101111;
            4'hA: segmen = 7'b1110111;
            4'hB: segmen = 7'b1111100;
            4'hC: segmen = 7'b0111001;
            4'hD: segmen = 7'b1011110;
            4'hE: segmen = 7'b1111001;
            default: segmen = 7'b1110001;   // F
        endcase
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            langkah    <= 5'd0;
            jeda       <= 4'd0;
            kirim      <= 1'b0;
            byte_kirim <= 8'h00;
            angka_foto <= 32'h0000_0000;
            tm_cs      <= 1'b1;         // TM1638 belum dipilih
        end else begin
            kirim <= 1'b0;              // kirim hanya 1 clock
            jeda  <= jeda + 4'd1;

            if (jeda == 4'd15 && !sibuk) begin
                langkah <= langkah + 5'd1;

                case (langkah)
                    // perintah data: tulis, alamat naik otomatis
                    5'd0: tm_cs <= 1'b0;
                    5'd1: begin kirim <= 1'b1; byte_kirim <= 8'h40; end
                    5'd2: tm_cs <= 1'b1;

                    // perintah alamat 0, lalu 16 byte isi display
                    5'd3: begin tm_cs <= 1'b0; angka_foto <= angka; end
                    5'd4: begin kirim <= 1'b1; byte_kirim <= 8'hC0; end

                    5'd21: tm_cs <= 1'b1;

                    // perintah display nyala, terang maksimum
                    5'd22: tm_cs <= 1'b0;
                    5'd23: begin kirim <= 1'b1; byte_kirim <= 8'h8F; end
                    5'd24: begin tm_cs <= 1'b1; langkah <= 5'd0; end

                    // langkah 5..20: 16 byte isi display
                    default: begin
                        kirim <= 1'b1;
                        if (nomor_byte[0] == 1'b0)
                            byte_kirim <= {1'b0, segmen};               // digit
                        else
                            byte_kirim <= {7'b0, led[7 - nomor_digit]}; // LED
                    end
                endcase
            end
        end
    end

    // ========================================================================
    // 3. tm1638.v dosen: mengirim byte_kirim bit per bit lewat tm_clk/tm_dio
    //    rw = 1 terus (selalu menulis), jadi tm_dio cukup dipakai sebagai output
    // ========================================================================
    // port "data" di tm1638.v dua arah (inout), jadi cara menyambungnya
    // ditiru dari top.v dosen: kita yang mengisi data saat rw = 1,
    // dan melepas (Z) saat rw = 0.
    //
    // rw = 0 hanya saat reset, setelah itu 1 terus. (Kalau ditulis
    // rw = 1'b1, nextpnr error "byte_kirim[5] is multiply driven".)
    wire       rw = S_AXI_ARESETN;  // 1 = tulis ke TM1638
    wire [7:0] data_tm;
    assign data_tm = rw ? byte_kirim : 8'hZZ;

    tm1638 u_tm1638 (
        .clk        (S_AXI_ACLK),
        .rst        (~S_AXI_ARESETN),   // tm1638.v memakai reset aktif tinggi
        .data_latch (kirim),
        .data       (data_tm),
        .rw         (rw),
        .busy       (sibuk),
        .sclk       (tm_clk),
        .dio_in     (1'b0),             // tidak membaca tombol
        .dio_out    (tm_dio)
    );

endmodule
