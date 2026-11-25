###############
#### ECO ######
###############
# UART IP - apply the Tempus ECO in Innovus (lab 6_ECO.tcl form, design names changed)
#  Run in this folder after tempus.tcl Practice 1 wrote innovus.eco:
#    innovus      then  source eco.tcl   (or paste the sections one by one)
#  This is the ECO demo: the real design needs no ECO. Outputs get "_eco" names so the real
#  all.tcl outputs (uart_top_pnr.v, uart_top_slow.sdf, ...) are not overwritten.

restoreDesign RouteDesign_for_ECO.dat uart_top

## Cell count before / after the ECO (portfolio) -> reports/cell_count_eco.txt
proc count_cells_eco {tag} {
  file mkdir reports
  set n_all [llength [dbGet top.insts]]
  set n_buf [llength [dbGet -e -p2 top.insts.cell.name BUF*]]
  set n_dly [llength [dbGet -e -p2 top.insts.cell.name DLY*]]
  set n_eco [llength [dbGet -e top.insts.name *FE_ECO*]]
  set f [open reports/cell_count_eco.txt a]
  puts $f [format "%-16s insts %5d  BUF %4d  DLY %4d  FE_ECO %3d" $tag $n_all $n_buf $n_dly $n_eco]
  close $f
  puts [format "CELLCOUNT %-16s insts %5d  BUF %4d  DLY %4d  FE_ECO %3d" $tag $n_all $n_buf $n_dly $n_eco]
}
count_cells_eco before_eco

source innovus.eco
count_cells_eco after_eco_file

# After inserting repeat cells,
# Ctrl+F and Turn on Auto Zoom
# and Press the find button with using the word "*FE_ECO*"

# ECO routing and Optimize Design
setAnalysisMode -analysisType single -checkType setup ; # After change to single mode
optDesign -postRoute -setup; # 0 : Optimization and resolve the Setup Violation

setAnalysisMode -analysisType single -checkType hold
optDesign -postRoute -hold; # 1 : Optimization and resolve the Hold Violation
count_cells_eco after_eco_opt

# RC Extraction
extractRC

# Timing Check after ECO routing and Optimization
timeDesign -postRoute -outDir reports/timing/eco_setup	; # Setup time report
timeDesign -postRoute -hold -outDir reports/timing/eco_hold; # Hold time report

# DRC again
set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false -use_min_spacing_on_block_obs auto -report uart_top_eco.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}

# Below line is useful and temporaily when you want auto DRC fix
#setAnalysisMode -analysisType onChipVariation
#optDesign -postRoute -drv ; # auto DRC Fix

# LVS : Connectivity
verifyConnectivity -type all -geomConnect -error 1000 -warning 50

# Violation Browser
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer

######################################################################
# Save Design for tempus : It is useful to read design easily in Tempus
######################################################################
saveDesign -rc -def RouteDesign_ECO_mmmc1

#######################
#### Chip Finish ######
#######################
#restoreDesign RouteDesign_ECO_mmmc1.dat uart_top

# Add Filler
getFillerMode -quiet
addFiller -cell FILL1 FILL8 FILL64 FILL4 FILL32 FILL2 FILL16 -prefix FILLER
checkPlace uart_top_eco.checkPlace
extractRC
# If there is no error, save Design
saveDesign -rc -def ChipFinish_after_ECO

#####################
#### Write Out ######
#####################
# Hierarchical netlist (matches the hierarchical SDF, see all.tcl) - demo design, "_eco" names
saveNetlist uart_top_pnr_eco.v
writeTimingCon uart_top_pnr_eco.sdc
# SDF: the lab recommends the SDF from Tempus (tempus.tcl Practice 2)

#exit
