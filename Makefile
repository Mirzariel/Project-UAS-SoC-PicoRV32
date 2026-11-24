# ============================================================================
# Makefile Project UAS SoC PicoRV32 (dasar: Makefile template dosen)
#
# Jalankan dulu setenv-oss.bat (di cmd), lalu dari folder ini:
#   make hex   : ubah firmware.hex (1 byte/baris) menjadi 1 word/baris
#   make syn   : sintesis RTL -> netlist dengan Yosys
#   make sim   : simulasi dengan iVerilog (hasil PASS/FAIL)
#   make simgate : simulasi netlist hasil yosys (jalankan make syn dulu)
#   make pnr   : place & route dengan nextpnr-ice40
#   make bit   : buat bitstream (.bin) dengan icepack
#   make prog  : flash bitstream ke iCESugar dengan icesprog
#   make build : syn + pnr + bit
#   make clean / make cleanall
#
# Pin TM1638:
#   (biasa)          pin terbukti di board   STB=48 CLK=3 DIO=2
#   PIN=dosen        pin dari dosen          STB=9  CLK=4 DIO=2
#   contoh: make build PIN=dosen   lalu   make prog PIN=dosen
# ============================================================================

# diubah: perintah di bawah memakai sintaks cmd.exe (if not exist, rmdir /S /Q),
# jadi shell dikunci ke cmd.exe supaya tidak terpakai sh dari Git/OSS CAD Suite
SHELL = cmd.exe

export PROJECT_NAME = soc_picorv32
export TOP_LEVEL_PROJECT = top_$(PROJECT_NAME)
export DIR_BUILD = build
export DIR_BUILD_PROJECT = $(DIR_BUILD)_$(PROJECT_NAME)

export DIR_SIM = ../../sim
export DIR_RTL = ../../rtl
export DIR_TCL = ../../tcl
export DIR_TB = ../../tb
export DIR_CONS = ../../cons
export DIR_XDC = $(DIR_CONS)/xdc
export DIR_PCF = $(DIR_CONS)/pcf
# diubah: "bitsream" -> "bitstream" (salah ketik)
export DIR_BITSTREAM = bitstream

export BOARD = icesugarv15

# diubah: TOP_LEVEL dan PCF_FILENAME dipakai di pnr/bit/prog tetapi
# di template belum didefinisikan
TOP_LEVEL = $(TOP_LEVEL_PROJECT)
PIN ?= biasa
ifeq ($(PIN),dosen)
PCF_FILENAME = $(TOP_LEVEL_PROJECT)_$(BOARD)_pindosen.pcf
BITSTREAM_FILENAME = $(TOP_LEVEL_PROJECT)_pindosen.bin
else
PCF_FILENAME = $(TOP_LEVEL_PROJECT)_$(BOARD).pcf
# diubah: .bit -> .bin, icesprog dan drag-and-drop iCELink memakai file .bin
BITSTREAM_FILENAME = $(TOP_LEVEL_PROJECT).bin
endif

