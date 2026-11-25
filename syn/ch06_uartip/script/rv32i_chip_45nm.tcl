#####################################################################
# RV32I MCU chip with the UART IP (rtl/ch06_uartip + rtl/ip_uart; rv32i_chip = rv32i_mcu + giolib045
# IO pads) synthesis - lab style
# (based on the lab Genus script cortexm0_45nm.tcl, only paths, names and numbers changed)
#  Batch      : ./run_synthesis                         (in syn/ch06_uartip)
#  Interactive: genus  ->  source ./script/rv32i_chip_45nm.tcl   (or paste the sections one by one)
#  Outputs    : ./log ./report ./unmapped ./mapped (not committed)
#  Changes from the lab script: design name and RTL list (the whole MCU is RTL, no pre-synthesized
#  sub-block), GPDK045 path in one variable, slow standard cells + slow (SS) pads only, the IO pad
#  cells are dont_touch, write_do_lec enabled.
#  Memories (IMEM, DMEM) are outside the chip and not synthesized (mcu_imem.v / mcu_dmem.v are
#  simulation models only). Same settings as the project flow syn/ch06_chip (chip without the UART IP).
#####################################################################

if {[file exists /proc/cpuinfo]} {
  sh grep "model name" /proc/cpuinfo
  sh grep "cpu MHz"    /proc/cpuinfo
}

puts "Hostname : [info hostname]"

######################################################################
# Preset global variables and attributes
######################################################################

set TOP_DESIGN  rv32i_chip

set LOG_DIR     "./log"
set RPT_DIR     "./report"
set UNMAPPED_DIR   "./unmapped"
set MAPPED_DIR     "./mapped"
file mkdir $LOG_DIR $RPT_DIR $UNMAPPED_DIR $MAPPED_DIR

#GPDK 045 SVT (the GPDK045 folder is at / on the school server; change this line if it moves)
set GPDK045 /GPDK045
set STD_LIB_PATH "$GPDK045/digital/gsclib045_all_v4.4/gsclib045/timing"
set IO_LIB_PATH  "$GPDK045/digital/giolib045_v3.5/timing"
set LEF_LIB_PATH "$GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef $GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/lef $GPDK045/digital/giolib045_v3.5/lef"
set RTL_PATH     "../../rtl/ch06_uartip"
set UART_PATH    "../../rtl/ip_uart"
set QRC_FILE_PATH "$GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/qrc/qx"

#GPDK 045 SVT - slow corner only (the lab list also read the fast library; with both slow and fast,
#               cells of the same name could take fast timing) + slow (SS) IO pads
#set LIB_LIST {fast_vdd1v0_basicCells.lib slow_vdd1v0_basicCells.lib pads_SS_s1vg.lib}
set LIB_LIST {slow_vdd1v0_basicCells.lib pads_SS_s1vg.lib}
# pad LEF: giolib045_modify.lef (PADVDD / PADVSS as AREAIO), the same file PnR reads
set LEF_LIST {gsclib045_tech.lef gsclib045_macro.lef giolib045_modify.lef}
set QRC_LIST {gpdk045.tch}

# mcu_imem.v, mcu_dmem.v, mcu_top.v are simulation / FPGA only and are not read
set RTL_SOURCES "$RTL_PATH/rv32i_core.v \
		$RTL_PATH/csr.v \
		$RTL_PATH/control.v \
		$RTL_PATH/regfile.v \
		$RTL_PATH/imm_gen.v \
		$RTL_PATH/alu.v \
		$RTL_PATH/branch_cmp.v \
		$RTL_PATH/lsu.v \
		$RTL_PATH/bus_mux.v \
		$RTL_PATH/apb_bridge.v \
		$RTL_PATH/apb_gpio.v \
		$RTL_PATH/apb_timer.v \
		$UART_PATH/uart_fifo.v \
		$UART_PATH/uart_baud.v \
		$UART_PATH/uart_tx.v \
		$UART_PATH/uart_rx.v \
		$UART_PATH/uart_regs.v \
		$UART_PATH/uart_top.v \
		$RTL_PATH/rv32i_mcu.v \
		$RTL_PATH/rv32i_chip.v \
"
set_db auto_ungroup none
set_db max_cpus_per_server 2

##Set synthesizing effort for each synthesis stage
set_db syn_generic_effort high; # Default medium
set_db syn_map_effort high;     # Default medium
set_db syn_opt_effort high;     # Default medium

set_db init_lib_search_path [concat $STD_LIB_PATH $IO_LIB_PATH $LEF_LIB_PATH $QRC_FILE_PATH]
set_db init_hdl_search_path [concat $RTL_PATH $UART_PATH]

read_libs ${LIB_LIST}
read_physical -lef ${LEF_LIST}
read_qrc ${QRC_LIST}

##generates <signal>_reg[<bit_width>] format
set_db hdl_array_naming_style %s_%d
set_db / .uniquify_naming_style ${TOP_DESIGN}_%s_%d

####################################################################
## Load Design
####################################################################

read_hdl $RTL_SOURCES

elaborate ${TOP_DESIGN}
puts "Runtime & Memory after 'read_hdl'"
time_info Elaboration

set_db optimize_merge_flops false
set_db optimize_merge_latches false

uniquify -verbose ${TOP_DESIGN}

check_design > ${RPT_DIR}/00_check_design.rpt
check_design -unresolved >> ${RPT_DIR}/00_check_design.rpt


