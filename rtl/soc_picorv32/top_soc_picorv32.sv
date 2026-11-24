// ============================================================================
// top_soc_picorv32 : SoC PicoRV32 untuk board iCESugar v1.5 (iCE40UP5K)
//
//   PicoRV32 --bus_picorv32--> AXI4-Lite Interconnect
//                                |-- m0 : bus_rom    --> ROM    0x0000_0000
//                                |-- m1 : bus_ram    --> RAM    0x0001_0000
//                                |-- m2 : bus_gpio   --> GPIO   0x0002_0000
//                                |-- m3 : bus_tm1638 --> TM1638 0x0003_0000
//
// Dasar file ini adalah top_soc_picorv32.sv dari template dosen.
// Yang diubah ditandai dengan komentar "diubah".
// ============================================================================

module top_soc_picorv32(
    input           clock,          // 12 MHz dari board (pin 35)
    // diubah: port "reset" dihapus. iCESugar tidak punya tombol reset untuk
    // FPGA, jadi reset dibuat otomatis (power-on reset, lihat di bawah).
    inout [15:0]    gpio,
    // diubah: port TM1638 ditambahkan (namanya sama dengan contoh di soal)
    output          tm_cs,
    output          tm_clk,
    inout           tm_dio
);
    wire clk = clock;

    // ------------------------------------------------------------------------
    // diubah: power-on reset (sama seperti Tugas-SoC-2)
    // Setelah FPGA selesai dikonfigurasi semua register bernilai 0,
    // jadi rst_n = 0 (reset aktif) selama 16 clock, lalu menjadi 1.
    // ------------------------------------------------------------------------
    reg [3:0] hitung_reset = 4'd0;
    reg       rst_n        = 1'b0;

    always @(posedge clk) begin
        if (hitung_reset != 4'hF)
            hitung_reset <= hitung_reset + 4'd1;
        else
            rst_n <= 1'b1;
    end

    // ------------------------------------------------------------------------
    // bus (satu interface = satu panah di diagram)
    // diubah: bus_tm1638 ditambahkan untuk slave m3
    // ------------------------------------------------------------------------
    if_axi4_lite bus_picorv32(.clk(clk), .rst_n(rst_n));
    if_axi4_lite bus_rom(.clk(clk), .rst_n(rst_n));
    if_axi4_lite bus_ram(.clk(clk), .rst_n(rst_n));
    if_axi4_lite bus_gpio(.clk(clk), .rst_n(rst_n));
    if_axi4_lite bus_tm1638(.clk(clk), .rst_n(rst_n));

    // diubah (untuk semua instance di bawah): ".m0(bus_picorv32.master)"
    // menjadi ".m0(bus_picorv32)". iverilog menolak bentuk ".master/.slave"
    // dengan error "Interface port `m0' must be connected to a simple
    // interface instance name". Arah sinyal tetap diatur oleh modport yang
    // ditulis di port wrapper (if_axi4_lite.master / if_axi4_lite.slave).

    picorv32_axi_wrapper u_picorv32_axi_wrapper (
        .clk(clk),
        .rstn(rst_n),               // diubah: koma yang hilang ditambahkan
        .m0(bus_picorv32)
    );
    axi4_lite_interconnect_m1s4_wrapper u_interconnect(
        .iCLK(clk),
        .iRST(rst_n),
        .s0(bus_picorv32),
        .m0(bus_rom),
        .m1(bus_ram),
        .m2(bus_gpio),
        .m3(bus_tm1638)             // diubah: sebelumnya ".m3()," (kosong, koma lebih)
    );
    axi4_lite_rom_wrapper u_axi4_lite_rom_wrapper(
        .clk(clk),
        .rst_n(rst_n),
        .s0(bus_rom)
    );
    axi4_lite_ram_wrapper u_axi4_lite_ram_wrapper(
        .clk(clk),
        .rst_n(rst_n),
        .s0(bus_ram)
    );
    axi4_lite_gpio_wrapper u_axi4_lite_gpio_wrapper(
        .clk(clk),
        .rstn(rst_n),
        .s0(bus_gpio),
        .gpio(gpio),
        .gpio_dir()
    );
    // diubah: slave TM1638 ditambahkan
    axi4_lite_tm1638_wrapper u_axi4_lite_tm1638_wrapper(
        .clk(clk),
        .rstn(rst_n),
        .s0(bus_tm1638),
        .tm_cs(tm_cs),
        .tm_clk(tm_clk),
        .tm_dio(tm_dio)
    );
endmodule
