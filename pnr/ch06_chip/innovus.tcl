#####################################################################
# Innovus place and route of the ch6 single-cycle MCU chip (rv32i_chip: rv32i_mcu + IO pads) - gpdk045
#  Flow of the earlier project (all.tcl): init -> floorplan / pads -> power -> place -> CTS -> route
#  -> finish -> write out. Every STEP ends with saveDesign (restart from any step with restoreDesign).
#
# Ways to run (same script; see README.md):
#   bash pnr/ch06_chip/run_pnr.sh [target ns]          batch, no window, quits at the end
#   bash pnr/ch06_chip/run_pnr.sh --gui [target ns]    GUI window, the whole flow runs in it, stays open
#   bash pnr/ch06_chip/run_pnr.sh -i [--gui] [target]  prompt (+ GUI): step 0 ... step 8 yourself
#   restart from a saved step (in runs/<dir>):  restoreDesign dbs/<NN_name>.dat rv32i_chip ; then step <n+1>
#
#  - Input: the chip netlist of syn/ch06_chip for the same target (runs/t<target>ns/mapped), or NETLIST
#  - Constraints: syn/ch06_chip/cons/rv32i_chip.sdc with CLK_PERIOD = TARGET_PERIOD (no synthesis margin),
#    flattened to ./pnr.sdc for the MMMC file (pnr/common/flatten_sdc.tcl)
#  - Corners: setup slow, hold fast (mmmc.tcl). Library paths from GPDK045_DIR
#  - Outputs (runs/, not committed): dbs/, report/, out/ (netlist, SDF, SDC, DEF, GDS)
#####################################################################

####################################################################
## STEP 0. Paths and variables
####################################################################

if {[info exists ::env(PNR_DIR)]} {
    set PNR_DIR $::env(PNR_DIR)
} elseif {[info script] ne ""} {
    set PNR_DIR [file dirname [file normalize [info script]]]
} else {
    set PNR_DIR [file normalize [pwd]/../..]
}
set ROOT [file normalize $PNR_DIR/../..]
if {![info exists ::env(GPDK045_DIR)]} {
    error "environment variable GPDK045_DIR is not set (csh: setenv GPDK045_DIR <GPDK045 folder>)"
}
if {![info exists TARGET_PERIOD]} {
    set TARGET_PERIOD [expr {[info exists ::env(TARGET_PERIOD)] ? $::env(TARGET_PERIOD) : 12}]
}
set TOP_DESIGN rv32i_chip
if {![info exists NETLIST]} {
    set NETLIST [expr {[info exists ::env(NETLIST)] ? $::env(NETLIST) :
                       "$ROOT/syn/ch06_chip/runs/t${TARGET_PERIOD}ns/mapped/${TOP_DESIGN}_syn_final.v"}]
}
if {![file exists $NETLIST]} {
    error "netlist not found: $NETLIST (run bash syn/ch06_chip/run_syn.sh $TARGET_PERIOD first, or set NETLIST)"
}

# Floorplan: pad-limited chip (03_chapters/ch06_exception/chip.md sec. 3)
#  die DIE x DIE um; core box CORE_MARGIN um inside the die edge (240 um pads + room for the power rings)
set DIE         3700
set CORE_MARGIN 380

set G       $::env(GPDK045_DIR)/digital
set LEF_FILES [list \
    $G/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef \
    $G/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef \
    $G/giolib045_v3.5/lef/giolib045_modify.lef]

foreach d {log report dbs out} { file mkdir $d }

# plain SDC for the MMMC constraint mode (period = target, no synthesis margin)
source $ROOT/pnr/common/flatten_sdc.tcl
flatten_sdc $ROOT/syn/ch06_chip/cons/rv32i_chip.sdc ./pnr.sdc CLK_PERIOD $TARGET_PERIOD

puts "TOP = $TOP_DESIGN, target period = $TARGET_PERIOD ns, die = $DIE um, netlist = $NETLIST"

####################################################################
## STEP 1. Init design (netlist, LEF, MMMC, IO file)
####################################################################

