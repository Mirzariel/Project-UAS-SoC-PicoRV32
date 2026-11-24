"""Konversi file hex dosen (1 byte per baris) menjadi hex 1 word per baris.

Kenapa perlu?
  File firmware.hex dari template berisi 4096 baris, tiap baris 1 byte.
  Memori ROM di axi4_lite_rom.v lebarnya 32-bit (reg [31:0] mem [...]).
  $readmemh mengisi SATU baris ke SATU alamat memori, jadi kalau file dosen
  dibaca langsung, tiap byte masuk ke word sendiri dan instruksinya rusak.

  RISC-V memakai urutan little-endian: byte pertama adalah bagian paling
  kanan (bit 7:0) dari word. Jadi 4 byte  b7 02 03 00  menjadi word 000302b7.

Cara pakai (dari folder uas-soc-design):
    python tools/konversi_hex.py
  atau
    make hex
"""
import os

FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                      "rtl", "soc_picorv32", "peripherals")
FILE_BYTE = os.path.join(FOLDER, "firmware.hex")
FILE_WORD = os.path.join(FOLDER, "firmware_word.hex")

NAMA_REG = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
            "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
            "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
            "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"]


def tanda(nilai, jumlah_bit):
    """Ubah bilangan tak bertanda menjadi bertanda (two's complement)."""
    if nilai & (1 << (jumlah_bit - 1)):
        nilai -= 1 << jumlah_bit
    return nilai


def bongkar(word, pc):
    """Disassembler kecil, hanya instruksi yang dipakai program ini."""
    opcode = word & 0x7F
    rd = NAMA_REG[(word >> 7) & 31]
    rs1 = NAMA_REG[(word >> 15) & 31]
    rs2 = NAMA_REG[(word >> 20) & 31]
    funct3 = (word >> 12) & 7
    if opcode == 0x37:
        return f"lui   {rd}, 0x{word >> 12:x}"
    if opcode == 0x13 and funct3 == 0:
        return f"addi  {rd}, {rs1}, {tanda(word >> 20, 12)}"
    if opcode == 0x23 and funct3 == 2:
        imm = ((word >> 25) << 5) | ((word >> 7) & 31)
        return f"sw    {rs2}, {tanda(imm, 12)}({rs1})"
    if opcode == 0x6F:
        imm = (((word >> 31) & 1) << 20) | (((word >> 12) & 0xFF) << 12) \
            | (((word >> 20) & 1) << 11) | (((word >> 21) & 0x3FF) << 1)
        return f"jal   {rd}, 0x{pc + tanda(imm, 21):x}"
    return "(instruksi lain)"


def main():
    # 1. baca semua byte
    byte = []
    with open(FILE_BYTE) as f:
        for baris in f:
            baris = baris.strip()
            if baris:
                byte.append(int(baris, 16))
    print("jumlah byte dibaca :", len(byte))
    if len(byte) % 4 != 0:
        raise SystemExit("jumlah byte bukan kelipatan 4")

    # 2. gabungkan tiap 4 byte menjadi 1 word (little-endian)
    word = []
    for i in range(0, len(byte), 4):
        w = byte[i] | (byte[i + 1] << 8) | (byte[i + 2] << 16) | (byte[i + 3] << 24)
        word.append(w)
    print("jumlah word ditulis:", len(word))

    # 3. tulis file baru, 1 word per baris (format $readmemh biasa)
    with open(FILE_WORD, "w", newline="\n") as f:
        for w in word:
            f.write(f"{w:08x}\n")

    # 4. tampilkan isi program supaya bisa dicek dengan mata
    print("\nisi program (word yang bukan nol):")
    for i, w in enumerate(word):
        if w != 0:
            print(f"  0x{i * 4:04x}: {w:08x}   {bongkar(w, i * 4)}")
    print("\nfile hasil:", os.path.normpath(FILE_WORD))


if __name__ == "__main__":
    main()
