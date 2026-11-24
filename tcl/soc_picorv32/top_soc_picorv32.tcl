# ============================================================================
# top_soc_picorv32.tcl : sintesis SoC PicoRV32 dengan Yosys (target iCE40)
#
# diubah: dasar file ini adalah tcl/soc_picorv32/build-yosys.tcl dari
# template dosen, diganti namanya menjadi top_soc_picorv32.tcl sesuai soal.
# Yang diubah ditandai dengan komentar "diubah".
#
# Dipanggil dari Makefile (make syn). Yosys dijalankan dari folder
# build/build_soc_picorv32, jadi semua path relatif terhadap folder itu.
# ============================================================================
yosys -import

set board_name $env(BOARD)
set project_name $env(PROJECT_NAME)
set top_level_project $env(TOP_LEVEL_PROJECT)
set dir_build $env(DIR_BUILD)
set dir_build_project $env(DIR_BUILD_PROJECT)
set dir_tcl $env(DIR_TCL)
set dir_rtl $env(DIR_RTL)
set dir_cons $env(DIR_CONS)
set dir_xdc $env(DIR_XDC)
set dir_pcf $env(DIR_PCF)

puts "project_name is: ${project_name}"
puts "top_level_project is: ${top_level_project}"
puts "dir_build is: ${dir_build}"
puts "dir_build_project is: ${dir_build_project}"
puts "dir_tcl is: ${dir_tcl}"
puts "dir_rtl is: ${dir_rtl}"
puts "dir_cons is: ${dir_cons}"


# set project
set top_level "${top_level_project}"

#Step 1: Reading RTL
read_verilog {*}[glob -directory "${dir_rtl}/${project_name}/interconnect"  *.v]
read_verilog -sv {*}[glob -directory "${dir_rtl}/${project_name}/interfaces"  *.sv]
read_verilog {*}[glob -directory "${dir_rtl}/${project_name}/peripherals"  *.v]
read_verilog {*}[glob -directory "${dir_rtl}/${project_name}/picorv32"  *.v]
read_verilog -sv {*}[glob -directory "${dir_rtl}/${project_name}/wrapper"  *.sv]
read_verilog -sv {*}[glob -directory "${dir_rtl}/${project_name}"  *.sv]

# 3. Design Elaborate & Check
# diubah: ditambah -check supaya modul yang belum ada langsung ketahuan
hierarchy -check -top ${top_level}
procs; # Executes Yosys RTL proc pass (aliased from 'proc')

# 4. Run synthesis targeting iCE40, specifying the top-level module
# diubah: file hasil ditulis di folder ini (build/build_soc_picorv32).
# Di template ditulis ke "${dir_build_project}/...", padahal yosys sudah
# berada di dalam folder itu, jadi path-nya menjadi
# build_soc_picorv32/build_soc_picorv32/... yang tidak ada.
synth_ice40 -top ${top_level} -json ${top_level}_netlist.json

#3. Optional: Write out intermediate netlists or reports
# 6. Print synthesis stats and save the gate-level netlist
# diubah: hasil stat juga disimpan ke file supaya mudah dibaca lagi
tee -o ${top_level}_stat.txt stat
write_verilog "${top_level}_netlist.v"
write_verilog -noattr "${top_level}_netlist_noattr.v"
