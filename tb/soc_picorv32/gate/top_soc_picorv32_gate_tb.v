`timescale 1ns / 1ps

// ============================================================================
// Testbench GATE-LEVEL top_soc_picorv32
//
// Sama dengan top_soc_picorv32_tb.v, tetapi yang disimulasikan
// adalah NETLIST hasil yosys (build/build_soc_picorv32/top_soc_picorv32_netlist.v),
// yaitu rangkaian LUT, flip-flop, dan blok BRAM yang benar-benar masuk ke
// bitstream. Jadi kalau ada yang hilang saat sintesis (misalnya isi ROM),
// di sini akan ketahuan.
//
// Karena sinyal di dalam netlist sudah berganti nama, pengecekan yang
// memakai sinyal internal dihapus. Yang dicek:
//   - angka di 7-segment selalu bertambah dan kelipatan 3
//   - LED1..LED8 = bit 24..17 dari angka di layar
//   - perintah display nyala (0x8F) diterima
//
// Catatan: di simulasi gate-level tm_clk kadang turun-naik di waktu yang
// sama (glitch nol-detik) karena semua gerbang dianggap tanpa delay.
// Tepi seperti itu diabaikan oleh model TM1638 di bawah.
// ============================================================================

module top_soc_picorv32_gate_tb;

    // ------------------------------------------------------------------------
    // 1. clock 12 MHz -> periode 83,333 ns
    // ------------------------------------------------------------------------
    reg clock = 1'b0;
    always #41.667 clock = ~clock;

    wire [15:0] gpio;
    wire        tm_cs, tm_clk, tm_dio;

    top_soc_picorv32 dut (
        .clock (clock),
        .gpio  (gpio),
        .tm_cs (tm_cs),
        .tm_clk(tm_clk),
        .tm_dio(tm_dio)
    );

    // ------------------------------------------------------------------------
    // 2. model TM1638
    //    - byte dikirim LSB dulu, bit dibaca saat tm_clk naik
    //    - byte pertama setelah tm_cs turun = perintah
    //    - perintah 0xC0..0xCF = alamat awal, byte berikutnya = isi display
    // ------------------------------------------------------------------------
    reg [7:0] tampilan [0:15];      // isi display di dalam "chip"
    reg [7:0] geser;                // penampung bit
    integer   jumlah_bit;
    integer   urutan_byte;          // byte ke berapa sejak tm_cs turun
    reg [3:0] alamat;
    reg       display_nyala = 1'b0;
    integer   i;

    initial for (i = 0; i < 16; i = i + 1) tampilan[i] = 8'h00;

    always @(negedge tm_cs) begin
        jumlah_bit  = 0;
        urutan_byte = 0;
    end

    real t_turun = 0;
    always @(negedge tm_clk) t_turun = $realtime;
    always @(posedge tm_clk) begin
        // abaikan glitch nol-detik (turun lalu naik di waktu yang sama)
        if ($realtime - t_turun > 1.0 && tm_cs == 1'b0) begin
            geser = {tm_dio, geser[7:1]};       // LSB dulu
            jumlah_bit = jumlah_bit + 1;
            if (jumlah_bit == 8) begin
                jumlah_bit = 0;
                if (urutan_byte == 0) begin
                    // byte perintah
                    if (geser[7:6] == 2'b11) alamat = geser[3:0];   // 0xC0 + alamat
                    if (geser[7:6] == 2'b10) display_nyala = geser[3];  // 0x8F
                end else begin
                    tampilan[alamat] = geser;
                    alamat = alamat + 1;
                end
                urutan_byte = urutan_byte + 1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // fungsi bantu: 7-segment -> angka heksa (kebalikan dekoder di RTL)
    // ------------------------------------------------------------------------
    function [4:0] segmen_ke_heksa;     // bit 4 = 1 artinya pola tidak dikenal
        input [7:0] s;
        begin
            case (s)
                8'h3F: segmen_ke_heksa = 5'h0;  8'h06: segmen_ke_heksa = 5'h1;
                8'h5B: segmen_ke_heksa = 5'h2;  8'h4F: segmen_ke_heksa = 5'h3;
                8'h66: segmen_ke_heksa = 5'h4;  8'h6D: segmen_ke_heksa = 5'h5;
                8'h7D: segmen_ke_heksa = 5'h6;  8'h07: segmen_ke_heksa = 5'h7;
                8'h7F: segmen_ke_heksa = 5'h8;  8'h6F: segmen_ke_heksa = 5'h9;
                8'h77: segmen_ke_heksa = 5'hA;  8'h7C: segmen_ke_heksa = 5'hB;
                8'h39: segmen_ke_heksa = 5'hC;  8'h5E: segmen_ke_heksa = 5'hD;
                8'h79: segmen_ke_heksa = 5'hE;  8'h71: segmen_ke_heksa = 5'hF;
                default: segmen_ke_heksa = 5'h10;
            endcase
        end
    endfunction

    // ------------------------------------------------------------------------
    // 3. pengecekan setiap refresh selesai (tm_cs naik setelah 17 byte)
    // ------------------------------------------------------------------------
    integer   jumlah_error   = 0;
    integer   jumlah_refresh = 0;
    reg [31:0] angka_layar;
    reg [7:0]  led_layar;
    reg [31:0] angka_sebelum = 0;
    reg [4:0]  h;
    real       waktu_refresh_lalu = 0;
    real       periode_refresh = 0;

    always @(posedge tm_cs) begin
        if (urutan_byte == 17) begin
            angka_layar = 0;
            for (i = 0; i < 8; i = i + 1) begin
                h = segmen_ke_heksa(tampilan[2*i]);
                if (h[4]) begin
                    $display("FAIL: digit %0d berisi pola segmen aneh %h", i, tampilan[2*i]);
                    jumlah_error = jumlah_error + 1;
                end
                angka_layar = {angka_layar[27:0], h[3:0]};
                led_layar[7-i] = tampilan[2*i+1][0];
            end

            jumlah_refresh = jumlah_refresh + 1;
            if (jumlah_refresh > 1) periode_refresh = $realtime - waktu_refresh_lalu;
            waktu_refresh_lalu = $realtime;

            $display("refresh %0d  t=%0.1f us  layar=%h  LED=%b", jumlah_refresh, $realtime/1000.0, angka_layar, led_layar);
            if (led_layar !== angka_layar[24:17]) begin $display("FAIL LED"); jumlah_error = jumlah_error + 1; end

            // c. counter naik dan kelipatan 3
            if (jumlah_refresh > 1 && angka_layar <= angka_sebelum) begin
                $display("FAIL: angka tidak bertambah (%h -> %h)", angka_sebelum, angka_layar);
                jumlah_error = jumlah_error + 1;
            end
            if (angka_layar % 3 != 0) begin
                $display("FAIL: angka %h bukan kelipatan 3", angka_layar);
                jumlah_error = jumlah_error + 1;
            end
            angka_sebelum = angka_layar;
        end
    end

    // ------------------------------------------------------------------------
    // jalannya simulasi
    // ------------------------------------------------------------------------
    initial begin
        $dumpfile("top_soc_picorv32_gate_tb.vcd");
        $dumpvars(1, top_soc_picorv32_gate_tb);

        // tunggu 6 refresh (sekitar 1 ms)
        wait (jumlah_refresh == 6);
        #1000;

        $display("");
        $display("---------------- ringkasan ----------------");
        $display("periode refresh   = %0.1f us", periode_refresh / 1000.0);
        $display("display nyala     = %0d", display_nyala);

        if (display_nyala !== 1'b1) begin
            $display("FAIL: perintah display nyala (0x8F) tidak pernah diterima");
            jumlah_error = jumlah_error + 1;
        end

        if (jumlah_error == 0) $display("PASS: semua pengecekan benar (%0d refresh)", jumlah_refresh);
        else                   $display("FAIL: %0d error", jumlah_error);
        $finish;
    end

    // pengaman: kalau macet, berhenti setelah 2 ms
    initial begin
        #2_000_000;
        $display("FAIL: waktu habis, display tidak pernah di-refresh");
        $finish;
    end

endmodule
