#####################################################################
# Genus synthesis of the ch05 single-cycle CPU core (rv32i_core) - gpdk045, slow corner
#  - Run: bash syn/ch05_single_cycle/run_syn.sh [clock period ns]   (default 10 ns)
#    run_syn.sh passes ROOT, SYN_DIR, CLK_PERIOD as environment variables and runs in runs/clk<period>ns/
#  - Memories (imem, dmem) are not synthesized. Their access time is modeled by SDC I/O delays
#  - Outputs (reports, netlist, logs) go under runs/ and are not committed (summary only in README)
#####################################################################

set ROOT       $::env(ROOT)
set SYN_DIR    $::env(SYN_DIR)
set CLK_PERIOD [expr {[info exists ::env(CLK_PERIOD)] ? $::env(CLK_PERIOD) : 10.0}]

set TOP_DESIGN rv32i_core
set RTL_DIR    $ROOT/rtl/ch05_single_cycle
set RTL_FILES  {rv32i_core.v control.v regfile.v imm_gen.v alu.v branch_cmp.v lsu.v}

set LOG_DIR      ./log
set RPT_DIR      ./report
set UNMAPPED_DIR ./unmapped
set MAPPED_DIR   ./mapped
foreach d [list $LOG_DIR $RPT_DIR $UNMAPPED_DIR $MAPPED_DIR] { file mkdir $d }

puts "Hostname : [info hostname]"
puts "TOP = $TOP_DESIGN, CLK_PERIOD = $CLK_PERIOD ns"

######################################################################
# Preset global variables and attributes
######################################################################

set_db auto_ungroup none              ;# keep module hierarchy -> per-module area is visible
set_db max_cpus_per_server 2

set_db syn_generic_effort high
set_db syn_map_effort     high
set_db syn_opt_effort     high

source $ROOT/syn/common/gpdk045.tcl   ;# read_libs (+ LEF, QRC)

set_db init_hdl_search_path $RTL_DIR  ;# `include "rv32i_defs.vh" is found here too
set_db hdl_array_naming_style %s_%d

####################################################################
## Load Design
####################################################################

read_hdl $RTL_FILES
elaborate $TOP_DESIGN
puts "Runtime & Memory after 'read_hdl'"
time_info Elaboration

check_design             > ${RPT_DIR}/00_check_design.rpt
check_design -unresolved >> ${RPT_DIR}/00_check_design.rpt

####################################################################
## Constraints Setup
####################################################################

source -verbose $SYN_DIR/cons/rv32i_core.sdc
puts "The number of exceptions is [llength [vfind "design:$TOP_DESIGN" -exception *]]"

check_timing_intent -verbose > ${RPT_DIR}/01_check_timing_intent.rpt
report_port -delay -driver [all_inputs] > ${RPT_DIR}/02_report_port.rpt
report_port -delay -load [all_outputs] >> ${RPT_DIR}/02_report_port.rpt

####################################################################
## Synthesizing to generic
####################################################################

syn_generic
puts "Runtime & Memory after 'syn_generic'"
time_info GENERIC
report_datapath > ${RPT_DIR}/03_report_datapath_generic.rpt
write_snapshot -outdir ${RPT_DIR} -tag syn_generic
write_db -to_file ${UNMAPPED_DIR}/syn_generic.db

####################################################################
## Synthesizing to gates
####################################################################

syn_map
puts "Runtime & Memory after 'syn_map'"
time_info MAPPED
report_datapath > ${RPT_DIR}/04_report_datapath_map.rpt
foreach cg [vfind / -cost_group *] {
    report_timing -cost_group [list $cg] > ${RPT_DIR}/05_[basename $cg]_post_syn_map.rpt
}
write_snapshot -outdir ${RPT_DIR} -tag syn_map
write_db -to_file ${MAPPED_DIR}/syn_map.db

####################################################################
## Optimize Netlist
####################################################################

syn_opt
report_constraint -all_violators > ${RPT_DIR}/06_report_constraint.rpt
write_snapshot -outdir ${RPT_DIR} -tag syn_opt
puts "Runtime & Memory after syn_opt"
time_info OPT
foreach cg [vfind / -cost_group *] {
    report_timing -cost_group [list $cg] > ${RPT_DIR}/07_[basename $cg]_post_syn_opt.rpt
}
write_db -to_file ${MAPPED_DIR}/syn_opt.db

####################################################################
## Reports
####################################################################

report_area                    > ${RPT_DIR}/09_${TOP_DESIGN}_area.rpt
report_clocks                  > ${RPT_DIR}/10_${TOP_DESIGN}_clock.rpt
report_datapath                > ${RPT_DIR}/11_${TOP_DESIGN}_datapath.rpt
report_design_rules            > ${RPT_DIR}/12_${TOP_DESIGN}_design_rules.rpt
report_gates                   > ${RPT_DIR}/13_${TOP_DESIGN}_gate.rpt
report_gates -power           >> ${RPT_DIR}/13_${TOP_DESIGN}_gate.rpt
report_hierarchy               > ${RPT_DIR}/14_${TOP_DESIGN}_hier.rpt
report_messages -all           > ${RPT_DIR}/16_${TOP_DESIGN}_message.rpt
report_power                   > ${RPT_DIR}/18_${TOP_DESIGN}_pwr.rpt
report_qor                     > ${RPT_DIR}/19_${TOP_DESIGN}_qor.rpt
report_timing -nworst 10 -net  > ${RPT_DIR}/20_${TOP_DESIGN}_timing.rpt
report_summary

####################################################################
## Write out (netlist, SDC, SDF, LEC do file)
####################################################################

write_design -basename ${MAPPED_DIR}/${TOP_DESIGN}_mapped
write_hdl > ${MAPPED_DIR}/${TOP_DESIGN}_syn_final.v
write_sdc > ${MAPPED_DIR}/${TOP_DESIGN}_syn_final.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split > ${MAPPED_DIR}/${TOP_DESIGN}_delays.sdf
# For LEC (professor's server): golden = RTL read in, revised = synthesized netlist
write_do_lec -revised_design ${MAPPED_DIR}/${TOP_DESIGN}_syn_final.v -logfile ${LOG_DIR}/rtl2gate_lec.log > ${MAPPED_DIR}/rtl2gate.do

puts "Final Runtime & Memory."
time_info FINAL
puts "============================"
puts "Synthesis Finished ........."
puts "============================"

quit
