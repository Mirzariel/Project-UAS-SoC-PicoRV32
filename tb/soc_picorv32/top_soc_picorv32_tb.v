`timescale 1ns / 1ps

// ============================================================================
// Testbench top_soc_picorv32
//
// Isi:
//   1. Clock 12 MHz seperti di board.
//   2. "Model TM1638": membaca pin tm_cs / tm_clk / tm_dio persis seperti
//      chip TM1638 asli, lalu menyimpan 16 byte isi display.
//   3. Pengecekan, setiap kali satu refresh display selesai:
//        a. 8 digit 7-segment, kalau dibaca sebagai angka heksa, harus sama
//           dengan angka yang ditulis CPU ke alamat 0x0003_0000
//        b. LED1..LED8 harus sama dengan bit 24..17 angka itu
//        c. angka harus terus bertambah dan selalu kelipatan 3
//           (program dosen: t1 = t1 + 3)
//      Tahap 2: register angka "dipaksa" (force) menjadi 0x12345678, lalu
//      layar harus menampilkan 12345678 dan LED harus 00011010.
//      Tahap ini perlu karena selama tahap 1 counter masih kecil, jadi
//      bit 24..17 (LED) selalu 0 dan salah sambung LED tidak akan ketahuan.
//   4. CPU tidak boleh mengakses alamat di luar ROM/RAM/GPIO/TM1638
//      (kalau terjadi, interconnect tidak menjawab dan CPU macet).
//
// Hasil akhir: tulisan PASS atau FAIL, ditambah beberapa angka ukuran.
// ============================================================================

module top_soc_picorv32_tb;

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

    // jalan pintas ke register di dalam modul TM1638
    `define TM dut.u_axi4_lite_tm1638_wrapper.u_axi4_lite_tm1638

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
    reg       dapat_40 = 1'b0;      // perintah 0x40 pernah diterima
    reg       dapat_C0 = 1'b0;      // perintah 0xC0 pernah diterima
    integer   i;

    initial for (i = 0; i < 16; i = i + 1) tampilan[i] = 8'h00;

    always @(negedge tm_cs) begin
        jumlah_bit  = 0;
        urutan_byte = 0;
    end

    always @(posedge tm_clk) begin
        if (tm_cs == 1'b0) begin
            geser = {tm_dio, geser[7:1]};       // LSB dulu
            jumlah_bit = jumlah_bit + 1;
            if (jumlah_bit == 8) begin
                jumlah_bit = 0;
                if (urutan_byte == 0) begin
                    // byte perintah
                    if (geser == 8'h40) dapat_40 = 1'b1;
                    if (geser == 8'hC0) dapat_C0 = 1'b1;
                    if (geser[7:6] == 2'b11) alamat = geser[3:0];   // 0xC0 + alamat
                    if (geser == 8'h8F) display_nyala = 1'b1;       // nyala, terang maks
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
    integer    tahap = 1;
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

            $display("refresh %0d  t=%0.1f us  layar=%h  LED=%b  (angka CPU saat itu=%h)",
                     jumlah_refresh, $realtime/1000.0, angka_layar, led_layar, `TM.angka);

            // a. 7-segment = angka yang difoto dari register ANGKA
            if (tahap == 1 && angka_layar !== `TM.angka_foto) begin
                $display("FAIL: layar %h tidak sama dengan angka %h", angka_layar, `TM.angka_foto);
                jumlah_error = jumlah_error + 1;
            end
            // b. LED = bit 24..17
            if (led_layar !== angka_layar[24:17]) begin
                $display("FAIL: LED %b tidak sama dengan bit 24..17 (%b)", led_layar, angka_layar[24:17]);
                jumlah_error = jumlah_error + 1;
            end
            // c. counter naik dan kelipatan 3
            if (tahap == 1 && jumlah_refresh > 1 && angka_layar <= angka_sebelum) begin
                $display("FAIL: angka tidak bertambah (%h -> %h)", angka_sebelum, angka_layar);
                jumlah_error = jumlah_error + 1;
            end
            if (tahap == 1 && angka_layar % 3 != 0) begin
                $display("FAIL: angka %h bukan kelipatan 3", angka_layar);
                jumlah_error = jumlah_error + 1;
            end
            angka_sebelum = angka_layar;
        end
    end

    // ------------------------------------------------------------------------
    // 4. CPU tidak boleh mengakses alamat di luar 4 daerah
    // ------------------------------------------------------------------------
    always @(posedge clock) begin
        if (dut.bus_picorv32.arvalid && dut.bus_picorv32.araddr > 32'h0003_FFFF) begin
            $display("FAIL: CPU membaca alamat liar %h", dut.bus_picorv32.araddr);
            jumlah_error = jumlah_error + 1;
        end
        if (dut.bus_picorv32.awvalid && dut.bus_picorv32.awaddr > 32'h0003_FFFF) begin
            $display("FAIL: CPU menulis alamat liar %h", dut.bus_picorv32.awaddr);
            jumlah_error = jumlah_error + 1;
        end
    end

    // ------------------------------------------------------------------------
    // ukuran: lama 1 putaran program dan frekuensi tm_clk
    // ------------------------------------------------------------------------
    integer jumlah_tulis = 0;
    real    waktu_tulis_1 = 0, waktu_tulis_2 = 0;
    always @(`TM.angka) begin
        jumlah_tulis = jumlah_tulis + 1;
        if (jumlah_tulis == 10) waktu_tulis_1 = $realtime;
        if (jumlah_tulis == 20) waktu_tulis_2 = $realtime;
    end

    // periode tm_clk = jarak terpendek antara dua tm_clk naik
    real waktu_clk_lalu = 0, periode_tm_clk = 1.0e9;
    always @(posedge tm_clk) begin
        if (waktu_clk_lalu > 0 && $realtime - waktu_clk_lalu < periode_tm_clk)
            periode_tm_clk = $realtime - waktu_clk_lalu;
        waktu_clk_lalu = $realtime;
    end

    // ------------------------------------------------------------------------
    // jalannya simulasi
    // ------------------------------------------------------------------------
    real putaran_clock;
    initial begin
        $dumpfile("top_soc_picorv32_tb.vcd");
        $dumpvars(1, top_soc_picorv32_tb);
        $dumpvars(1, `TM);

        // tahap 1: tunggu 6 refresh (sekitar 1 ms)
        wait (jumlah_refresh == 6);
        #1000;

        // tahap 2: paksa angka = 0x12345678, tunggu 2 refresh, lalu cek
        tahap = 2;
        force `TM.angka = 32'h1234_5678;
        wait (jumlah_refresh == 8);
        #1000;
        release `TM.angka;
        $display("tahap 2: layar=%h (harus 12345678), LED=%b (harus 00011010)", angka_layar, led_layar);
        if (angka_layar !== 32'h1234_5678) begin
            $display("FAIL: urutan digit salah");
            jumlah_error = jumlah_error + 1;
        end
        if (led_layar !== 8'b0001_1010) begin
            $display("FAIL: sambungan LED salah");
            jumlah_error = jumlah_error + 1;
        end

        putaran_clock = (waktu_tulis_2 - waktu_tulis_1) / 10.0 / 83.333;
        $display("");
        $display("---------------- ringkasan ----------------");
        $display("1 putaran program (sw, addi, jal) = %0.1f clock", putaran_clock);
        $display("counter naik      = %0.0f per detik", 3.0 * 12.0e6 / putaran_clock);
        $display("periode tm_clk    = %0.1f ns  (%0.2f MHz)", periode_tm_clk, 1000.0 / periode_tm_clk);
        $display("periode refresh   = %0.1f us", periode_refresh / 1000.0);
        $display("display nyala     = %0d", display_nyala);

        if (display_nyala !== 1'b1 || dapat_40 !== 1'b1 || dapat_C0 !== 1'b1) begin
            $display("FAIL: perintah 0x40 / 0xC0 / 0x8F tidak lengkap");
            jumlah_error = jumlah_error + 1;
        end

        if (jumlah_error == 0) $display("PASS: semua pengecekan benar (%0d refresh)", jumlah_refresh);
        else                   $display("FAIL: %0d error", jumlah_error);
        $finish;
    end

    // pengaman: kalau macet, berhenti setelah 20 ms
    initial begin
        #20_000_000;
        $display("FAIL: waktu habis, display tidak pernah di-refresh");
        $finish;
    end

endmodule