####################################################################
## Constraints Setup
####################################################################

source -verbose  ./cons/rv32i_chip.sdc     ; #This command can't write report by using the mark '>'
source -verbose  ./cons/dont_use_45nm.tcl  ; #This command can't write report by using the mark '>'
# the IO pads are instantiated on purpose: never resize, remove or restructure them
set_dont_touch [get_cells -hierarchical PAD_*]
set_dont_touch [get_cells -hierarchical P_*]
puts "The number of exceptions is [llength [vfind "design:$TOP_DESIGN" -exception *]]"

check_timing_intent -verbose > ${RPT_DIR}/01_check_timing_intent.rpt

report_port -delay -driver [all_inputs] > ${RPT_DIR}/02_report_port.rpt
report_port -delay -load [all_outputs] >> ${RPT_DIR}/02_report_port.rpt

echo -n "\n TIMEX > compile is ready :            ";
sh date

####################################################################################################
## Synthesizing to generic
####################################################################################################

syn_generic ; #This command can't write report by using the mark '>'
puts "Runtime & Memory after 'syn_generic'"
time_info GENERIC
report_datapath > ${RPT_DIR}/03_report_datapath_generic.rpt

write_snapshot -outdir ${RPT_DIR} -tag syn_generic

write_db -to_file  ${UNMAPPED_DIR}/syn_generic.db

####################################################################################################
## Synthesizing to gates
####################################################################################################

syn_map ; #This command can't write report by using the mark '>'
puts "Runtime & Memory after 'syn_map'"
time_info MAPPED

report_datapath > ${RPT_DIR}/04_report_datapath_map.rpt

foreach cg [vfind / -cost_group *] {
  report timing -cost_group [list $cg] > ${RPT_DIR}/05_[basename $cg]_post_syn_map.rpt
  }

write_snapshot -outdir ${RPT_DIR} -tag syn_map

write_db -to_file ${MAPPED_DIR}/syn_map.db

#######################################################################################################
## Optimize Netlist + Incremental
#######################################################################################################

syn_opt ; #This command can't write report by using the mark '>'

report_constraint -all_violators > ${RPT_DIR}/06_report_constraint.rpt

write_snapshot -outdir ${RPT_DIR} -tag syn_opt

puts "Runtime & Memory after syn_opt"
time_info OPT

foreach cg [vfind / -cost_group *] {
  report timing -cost_group [list $cg] > ${RPT_DIR}/07_[basename $cg]_post_syn_opt.rpt
  }

write_db -to_file ${MAPPED_DIR}/syn_opt.db


echo -n "\n TIMEX > Compile is completed :            ";
sh date

######################################################################################################
## REPORTS
######################################################################################################

report_analysis_views -type all           > ${RPT_DIR}/08_${TOP_DESIGN}_SYN_analysis_view.rpt
report_area                               > ${RPT_DIR}/09_${TOP_DESIGN}_SYN_area.rpt
report_clocks                             > ${RPT_DIR}/10_${TOP_DESIGN}_SYN_clock.rpt
report_clocks -generated                 >> ${RPT_DIR}/10_${TOP_DESIGN}_SYN_clock.rpt
report_datapath                           > ${RPT_DIR}/11_${TOP_DESIGN}_SYN_datapath.rpt
report_design_rules                       > ${RPT_DIR}/12_${TOP_DESIGN}_SYN_design_rules.rpt
report_gates                              > ${RPT_DIR}/13_${TOP_DESIGN}_SYN_gate.rpt
report_gates -power                      >> ${RPT_DIR}/13_${TOP_DESIGN}_SYN_gate.rpt
report_hierarchy                          > ${RPT_DIR}/14_${TOP_DESIGN}_SYN_hier.rpt
report_memory_cells                       > ${RPT_DIR}/15_${TOP_DESIGN}_SYN_mem_cell.rpt
report_messages -all                      > ${RPT_DIR}/16_${TOP_DESIGN}_SYN_message.rpt
report_nets -hierarchical                 > ${RPT_DIR}/17_${TOP_DESIGN}_SYN_net.rpt
report_power                              > ${RPT_DIR}/18_${TOP_DESIGN}_SYN_pwr.rpt
report_qor                                > ${RPT_DIR}/19_${TOP_DESIGN}_SYN_qor.rpt
report_timing -nworst 100 -net            > ${RPT_DIR}/20_${TOP_DESIGN}_SYN_timing.rpt
report_summary


######################################################################################################
## write Innovus file set (verilog, SDC, config, etc.)
######################################################################################################

write_design -basename ${MAPPED_DIR}/${TOP_DESIGN}_mapped
write_hdl  > ${MAPPED_DIR}/${TOP_DESIGN}_syn_final.v
write_sdc  > ${MAPPED_DIR}/${TOP_DESIGN}_syn_final.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge  -setuphold split > ${MAPPED_DIR}/${TOP_DESIGN}_delays.sdf

#################################
### write_do_lec
#################################

write_do_lec -revised_design ${MAPPED_DIR}/${TOP_DESIGN}_syn_final.v -logfile ${LOG_DIR}/rtl_2_lec_final.log > ${MAPPED_DIR}/rtl_2_lec_final.do

echo -n "\n TIMEX > End :             " ;
sh date

puts "Final Runtime & Memory."
time_info FINAL
puts "============================"
puts "Synthesis Finished ........."
puts "============================"

#quit