set init_verilog    $NETLIST
set init_top_cell   $TOP_DESIGN
set init_lef_file   $LEF_FILES
set init_mmmc_file  $PNR_DIR/mmmc.tcl
set init_io_file    $PNR_DIR/rv32i_chip.io
set init_pwr_net    VDD
set init_gnd_net    VSS
init_design

checkDesign -io -netlist -physicalLibrary -powerGround -tieHilo -timingLibrary -outdir report/checkDesign
report_analysis_views
saveDesign dbs/01_init

####################################################################
## STEP 2. Floorplan, IO pads, IO fillers
####################################################################

# die size and core box; the pads go around the core in the order of rv32i_chip.io
floorPlan -site CoreSite -d $DIE $DIE $CORE_MARGIN $CORE_MARGIN $CORE_MARGIN $CORE_MARGIN
# fill the gaps between pads so the IO ring is continuous
foreach side {n s w e} {
    addIoFiller -cell {padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1} \
        -prefix FILLER -side $side
}
timeDesign -prePlace -outDir report/timing/prePlace
saveDesign dbs/02_floorplan

####################################################################
## STEP 3. Power plan (ring, rails, stripes, pad connection)
####################################################################

globalNetConnect VDD -type pgpin -pin VDD -instanceBasename *
globalNetConnect VSS -type pgpin -pin VSS -instanceBasename *
globalNetConnect VDD -type tiehi -instanceBasename *
globalNetConnect VSS -type tielo -instanceBasename *
setTieHiLoMode -reset
setTieHiLoMode -cell {TIELO TIEHI} -honorDontTouch false -createHierPort false

# core ring around the core box
setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 \
    -skip_crossing_trunks none -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 \
    -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {standardcell} \
    -skip_via_on_wire_shape {noshape}
addRing -nets {VDD VSS} -type core_rings -follow core \
    -layer {top Metal11 bottom Metal11 left Metal10 right Metal10} \
    -width {top 5 bottom 5 left 5 right 5} -spacing {top 5 bottom 5 left 5 right 5} \
    -offset {top 5 bottom 5 left 5 right 5} -center 0 -threshold 0 -jog_distance 0 \
    -snap_wire_center_to_grid None

# connect the core power pads (PADVDD / PADVSS) to the ring
setSrouteMode -viaConnectToShape {noshape}
sroute -connect {padPin} -layerChangeRange {Metal1(1) Metal11(11)} -blockPinTarget {nearestTarget} \
    -padPinPortConnect {allPort oneGeom} -padPinTarget {nearestTarget} -allowJogging 1 \
    -crossoverViaLayerRange {Metal1(1) Metal11(11)} -nets {VDD VSS} -allowLayerChange 1 \
    -targetViaLayerRange {Metal1(1) Metal11(11)}

# standard cell power rails
sroute -connect {corePin} -layerChangeRange {Metal1(1) Metal11(11)} -blockPinTarget {nearestTarget} \
    -corePinTarget {firstAfterRowEnd} -allowJogging 1 -crossoverViaLayerRange {Metal1(1) Metal11(11)} \
    -nets {VDD VSS} -allowLayerChange 1 -targetViaLayerRange {Metal1(1) Metal11(11)}

# vertical and horizontal stripes over the core
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false \
    -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false \
    -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none \
    -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width \
    -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size false \
    -split_vias false -orthogonal_only true -allow_jog {padcore_ring block_ring} \
    -skip_via_on_pin {standardcell} -skip_via_on_wire_shape {noshape}
addStripe -nets {VDD VSS} -layer Metal10 -direction vertical -width 5 -spacing 5 \
    -set_to_set_distance 100 -start_from left -start_offset 50 -stop_offset 0 \
    -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal11 \
    -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 \
    -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None
addStripe -nets {VDD VSS} -layer Metal11 -direction horizontal -width 5 -spacing 5 \
    -set_to_set_distance 100 -start_from bottom -start_offset 50 -stop_offset 0 \
    -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal11 \
    -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 \
    -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None

set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true \
    -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false \
    -use_min_spacing_on_block_obs auto -report report/03_power.drc.rpt -limit 1000
verify_drc
verifyConnectivity -type all -noOpen -noAntenna -noWeakConnect -noUnConnPin -noUnroutedNet \
    -error 1000 -warning 50 -report report/03_power.conn.rpt