# diubah: daftar file untuk simulasi (make sim). Simulasi dijalankan dari
# folder sim/soc_picorv32 supaya path firmware di axi4_lite_rom.v
# (../../rtl/...) sama dengan saat yosys jalan di build/build_soc_picorv32.
TB_TOP  = $(TOP_LEVEL_PROJECT)_tb
SIM_SRC = $(wildcard rtl/$(PROJECT_NAME)/interfaces/*.sv) \
          $(wildcard rtl/$(PROJECT_NAME)/interconnect/*.v) \
          $(wildcard rtl/$(PROJECT_NAME)/peripherals/*.v) \
          $(wildcard rtl/$(PROJECT_NAME)/picorv32/*.v) \
          $(wildcard rtl/$(PROJECT_NAME)/wrapper/*.sv) \
          $(wildcard rtl/$(PROJECT_NAME)/*.sv) \
          $(wildcard tb/$(PROJECT_NAME)/*.v)

.PHONY: build all hex syn sim simgate pnr bit prog clean cleanall

build: syn pnr bit

all: build

hex:
	python tools/konversi_hex.py

syn:
	if not exist $(DIR_BUILD) mkdir $(DIR_BUILD)
	cd $(DIR_BUILD) && if not exist $(DIR_BUILD_PROJECT) mkdir $(DIR_BUILD_PROJECT)
	@echo Synthesized using Yosys
	cd $(DIR_BUILD) && \
	cd $(DIR_BUILD_PROJECT) && \
	yosys -l yosys.log -p "tcl $(DIR_TCL)/$(PROJECT_NAME)/$(TOP_LEVEL_PROJECT).tcl"

sim:
	if not exist sim mkdir sim
	cd sim && if not exist $(PROJECT_NAME) mkdir $(PROJECT_NAME)
	cd sim && \
	cd $(PROJECT_NAME) && \
	iverilog -g2012 -o $(TOP_LEVEL)_sim -s $(TB_TOP) $(addprefix ../../,$(SIM_SRC)) && \
	vvp -n $(TOP_LEVEL)_sim

# simulasi gate-level: netlist hasil "make syn" + model sel iCE40 dari yosys.
# Ditambahkan karena simulasi RTL sudah PASS, tetapi ternyata ROM di netlist
# kosong (lihat komentar di axi4_lite_rom.v). Pengecekan ini menangkapnya.
GATE_TB   = ../../tb/$(PROJECT_NAME)/gate/$(TOP_LEVEL_PROJECT)_gate_tb.v
CELLS_SIM = $(YOSYSHQ_ROOT)share/yosys/ice40/cells_sim.v $(YOSYSHQ_ROOT)share/yosys/simcells.v

simgate:
	if not exist sim mkdir sim
	cd sim && if not exist $(PROJECT_NAME) mkdir $(PROJECT_NAME)
	cd sim && \
	cd $(PROJECT_NAME) && \
	iverilog -g2012 -o $(TOP_LEVEL)_gate_sim -s $(TOP_LEVEL_PROJECT)_gate_tb $(GATE_TB) ../../$(DIR_BUILD)/$(DIR_BUILD_PROJECT)/$(TOP_LEVEL)_netlist.v $(CELLS_SIM) && \
	vvp -n $(TOP_LEVEL)_gate_sim

pnr:
	cd $(DIR_BUILD) && \
	cd $(DIR_BUILD_PROJECT) && \
	nextpnr-ice40 \
		--up5k \
		--package sg48 \
		--freq 12 \
		--json $(TOP_LEVEL)_netlist.json \
		--pcf $(DIR_PCF)/$(PCF_FILENAME) \
		--asc $(TOP_LEVEL).asc \
		--log nextpnr.log

bit:
	cd $(DIR_BUILD) && \
	cd $(DIR_BUILD_PROJECT) && \
	if not exist $(DIR_BITSTREAM) mkdir $(DIR_BITSTREAM)
	cd $(DIR_BUILD) && \
	cd $(DIR_BUILD_PROJECT) && \
	icepack $(TOP_LEVEL).asc $(DIR_BITSTREAM)/$(BITSTREAM_FILENAME)

# diubah: path disamakan dengan lokasi file hasil make bit
prog:
	icesprog $(DIR_BUILD)/$(DIR_BUILD_PROJECT)/$(DIR_BITSTREAM)/$(BITSTREAM_FILENAME)

clean:
	@echo deleting build_soc_picorv32
	cd $(DIR_BUILD) && \
	if exist $(DIR_BUILD_PROJECT) rmdir $(DIR_BUILD_PROJECT) /S /Q

cleanall:
	@echo deleting all build directories
	if exist $(DIR_BUILD) rmdir $(DIR_BUILD) /S /Q
	if exist sim\$(PROJECT_NAME) rmdir sim\$(PROJECT_NAME) /S /Q
