#####################################################################
# RV32I MCU chip with the UART IP (rv32i_chip: rv32i_mcu + IO pads, rtl/ch06_uartip) - Innovus PnR,
# lab style: same sections and order as the lab all.tcl (InitDesign -> PowerPlan -> Placement ->
# CTS -> Route -> Power -> Chip Finish -> Write Out), run in this folder (pnr/ch06_uartip):
#    innovus      then  source all.tcl   (or paste the sections one by one and look at the GUI)
#  Every section ends with saveDesign; restart from one with  restoreDesign <name>.dat rv32i_chip
#
#  Additions to the lab script (fixes found in the project-style flow pnr/ch06_chip, see its README):
#   - double-height cells (SITE CoreSiteDouble) dont_use: no rows of that site (checkPlace TechSite 95)
#   - floorplan from the die size, small core (1400 um) in the middle: input pad nets met max_tran
#     only with the core closer to the pads; the core power pads are moved into the pad ring
#   - power plan: inner ring + core stripes, outer ring along the IO ring, pad wires, ring-to-ring
#     stripes, trim; a power check after every sub-step (reports/03_pgcheck.txt)
#   - CTS: strong clock cells, trunk Metal7-8, no IO latency update (the first CCOpt default run had
#     hold -1.134 ns on 2216 paths); virtual clock vclk latency = measured insertion delay per view
#  Additions for the portfolio (same as pnr/ip_uart/all.tcl):
#   - reports/cell_count.txt: instances / BUF / CLKBUF / DLY after each step (hold-fix buffers)
#   - timing right after NanoRoute (OCV, before any post-route optimization), hold before / after
#     each hold fix, final setup / hold after the fillers
#   - RouteDesign_for_ECO (analysis mode single) for the Tempus sign-off STA / ECO
#  Input: ../../syn/ch06_uartip/mapped/rv32i_chip_syn_final.v (run_synthesis first)
#####################################################################

## GPDK045 folder (at / on the school server; change this line if it moves). Used by the mmmc view too.
set GPDK045 /GPDK045

## Cell count log for the portfolio: one line per call to reports/cell_count.txt
proc count_cells {tag} {
  file mkdir reports
  set n_all [llength [dbGet top.insts]]
  set n_buf [llength [dbGet -e -p2 top.insts.cell.name BUF*]]
  set n_cbf [llength [dbGet -e -p2 top.insts.cell.name CLKBUF*]]
  set n_dly [llength [dbGet -e -p2 top.insts.cell.name DLY*]]
  set f [open reports/cell_count.txt a]
  puts $f [format "%-22s insts %5d  BUF %4d  CLKBUF %4d  DLY %4d" $tag $n_all $n_buf $n_cbf $n_dly]
  close $f
  puts [format "CELLCOUNT %-22s insts %5d  BUF %4d  CLKBUF %4d  DLY %4d" $tag $n_all $n_buf $n_cbf $n_dly]
}

## Double-height library cells (SITE CoreSiteDouble): the rows are CoreSite only, so never use them
proc dont_use_double_height {} {
  set cells {}
  foreach lc [dbGet head.libCells] {
    if {[dbGet -e $lc.site.name] eq "CoreSiteDouble"} { lappend cells [dbGet $lc.name] }
  }
  set cells [lsort -unique $cells]
  foreach c $cells { setDontUse $c true }
  puts "double-height cells (dont_use): [llength $cells] - $cells"
  return $cells
}

########################################
# InitDesign (Setup, Floorplan)
########################################

## Initialization
set init_gnd_net VSS
set init_lef_file "$GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef $GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef $GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_multibitsDFF.lef $GPDK045/digital/giolib045_v3.5/lef/giolib045_modify.lef"
set init_verilog ../../syn/ch06_uartip/mapped/rv32i_chip_syn_final.v
set init_mmmc_file rv32i_chip.mmmc.view
set init_io_file rv32i_chip.io
set init_top_cell rv32i_chip
set init_pwr_net VDD
init_design