saveDesign dbs/03_power

####################################################################
## STEP 4. Placement and optimization
####################################################################

set_db place_global_cong_effort high
place_design
checkPlace report/04_checkPlace.rpt
place_opt_design
earlyGlobalRoute
reportCongestion -hotSpot  > report/04_congestion.rpt
reportCongestion -overflow >> report/04_congestion.rpt
timeDesign -preCTS -outDir report/timing/preCTS
saveDesign dbs/04_place

####################################################################
## STEP 5. Clock tree synthesis and optimization
####################################################################

set_ccopt_property target_skew 0.05
create_ccopt_clock_tree_spec
ccopt_design
set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [all_clocks]
report_ccopt_clock_trees  -file report/05_clock_trees.rpt
report_ccopt_skew_groups  -file report/05_skew_groups.rpt
optDesign -postCTS
optDesign -postCTS -hold
timeDesign -postCTS       -outDir report/timing/postCTS
timeDesign -postCTS -hold -outDir report/timing/postCTS_hold
saveDesign dbs/05_cts

####################################################################
## STEP 6. Routing and post-route optimization
####################################################################

setNanoRouteMode -quiet -drouteFixAntenna 1
setNanoRouteMode -quiet -routeInsertAntennaDiode 0
setNanoRouteMode -quiet -routeWithTimingDriven 1
setNanoRouteMode -quiet -routeWithSiDriven 1
setNanoRouteMode -quiet -routeTopRoutingLayer 11
setNanoRouteMode -quiet -routeBottomRoutingLayer 1
setNanoRouteMode -quiet -drouteEndIteration 5
routeDesign -globalDetail

setAnalysisMode -analysisType onChipVariation
setDelayCalMode -SIAware false
optDesign -postRoute -drv
optDesign -postRoute
optDesign -postRoute -hold
timeDesign -postRoute       -outDir report/timing/postRoute
timeDesign -postRoute -hold -outDir report/timing/postRoute_hold
saveDesign dbs/06_route

####################################################################
## STEP 7. Chip finish (fillers) and sign-off checks
####################################################################

addFiller -cell {FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1} -prefix FILLER
set_verify_drc_mode -report report/07_finish.drc.rpt -limit 1000
verify_drc
verifyConnectivity -type all -geomConnect -error 1000 -warning 50 -report report/07_finish.conn.rpt
extractRC
timeDesign -postRoute       -outDir report/timing/final
timeDesign -postRoute -hold -outDir report/timing/final_hold
report_timing -max_paths 10 > report/07_timing_setup.rpt
summaryReport -noHtml -outfile report/07_summary.rpt
reportGateCount -level 0 -outfile report/07_gate_count.rpt
report_power -outfile report/07_power.rpt
saveDesign dbs/07_finish

####################################################################
## STEP 8. Write out (netlist for gate-level simulation and LEC, SDF, SDC, DEF, GDS)
####################################################################

# flat netlist without the power pads (they have no logical ports)
saveNetlist -flat -excludeCellInst {PADVDD PADVSS PADVDDIOR PADVSSIOR} out/${TOP_DESIGN}_pnr.v
# netlist with every physical cell (fillers, corners) for LVS-like checks
saveNetlist -flat -includePhysicalCell out/${TOP_DESIGN}_pnr_phys.v
write_sdf -view view_slow out/${TOP_DESIGN}_slow.sdf
write_sdf -view view_fast out/${TOP_DESIGN}_fast.sdf
writeTimingCon out/${TOP_DESIGN}_pnr.sdc
defOut -floorplan -netlist -routing out/${TOP_DESIGN}.def
# GDS without a layer map (as in the earlier project); cell layouts are referenced, not merged
streamOut out/${TOP_DESIGN}.gds -libName DesignLib -units 2000 -mode ALL

puts "============================"
puts "PnR Finished ..............."
puts "============================"
if {[info exists ::env(PNR_BATCH)] && $::env(PNR_BATCH)} {
    exit
} else {
    puts "Interactive: Innovus stays open (GUI: zoom, violation browser, timing debug)"
}
