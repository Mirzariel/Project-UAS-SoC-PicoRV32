module axi4_lite_rom #(
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = 32,
    // diubah: 4096 -> 1024 word (4 KB). 4096 word butuh 32 blok BRAM,
    // padahal iCE40UP5K hanya punya 30. Program dosen cuma 6 instruksi.
    parameter integer MEM_DEPTH = 1024,
    // diubah: firmware.hex berisi 1 BYTE per baris, sedangkan mem lebarnya
    // 32 bit. Jadi dipakai hasil konversi (1 WORD per baris), dibuat oleh
    // tools/konversi_hex.py. Path dihitung dari folder
    // build/build_soc_picorv32 (tempat yosys dan vvp dijalankan).
    parameter INIT_FILE = "../../rtl/soc_picorv32/peripherals/firmware_word.hex"
    )
(
    input         clk,
    input         rst_n,

    /* AXI4-Lite Interface (Read-Only) */

    // Channel Read Address
    input  [31:0] axi_araddr,
    input         axi_arvalid,
    output        axi_arready,
    
    // Channel Read Data
    output [31:0] axi_rdata,
    output        axi_rvalid,
    input         axi_rready    
);

    // ===============================
    // ROM memory (4 KB)
    // ===============================
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // ===============================
    // ROM initialization
    // Initialize memory from the .hex file
    // ===============================
    // initial begin
    //     $readmemh("demo_led_berkedip_xcelium_v2.hex", mem);
    // end


    integer i;
    initial begin
        // diubah: baris "for (i=0; i<MEM_DEPTH; i=i+1) mem[i] = 0;" dihapus.
        // Di iverilog tidak masalah, tetapi di yosys loop ini menimpa hasil
        // $readmemh, sehingga ROM di bitstream berisi 0 semua (ketahuan dari
        // netlist: INIT blok BRAM ROM = 0, dan simulasi gate-level tidak
        // pernah menampilkan angka). File hex sudah berisi 1024 baris penuh,
        // jadi loop ini memang tidak diperlukan.
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    

    // ===============================
    // AXI Read logic
    // ===============================

    reg [31:0] rdata_r;              // registered read data -> infer BRAM
    reg        read_en;

    always @(posedge clk) begin
        if (!rst_n) begin
            read_en <= 1'b0;
        end
        else if (axi_arvalid && axi_arready) begin
            rdata_r <= mem[axi_araddr[11:2]]; // diubah: [13:2] -> [11:2], 10 bit = 1024 word
            read_en <= 1'b1;
        end
        else if (axi_rvalid && axi_rready) begin
            read_en <= 1'b0;
        end
    end

    assign axi_arready = ~read_en;
    assign axi_rvalid  = read_en;
    assign axi_rdata   = rdata_r;

endmodule
