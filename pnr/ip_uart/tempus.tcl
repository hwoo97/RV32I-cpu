#####################################################################
# UART IP sign-off STA and ECO in Tempus - lab style (same sections as the lab tempus.tcl)
#  Run in this folder after all.tcl (it saves RouteDesign_for_ECO with analysis mode single):
#    tempus            then paste one Practice at a time (Practice 0 is active, 1 and 2 are commented)
#  Practice 0 : STA of the real design -> coverage report (violations 0 means no ECO is needed)
#  Practice 1 : ECO demo. The real design has no violation, so the hold uncertainty is raised in
#               this Tempus session only, repeaters are added on the failing nets and the change is
#               written to innovus.eco (applied in Innovus by eco.tcl)
#  Practice 2 : STA of the design after the ECO (ChipFinish_after_ECO from eco.tcl), SDF out
#####################################################################

## Practice 0.
################
### SET UP #####
################
read_design RouteDesign_for_ECO.dat uart_top

check_timing                  ;# warnings are skipped
report_annotated_parasitics   ;# real nets (complete) should be 100 %
report_analysis_coverage      ;# violated checks should be 0

# DataCheckSetup and DataCheckHold :: constants are skipped
report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const

# Worst setup / hold path of the real design (portfolio)
file mkdir tempus_reports
report_timing -late  -max_paths 1 > tempus_reports/real_setup.rpt
report_timing -early -max_paths 1 > tempus_reports/real_hold.rpt
exit

## Practice 1.
################
### SET UP #####
################
#read_design RouteDesign_for_ECO.dat uart_top

##############################
### BELOW is ECO #############
### From FIX HOLD to CHECK ###
##############################
# Demo condition only (not in the SDC): hold uncertainty 0.05 -> 0.07 ns makes the paths with
# less than 0.02 ns hold slack fail. Aim for a few failing paths: if there are too many, use a
# smaller value (0.06); if there are none, use a larger one (0.08).
#set_interactive_constraint_modes [all_constraint_modes -active]
#set_clock_uncertainty -hold 0.07 [get_clocks PCLK]
#report_analysis_coverage
#file mkdir tempus_reports
#report_timing -early -max_paths 10 > tempus_reports/demo_hold_before.rpt

#######################
### ECO 0: FIX HOLD ###
#######################
# GUI way (lab): Timing SI -> Debug Timing -> Browse -> Generate (Check Type Hold)
# Select a path -> right click -> Show Timing Path Analyzer
# Interactive ECO/WhatIf -> Add Repeater -> Evaluation Type Early -> New Cells BUFX2 -> Apply
# Command way: one repeater on the last net before each failing end point, e.g.
#add_repeater -cell BUFX2 -net <net name from demo_hold_before.rpt>

#######################
#### ECO 1 : CHECK ####
#######################
#report_analysis_coverage                ;# violated checks should be 0 again
#report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const
#report_timing -early -max_paths 10 > tempus_reports/demo_hold_after.rpt

#write_eco -format innovus -output innovus.eco   ;# last action of the ECO

## Practice 2.
################
### SET UP #####
################
#read_design ChipFinish_after_ECO.dat uart_top

#check_timing
#report_annotated_parasitics
#report_analysis_coverage

#report_analysis_coverage -check_type data_setup -verbose untested -exclude_untested const

##################
#### FILE OUT ####
##################
# Demo design after the ECO: other names, the real outputs of all.tcl stay as they are
#write_sdf -view FUNC_SS_WORST uart_top_eco_slow.sdf
#write_sdf -view FUNC_FF_BEST  uart_top_eco_fast.sdf