set DOUBLE_CELLS [dont_use_double_height]
## The netlist itself must not use them (the PnR dont_use only stops new ones). First run 2026-11-26:
## IMPSP-365 right after init (cause not found yet; BUFX2 added to the synthesis dont_use as a guard,
## the synthesis result stayed the same). If this check stops, it names the instances.
set DOUBLE_INSTS {}
foreach i [dbGet top.insts] {
  if {[lsearch -exact $DOUBLE_CELLS [dbGet $i.cell.name]] >= 0} { lappend DOUBLE_INSTS "[dbGet $i.name]([dbGet $i.cell.name])" }
}
if {[llength $DOUBLE_INSTS] > 0} {
  error "[llength $DOUBLE_INSTS] netlist instances use double-height cells, e.g. [lrange $DOUBLE_INSTS 0 4] - synthesize again with the dont_use list"
}

## Check Design
checkDesign -io -netlist -physicalLibrary -powerGround -tieHilo -timingLibrary -spef -floorplan -place -outdir checkDesign

##################################################
## Floorplan :: die 3700 um (set by the 197 pads), core 1400 um square in the middle
##################################################
#  The logic is about 35,000 um^2: a 1400 um core is ~2 % used. A larger core (1000 um margin) put
#  the core 1.1 mm from the pads and a few input pad nets had max_tran violations (the pad driver is
#  fixed and there are no rows between pad and core for buffers); 1400 um keeps them about 0.9 mm away.
set DIE         3700
set CORE_MARGIN 1150
set PAD_DEPTH   240     ;# pad cell depth
set OUTER_GAP   40      ;# gap between the IO ring and the outer power ring
#  With giolib045_modify.lef the power pads are AREAIO class: floorPlan shrinks the core box by the
#  pad depth on every side, so ask for PAD_DEPTH less (checked below).
set FP_MARGIN [expr {$CORE_MARGIN - $PAD_DEPTH}]
floorPlan -site CoreSite -d $DIE $DIE $FP_MARGIN $FP_MARGIN $FP_MARGIN $FP_MARGIN

## Place every pad of the ring again on whole um (PADVDD, PADVSS included)
#  The lab placed each power pad by hand (placeInstance padNN x y R270 ...). The IO file has no offsets,
#  so init spreads the pads evenly at fractional positions (e.g. y = 1463.505) and the gaps between
#  them are not whole um: the narrowest IO filler is padIORINGFEED1 (1 um), so 0.3 um gaps stay open
#  after addIoFiller (seen on the second run, 2026-11-26, next to every pad), and checkDesign already
#  reports IMPFP-7251 'IO pad not on Grid' right after init. Here each side is placed again in the IO
#  file order, evenly between the corners, every pad at a whole-um offset from the corner, so all
#  gaps are whole um. The AREAIO power pads (left in the core by floorPlan) get the same orientation
#  and depth as the ring pads of their side.
proc io_side_order {iofile} {
  set order [dict create]
  set side ""
  set fh [open $iofile r]
  foreach l [split [read $fh] "\n"] {
    if {[regexp {^\s*\((top|right|bottom|left)\s*$} $l -> s]} { set side $s; continue }
    if {[regexp {^\s*\((topleft|topright|bottomleft|bottomright)} $l]} { set side ""; continue }
    if {$side ne "" && [regexp {inst name="([^"]+)"} $l -> n]} { dict lappend order $side $n }
  }
  close $fh
  return $order
}
proc inst_box {name} {
  set p [dbGet -e -p top.insts.name $name]
  if {$p eq "" || $p eq "0x0"} { error "instance $name not found" }
  return [concat {*}[dbGet $p.box]]
}
proc in_pad_ring {name} {
  global DIE
  lassign [inst_box $name] x1 y1 x2 y2
  return [expr {$x1 < 1 || $y1 < 1 || $x2 > $DIE - 1 || $y2 > $DIE - 1}]
}
proc place_ring_pads {iofile} {
  set moved 0
  lassign [inst_box CORNER_BL] blx1 bly1 blx2 bly2
  lassign [inst_box CORNER_TR] trx1 try1 trx2 try2
  dict for {side names} [io_side_order $iofile] {
    set axis [expr {$side eq "top" || $side eq "bottom" ? 0 : 1}]
    set start [expr {$axis == 0 ? $blx2 : $bly2}]
    set end   [expr {$axis == 0 ? $trx1 : $try1}]
    # a pad already in the ring gives the orientation, the depth position and the direction of the order
    set ring {}
    foreach nm $names { if {[in_pad_ring $nm]} { lappend ring $nm } }
    if {[llength $ring] < 2} { error "side $side has fewer than 2 pads in the ring" }
    set ref [lindex $ring 0]
    set rb [inst_box $ref]
    set orient [dbGet [dbGet -p top.insts.name $ref].orient]
    if {[lindex $rb $axis] > [lindex [inst_box [lindex $ring end]] $axis]} { set names [lreverse $names] }
    set widths {}
    set total 0.0
    foreach nm $names {
      set w [lindex [concat {*}[dbGet [dbGet -p top.insts.name $nm].cell.size]] 0]
      lappend widths $w
      set total [expr {$total + $w}]
    }
    set gap [expr {($end - $start - $total) / ([llength $names] + 1.0)}]
    if {$gap < 1} { error "side $side: pads do not fit between the corners (gap $gap)" }
    set used 0.0
    foreach nm $names w $widths {
      set pos [format %.3f [expr {$start + round($used + $gap)}]]
      set used [expr {$pos - $start + $w}]
      if {$axis == 0} {
        placeInstance $nm $pos [lindex $rb 1] $orient -fixed
      } else {
        placeInstance $nm [lindex $rb 0] $pos $orient -fixed
      }
      incr moved
    }
    puts "side $side: [llength $names] pads from $start to $end, gap about [format %.2f $gap] um"
  }
  return $moved
}
## Gaps in the IO ring after addIoFiller (pads, corners, fillers side by side; 0 expected)
proc ring_gaps {} {
  global DIE
  set bad 0
  foreach side {bottom top left right} {
    set L {}
    foreach i [dbGet top.insts] {
      lassign [concat {*}[dbGet $i.box]] x1 y1 x2 y2
      switch $side {
        bottom { if {$y1 < 1}        { lappend L [list $x1 $x2 [dbGet $i.name]] } }
        top    { if {$y2 > $DIE - 1} { lappend L [list $x1 $x2 [dbGet $i.name]] } }
        left   { if {$x1 < 1}        { lappend L [list $y1 $y2 [dbGet $i.name]] } }
        right  { if {$x2 > $DIE - 1} { lappend L [list $y1 $y2 [dbGet $i.name]] } }
      }
    }
    set L [lsort -real -index 0 $L]
    for {set k 1} {$k < [llength $L]} {incr k} {
      set e0 [lindex $L [expr {$k - 1}] 1]
      set s1 [lindex $L $k 0]
      if {abs($s1 - $e0) > 0.001} {
        incr bad
        if {$bad <= 10} { puts "IO ring gap ($side): [lindex $L [expr {$k - 1}] 2] ends $e0, [lindex $L $k 2] starts $s1" }
      }
    }
  }
  puts "IO ring gaps: $bad"
  return $bad
}
puts "pads placed again: [place_ring_pads rv32i_chip.io]"

## Rows again over the whole core box (the first floorPlan left out the band the power pads took)
deleteRow -all
createRow -site CoreSite -area [list $CORE_MARGIN $CORE_MARGIN [expr {$DIE - $CORE_MARGIN}] [expr {$DIE - $CORE_MARGIN}]]
## Checks: every pad in the ring, core box as requested
dict for {side names} [io_side_order rv32i_chip.io] {
  foreach nm $names {
    if {![in_pad_ring $nm]} { error "pad $nm ($side) is not in the pad ring: [inst_box $nm]" }
  }
}
lassign [concat {*}[dbGet top.fPlan.coreBox]] cx1 cy1 cx2 cy2
puts "core box = $cx1 $cy1 $cx2 $cy2 (requested [expr {$DIE - 2 * $CORE_MARGIN}] um square at $CORE_MARGIN)"
if {abs($cx1 - $CORE_MARGIN) > 5 || abs($cx2 - ($DIE - $CORE_MARGIN)) > 5 ||
    abs($cy1 - $CORE_MARGIN) > 5 || abs($cy2 - ($DIE - $CORE_MARGIN)) > 5} {
  error "core box $cx1 $cy1 $cx2 $cy2 is not the requested one"
}

## IO Filler Insertion
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side n
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side s
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side w
addIoFiller -cell padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1 -prefix FILLER -side e
ring_gaps

# Verify Timing
report_analysis_views
timeDesign -prePlace

## If there is no error, Save Design
saveDesign -def InitDesign


########################################
# PowerPlan
########################################
#  board -> power pads -> outer ring -> ring-to-ring stripes -> inner ring / core stripes -> rails
#restoreDesign InitDesign.dat rv32i_chip

## Global Net Connection
globalNetConnect VDD -type pgpin -pin VDD -instanceBasename *
globalNetConnect VSS -type pgpin -pin VSS -instanceBasename *
globalNetConnect VDD -type tiehi -instanceBasename *
globalNetConnect VSS -type tielo -instanceBasename *
setTieHiLoMode -reset
setTieHiLoMode -cell {  TIELO TIEHI } -honorDontTouch false -createHierPort false

setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 -skip_crossing_trunks none -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape }
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size false -split_vias false -orthogonal_only true -allow_jog { padcore_ring  block_ring } -skip_via_on_pin {  standardcell } -skip_via_on_wire_shape {  noshape   }

## Power check after each sub-step: opens of VDD / VSS, DRC count, special wires -> reports/03_pgcheck.txt
proc pg_check {tag} {
  file mkdir reports
  set rpt reports/03_${tag}.open.rpt
  verifyConnectivity -nets {VDD VSS} -type special -geomConnect -noAntenna -error 1000 -warning 50 -report $rpt
  set probs {}
  set fh [open $rpt r]
  foreach l [split [read $fh] "\n"] {
    if {[regexp {(\d+) Problem\(s\) \((IMPVFC-\d+)\)} $l -> n code]} { lappend probs "$code=$n" }
  }
  close $fh
  set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false -use_min_spacing_on_block_obs auto -report reports/03_${tag}.drc.rpt -limit 1000
  verify_drc
  set ndrc 0
  set fh [open reports/03_${tag}.drc.rpt r]
  regexp {Total Violations\s*:\s*(\d+)} [read $fh] -> ndrc
  close $fh
  set shapes {}
  foreach s {ring padring stripe followpin iowire corewire} {
    set n [llength [dbGet -e top.nets.sWires.shape $s]]
    if {$n} { lappend shapes "$s=$n" }
  }
  if {![llength $probs]} { set probs {no-opens} }
  set line "PGCHECK $tag : opens [join $probs { }] | DRC $ndrc | sWires [join $shapes { }]"
  puts $line
  set fh [open reports/03_pgcheck.txt a]
  puts $fh $line
  close $fh
}
## Bounding box of all ring wires (measured from the database)
proc ring_bbox {} {
  set nums [concat {*}[dbGet -e [dbGet -e -p top.nets.sWires.shape ring].box]]
  if {[llength $nums] < 4} { error "no ring wires found" }
  set x1 1e9; set y1 1e9; set x2 -1e9; set y2 -1e9
  foreach {a b c d} $nums {
    set x1 [expr {min($x1,$a)}]; set y1 [expr {min($y1,$b)}]
    set x2 [expr {max($x2,$c)}]; set y2 [expr {max($y2,$d)}]
  }
  return [list $x1 $y1 $x2 $y2]
}
file delete -force reports/03_pgcheck.txt
lassign [concat {*}[dbGet top.fPlan.coreBox]] CX1 CY1 CX2 CY2
set STRIPE_OPTS {-nets {VDD VSS} -width 5 -spacing 5 -set_to_set_distance 100 -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal11 -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None}

## Make Rectangular Ring :: inner Ring (around the core, 5 um away)
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top Metal11 bottom Metal11 left Metal10 right Metal10} -width {top 5 bottom 5 left 5 right 5} -spacing {top 5 bottom 5 left 5 right 5} -offset {top 5 bottom 5 left 5 right 5} -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None
set INNER_BOX [ring_bbox]
pg_check 3-2_inner_ring

## Make STD cells's Power Rail
setSrouteMode -viaConnectToShape { noshape }
sroute -connect { corePin } -layerChangeRange { Metal1(1) Metal11(11) } -blockPinTarget { nearestTarget } -corePinTarget { firstAfterRowEnd } -allowJogging 1 -crossoverViaLayerRange { Metal1(1) Metal11(11) } -nets { VDD VSS } -allowLayerChange 1 -targetViaLayerRange { Metal1(1) Metal11(11) }
pg_check 3-3_rails

## Make Stripes in Core Area (area = inner ring box, so each stripe ends on the inner ring)
lassign $INNER_BOX IX1 IY1 IX2 IY2
eval addStripe $STRIPE_OPTS -area [list $INNER_BOX] -layer Metal10 -direction vertical -start_from left -start_offset [expr {$CX1 - $IX1 + 10}] -stop_offset [expr {$IX2 - $CX2 + 10}]
eval addStripe $STRIPE_OPTS -area [list $INNER_BOX] -layer Metal11 -direction horizontal -start_from bottom -start_offset [expr {$CY1 - $IY1 + 10}] -stop_offset [expr {$IY2 - $CY2 + 10}]
pg_check 3-4_core_stripes

## Make Outer Rectangular Ring (along the inner edge of the IO ring)
addRing -nets {VDD VSS} -type core_rings -follow io -layer {top Metal11 bottom Metal11 left Metal10 right Metal10} -width {top 5 bottom 5 left 5 right 5} -spacing {top 5 bottom 5 left 5 right 5} -offset [list top $OUTER_GAP bottom $OUTER_GAP left $OUTER_GAP right $OUTER_GAP] -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None
if {[llength [dbGet -e top.nets.sWires.shape ring]] <= 8} { error "outer ring was not created - check the addRing messages above" }
set OUTER_BOX [ring_bbox]
pg_check 3-5_outer_ring

## Connect between Pad and Outer Rectangular Ring
setSrouteMode -viaConnectToShape { noshape }
sroute -connect { padPin } -layerChangeRange { Metal1(1) Metal11(11) } -padPinPortConnect { allPort oneGeom } -padPinTarget { ring } -allowJogging 1 -crossoverViaLayerRange { Metal1(1) Metal11(11) } -nets { VDD VSS } -allowLayerChange 1 -targetViaLayerRange { Metal1(1) Metal11(11) }
pg_check 3-6_pad_wires

## Connect between Inner and Outer Rectangular Ring :: vertical and horizontal stripes over the core
lassign $OUTER_BOX OX1 OY1 OX2 OY2
eval addStripe $STRIPE_OPTS -area [list $OUTER_BOX] -layer Metal10 -direction vertical -start_from left -start_offset [expr {$CX1 - $OX1 + 50}] -stop_offset [expr {$OX2 - $CX2 + 50}]
eval addStripe $STRIPE_OPTS -area [list $OUTER_BOX] -layer Metal11 -direction horizontal -start_from bottom -start_offset [expr {$CY1 - $OY1 + 50}] -stop_offset [expr {$OY2 - $CY2 + 50}]
pg_check 3-7_ring_stripes

## Trim dangling stripe ends (the core stripes run past their own inner ring)
editTrim -nets {VDD VSS}
pg_check 3-8_trim

## DRC
set_verify_drc_mode -area {0 0 0 0}
set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false -use_min_spacing_on_block_obs auto -report rv32i_chip.drc.rpt -limit 1000
verify_drc
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer

## verifyConnectiviy -only Soft PG Connect
verifyConnectivity -type all -noOpen -noAntenna -noWeakConnect -noUnConnPin -noUnroutedNet -error 1000 -warning 50
## power grid opens (the check above uses -noOpen)
verifyConnectivity -nets {VDD VSS} -type special -geomConnect -noAntenna -error 1000 -warning 50

setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer

## If there is no error, Save Design
saveDesign -def PowerPlan

######################################
## Placement & Optimization
######################################
#restoreDesign PowerPlan.dat rv32i_chip
set_db place_global_cong_effort high

# First placement
place_design
# tie cells for the constant inputs (synthesis does not use TIE cells: dont_use list)
addTieHiLo -cell {TIEHI TIELO} -prefix TIE

# Check the Placement Density
checkPlace rv32i_chip.checkPlace

# Early GlobalRoute :: analisys of Congestion and Timing after Placement
setRouteMode -earlyGlobalMinRouteLayer 1 -earlyGlobalMaxRouteLayer 11 -earlyGlobalHonorMsvRouteConstraint false -earlyGlobalRoutePartitionPinGuide true
earlyGlobalRoute
reportCongestion -hotSpot
reportCongestion -overflow

# View Density Map
setDrawView place
setLayerPreference densityMap -isVisible 1
setLayerPreference densityMap -isVisible 0

## View Pin Density Map
setLayerPreference pinDensityMap -isVisible 1
setLayerPreference pinDensityMap -isVisible 0

# Placement Optimization
place_opt_design
count_cells after_place_opt

# Early GlobalRoute :: analisys of Congestion and Timing after Placement
earlyGlobalRoute
reportCongestion -hotSpot
reportCongestion -overflow

#Timing summary
timeDesign -preCTS -outDir reports/timing/preCTS

#checkDesign :: Density
checkDesign -place

# If there is no error, Save Design
saveDesign -def PlaceOpt

########################################
# CTS & Optimization
########################################

#restoreDesign PlaceOpt.dat rv32i_chip
#  (after a restoreDesign, source the procs at the top of this file and: set DOUBLE_CELLS [dont_use_double_height])
#  The clock pad is on the west edge, about 1.8 mm from the logic. With the CCOpt defaults a chain of
#  ~35 small buffers gave 4.1 ns insertion delay, and the IO latency update put minus that delay on one
#  side of the reg2reg checks -> hold -1.134 ns on 2216 paths (first project run, 2026-11-16). So:
#   - strong clock buffers / inverters only, a looser transition target -> fewer, larger repeaters
#   - trunk on Metal7-8 (less RC), leaves on Metal3-5
#   - no IO latency update: the board clock edge at the CLK pin is time 0 for every path
set CTS_BUFS {}
foreach c {CLKBUFX8 CLKBUFX12 CLKBUFX16 CLKBUFX20} {
  if {[dbGet -e head.libCells.name $c] ne "" && [lsearch -exact $DOUBLE_CELLS $c] < 0} { lappend CTS_BUFS $c }
}
set CTS_INVS {}
foreach c {CLKINVX8 CLKINVX12 CLKINVX16 CLKINVX20} {
  if {[dbGet -e head.libCells.name $c] ne "" && [lsearch -exact $DOUBLE_CELLS $c] < 0} { lappend CTS_INVS $c }
}
puts "CTS buffers: $CTS_BUFS   inverters: $CTS_INVS"
create_route_type -name clk_trunk -top_preferred_layer Metal8 -bottom_preferred_layer Metal7
create_route_type -name clk_leaf  -top_preferred_layer Metal5 -bottom_preferred_layer Metal3
set_ccopt_property route_type clk_trunk -net_type trunk
set_ccopt_property route_type clk_leaf  -net_type leaf
set_ccopt_property buffer_cells   $CTS_BUFS
set_ccopt_property inverter_cells $CTS_INVS
set_ccopt_property target_max_trans 0.2
# Target about skew (lab 0.01; 0.05 as in the project run)
set_ccopt_property target_skew 0.05
set_ccopt_property update_io_latency false

create_ccopt_clock_tree_spec
# CTS and report all timing WNS, TNS results
ccopt_design
count_cells after_cts

# Propagated Clock (board clock only; vclk is a virtual clock)
set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [get_clocks clk]
set_clock_latency -source 0 [get_clocks clk]

# Check right-after CTS
file mkdir reports/clock
report_ccopt_clock_trees -file reports/clock/clock_trees.rpt
report_ccopt_skew_groups -file reports/clock/skew_groups.rpt
report_clock_timing -type skew -nworst 5 > reports/clock/skew.rpt

# Virtual clock vclk (memory read round trip, see rv32i_chip_func.sdc): latency = the average clock
# insertion delay (Avg ID) of the skew group report for each view: SS_WORST:setup.late for the slow
# view (mode FUNC_S), FF_BEST:hold.early for the fast view (mode FUNC_F).
# If the report line is not found, set the values by hand before this part: set VCLK_LAT_SLOW <ns> ...
proc skew_group_avg_id {rpt corner} {
  set fh [open $rpt r]
  set lines [split [read $fh] "\n"]
  close $fh
  foreach l $lines {
    set f [regexp -all -inline {\S+} $l]
    if {[lindex $f 0] eq $corner && [llength $f] > 5 && [string is double -strict [lindex $f 5]]} {
      return [lindex $f 5]
    }
  }
  error "skew_group_avg_id: no '$corner' line in $rpt (set VCLK_LAT_SLOW / VCLK_LAT_FAST by hand)"
}
foreach {mode corner var} {FUNC_S SS_WORST:setup.late VCLK_LAT_SLOW FUNC_F FF_BEST:hold.early VCLK_LAT_FAST} {
  if {[info exists $var]} {
    set lat [set $var]
  } else {
    set lat [skew_group_avg_id reports/clock/skew_groups.rpt $corner]
  }
  set_interactive_constraint_modes [list $mode]
  set_clock_latency -source $lat [get_clocks vclk]
  puts "vclk latency ($mode) = $lat ns"
}
set_interactive_constraint_modes [all_constraint_modes -active]
timeDesign -postCTS -outDir reports/timing/postCTS

# Optimization of my design after CTS
optDesign -postCTS 	; # Setup/DRV concurrently
# Hold before / after the post-CTS hold fix (portfolio: buffer insertion)
timeDesign -postCTS -hold -outDir reports/timing/postCTS_hold_before
count_cells postCTS_before_hold
setOptMode -holdTargetSlack 0.02   ;# small margin: the first project runs ended at -0.000 ns on one path
optDesign -postCTS -hold ;# Only for hold violation
count_cells postCTS_after_hold
timeDesign -postCTS -hold -outDir reports/timing/postCTS_hold_after
timeDesign -postCTS -outDir reports/timing/postCTS

# If there is no error, Save Design
saveDesign -def PostCTSopt

##############
# Route
##############

#restoreDesign PostCTSopt.dat rv32i_chip

# Route Auto : To Detail
setNanoRouteMode -quiet -drouteFixAntenna 1
setNanoRouteMode -quiet -routeInsertAntennaDiode 0
setNanoRouteMode -quiet -routeWithTimingDriven 1
setNanoRouteMode -quiet -routeWithEco 0
setNanoRouteMode -quiet -routeWithLithoDriven 0
setNanoRouteMode -quiet -droutePostRouteLithoRepair 0
setNanoRouteMode -quiet -routeWithSiDriven 1
setNanoRouteMode -quiet -routeTdrEffort 8
setNanoRouteMode -quiet -drouteAutoStop 0
setNanoRouteMode -quiet -routeSelectedNetOnly 0
setNanoRouteMode -quiet -routeTopRoutingLayer 11
setNanoRouteMode -quiet -routeBottomRoutingLayer 1
setNanoRouteMode -quiet -drouteEndIteration 5
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
routeDesign -globalDetail

# Timing right after NanoRoute, before any post-route optimization (portfolio). Post-route
# timeDesign needs the analysis mode OCV (IMPOPT-7027), so set it first.
setAnalysisMode -analysisType onChipVariation -cppr both
timeDesign -postRoute -outDir reports/timing/route_setup
timeDesign -postRoute -hold -outDir reports/timing/route_hold
count_cells after_route

# DRC
set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false -use_min_spacing_on_block_obs auto -report rv32i_chip.drc.rpt -limit 1000
verify_drc
set_verify_drc_mode -area {0 0 0 0}

# Auto DRC Fix
setAnalysisMode -analysisType onChipVariation
optDesign -postRoute -drv ; # auto DRC Fix

# LVS : Connectivity
verifyConnectivity -type all -geomConnect -error 1000 -warning 50

# Violation Browser
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer

# Net Parasitic RC Extraction
extractRC

# Timing optimization. The lab switches to bcwc here; the project chip run stayed in OCV and kept a
# setup margin, because the hold fix and the fillers used up a 0-slack setup result (2026-11-17:
# -0.012 ns on RAM_RDATA -> regfile). Same here.
setDelayCalMode -SIAware false ; # Delete SI effect
setOptMode -setupTargetSlack 0.05
optDesign -postRoute -setup; # 0 : Optimization and resolve the Setup Violation

# Hold before / after the post-route hold fix (portfolio: STA -> buffer insertion)
timeDesign -postRoute -hold -outDir reports/timing/postRoute_hold_before
count_cells postRoute_before_hold
optDesign -postRoute -hold; # 1 : Optimization and resolve the Hold Violation
count_cells postRoute_after_hold

timeDesign -postRoute -outDir reports/timing/postRoute_setup 	; # Setup time report
timeDesign -postRoute -hold -outDir reports/timing/postRoute_hold; # Hold time report

# If there is no error, save Design
saveDesign -rc -def RouteDesign

# Design for the Tempus sign-off STA and the ECO: analysis mode single as in the lab ECO flow
setAnalysisMode -analysisType single
saveDesign -rc -def RouteDesign_for_ECO
setAnalysisMode -analysisType onChipVariation

##################
# Power Analysis
##################

set_power_analysis_mode -reset
set_power_analysis_mode -method static -analysis_view FUNC_SS_WORST -corner max -create_binary_db true -write_static_currents true -honor_negative_energy true -ignore_control_signals true

## Once again : Global Net Connection
globalNetConnect VDD -type pgpin -pin VDD -instanceBasename *
globalNetConnect VSS -type pgpin -pin VSS -instanceBasename *
globalNetConnect VDD -type tiehi -instanceBasename *
globalNetConnect VSS -type tielo -instanceBasename *

set_power_output_dir -reset
set_power_output_dir ./run1
set_dynamic_power_simulation -reset
set_default_switching_activity -reset
set_default_switching_activity -input_activity 0.2 -period 13.0 ;# 13 ns operation
read_activity_file -reset
set_power -reset
set_powerup_analysis -reset
report_power -rail_analysis_format VS -outfile ./run1/rv32i_chip.rpt

#######################
#### Chip Finish ######
#######################
#restoreDesign RouteDesign.dat rv32i_chip

# Add Filler
getFillerMode -quiet
addFiller -cell FILL1 FILL8 FILL64 FILL4 FILL32 FILL2 FILL16 -prefix FILLER

# DRC
verify_drc

# LVS : Connectivity
verifyConnectivity -type all -geomConnect -error 1000 -warning 50

# Placement check (also after fillers)
checkPlace rv32i_chip.checkPlace

# Error Browser
setLayerPreference violation -isVisible 1
violationBrowser -all -no_display_false -displayByLayer

# Extraction
extractRC

# Final timing (after the fillers)
timeDesign -postRoute -outDir reports/timing/final_setup
timeDesign -postRoute -hold -outDir reports/timing/final_hold

# If there is no error, save Design
saveDesign -rc -def ChipFinish

#####################
#### Write Out ######
#####################
# Netlist for gate-level simulation and LEC, without the power pads (no logical ports). Hierarchical
# (not -flat): write_sdf writes hierarchical instance names, and the SDF scopes must be found in the
# netlist (UART IP lesson: a flat netlist annotated almost nothing).
saveNetlist -excludeCellInst "PADVDD PADVSS PADVSSIOR PADVDDIOR" rv32i_chip_pnr.v

# SDF for gate-level simulation: slow (setup side) and fast (hold side)
write_sdf -view FUNC_SS_WORST rv32i_chip_slow.sdf
write_sdf -view FUNC_FF_BEST  rv32i_chip_fast.sdf

# Write Out Constraint
writeTimingCon rv32i_chip_pnr.sdc

# DEF and GDS (GDS without layermap file for GPDK045)
defOut -floorplan -netlist -routing rv32i_chip.def
streamOut rv32i_chip.gds -libName DesignLib -units 2000 -mode ALL

#exit
