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
    set TARGET_PERIOD [expr {[info exists ::env(TARGET_PERIOD)] ? $::env(TARGET_PERIOD) : 13}]
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
#  die DIE x DIE um (set by the pad count); core box CORE_MARGIN um inside the die edge.
#  The logic is about 35,000 um^2: a 1400 um core is ~1.8 % used and leaves room for buffers.
#  2026-11-18: a 1000 um core (margin 1350) put the core 1.1 mm from the pads and a few input pad
#  nets had max_tran up to -0.044 ns (pad driver fixed, no rows in between for buffers). The wire part
#  of the transition goes with the length squared, so the core grows to 1400 um (910 um to the pads).
#  (Before 2026-11-17 the core filled the pad ring, 2940 um, 0.4 % used.)
#  env CORE_MARGIN overrides the margin for a test run.
set DIE         3700
set CORE_MARGIN [expr {[info exists ::env(CORE_MARGIN)] ? $::env(CORE_MARGIN) : 1150}]
# power plan (STEP 3): pad depth, gap between the IO ring and the outer power ring
set PAD_DEPTH   240
set OUTER_GAP   40      ;# 10 um left no room for pad pin access: 95 signal shorts with pad blockages

set G       $::env(GPDK045_DIR)/digital
# IO LEF: giolib045_modify.lef (PADVDD / PADVSS as CLASS PAD AREAIO, as in the earlier project) or the
# original giolib045.lef (CLASS PAD). With AREAIO the floorPlan puts the core power pads inside the core
# box (STEP 2 moves them to the ring); env IO_LEF selects the file for a test run.
set IO_LEF [expr {[info exists ::env(IO_LEF)] ? $::env(IO_LEF) : "giolib045_modify.lef"}]
set LEF_FILES [list \
    $G/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef \
    $G/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef \
    $G/giolib045_v3.5/lef/$IO_LEF]
puts "IO LEF = $IO_LEF"

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

# Double-height cells (SITE CoreSiteDouble) need rows of that site, and the floorplan has CoreSite rows
# only. 2026-11-18: the optimizer put 95 IO buffers (FE_OFC*) on such cells -> checkPlace 'TechSite' 95,
# IMPSP-365 (found only in the Violation Browser). Keep the tool from choosing them.
# (2026-11-19: 'dbGet -p head.libCells.site.name' returned the site, not the cells -> nothing was
#  blocked. Walk the library cells and read each cell's site instead.)
set DOUBLE_CELLS {}
foreach lc [dbGet head.libCells] {
    if {[dbGet -e $lc.site.name] eq "CoreSiteDouble"} { lappend DOUBLE_CELLS [dbGet $lc.name] }
}
set DOUBLE_CELLS [lsort -unique $DOUBLE_CELLS]
puts "double-height cells (dont_use): [llength $DOUBLE_CELLS] - $DOUBLE_CELLS"
if {[llength $DOUBLE_CELLS] == 0} { puts "WARNING: no CoreSiteDouble library cells found - check the site name" }
foreach c $DOUBLE_CELLS { setDontUse $c true }
set n_dbl 0
foreach inst [dbGet top.insts] {
    if {[lsearch -exact $DOUBLE_CELLS [dbGet $inst.cell.name]] >= 0} { incr n_dbl }
}
if {$n_dbl > 0} { puts "WARNING: $n_dbl netlist instances use double-height cells (check synthesis)" }

checkDesign -io -netlist -physicalLibrary -powerGround -tieHilo -timingLibrary -outdir report/checkDesign
report_analysis_views
saveDesign dbs/01_init

####################################################################
## STEP 2. Floorplan, IO pads, IO fillers
####################################################################

# die size and core box (small core in the middle, empty space up to the pads for the power rings);
# the pads go around the die edge in the order of rv32i_chip.io.
# With the AREAIO pads the core box came out PAD_DEPTH smaller on every side than requested
# (2026-11-18: 1350 requested -> 1590), and it cannot be set afterwards (dbSet coreBox not allowed,
# createRow / saveDesign keep it). So ask for PAD_DEPTH more: FP_MARGIN = CORE_MARGIN - PAD_DEPTH.
# The check after the pad move stops the run if the core box is still not CORE_MARGIN.
if {[string match "*modify*" $IO_LEF]} {
    set FP_MARGIN [expr {$CORE_MARGIN - $PAD_DEPTH}]
} else {
    set FP_MARGIN $CORE_MARGIN
}
puts "floorPlan core margin = $FP_MARGIN (target core box margin = $CORE_MARGIN)"
floorPlan -site CoreSite -d $DIE $DIE $FP_MARGIN $FP_MARGIN $FP_MARGIN $FP_MARGIN
lassign [concat {*}[dbGet top.fPlan.coreBox]] cx1 cy1 cx2 cy2
puts "core box after floorPlan = $cx1 $cy1 $cx2 $cy2"

# Move the core power pads into the pad ring.
#  PADVDD / PADVSS are AREAIO class in the IO LEF used here, so the IO file does not put them in the ring:
#  the tool placed them along the inside of the core box (2026-11-18: P_E_VDD at x 1870..2110 with the
#  core at 1590..2110 - rows cut, core box reset). Their slots in the ring are left empty, so each one
#  goes to its slot: evenly between the ring pads before and after it in the IO file order, same edge
#  and orientation as those pads. Earlier runs had the same fault (rails cut at x = 1246.8).
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
proc place_pads_in_ring {iofile} {
    set moved 0
    dict for {side names} [io_side_order $iofile] {
        set axis [expr {$side eq "top" || $side eq "bottom" ? 0 : 1}]
        set n [llength $names]
        set i 0
        while {$i < $n} {
            if {[in_pad_ring [lindex $names $i]]} { incr i; continue }
            # run i..j of pads outside the ring, between ring pads i-1 and j+1
            set j $i
            while {$j + 1 < $n && ![in_pad_ring [lindex $names [expr {$j + 1}]]]} { incr j }
            if {$i == 0 || $j == $n - 1} { error "pad [lindex $names $i] ($side) has no ring pad on both sides" }
            set prev [lindex $names [expr {$i - 1}]]
            set next [lindex $names [expr {$j + 1}]]
            set pb [inst_box $prev]
            set a0 [lindex $pb $axis]
            set a1 [lindex [inst_box $next] $axis]
            set k [expr {$j - $i + 1}]
            set orient [dbGet [dbGet -p top.insts.name $prev].orient]
            for {set m 0} {$m < $k} {incr m} {
                set name [lindex $names [expr {$i + $m}]]
                set pos [expr {$a0 + ($m + 1) * ($a1 - $a0) / ($k + 1.0)}]
                if {$axis == 0} {
                    placeInstance $name $pos [lindex $pb 1] $orient -fixed
                } else {
                    placeInstance $name [lindex $pb 0] $pos $orient -fixed
                }
                puts "pad moved into the ring: $name ($side) [inst_box $name] $orient"
                incr moved
            }
            set i [expr {$j + 1}]
        }
    }
    return $moved
}
set n_moved [place_pads_in_ring $PNR_DIR/rv32i_chip.io]
puts "pads moved into the ring: $n_moved"
# rows again over the whole core box (the first floorPlan left out the band the pads took).
# Not a second floorPlan: it saves the area IO cells relative to the core and puts them back inside
# (2026-11-18: P_N_VDD back at 1590 1870 after the second floorPlan)
deleteRow -all
createRow -site CoreSite -area [list $CORE_MARGIN $CORE_MARGIN [expr {$DIE - $CORE_MARGIN}] [expr {$DIE - $CORE_MARGIN}]]
# checks: every pad of the IO file in the ring, core box close to the requested one
dict for {side names} [io_side_order $PNR_DIR/rv32i_chip.io] {
    foreach nm $names {
        if {![in_pad_ring $nm]} { error "pad $nm ($side) is not in the pad ring: [inst_box $nm]" }
    }
}
lassign [concat {*}[dbGet top.fPlan.coreBox]] cx1 cy1 cx2 cy2
puts "core box = $cx1 $cy1 $cx2 $cy2 (requested [expr {$DIE - 2 * $CORE_MARGIN}] um square at $CORE_MARGIN)"
if {abs($cx1 - $CORE_MARGIN) > 5 || abs($cx2 - ($DIE - $CORE_MARGIN)) > 5 ||
    abs($cy1 - $CORE_MARGIN) > 5 || abs($cy2 - ($DIE - $CORE_MARGIN)) > 5} {
    error "core box $cx1 $cy1 $cx2 $cy2 is not the requested one (floorPlan margin $FP_MARGIN) - a pad or block still cuts the rows, or the shrink is not PAD_DEPTH"
}
# fill the gaps between pads so the IO ring is continuous
foreach side {n s w e} {
    addIoFiller -cell {padIORINGFEED60 padIORINGFEED10 padIORINGFEED5 padIORINGFEED3 padIORINGFEED1} \
        -prefix FILLER -side $side
}
timeDesign -prePlace -outDir report/timing/prePlace
saveDesign dbs/02_floorplan

####################################################################
## STEP 3. Power plan (inner ring, rails, core stripes, outer ring, pad connection, ring stripes)
####################################################################
#  Power path: board -> power pads -> outer ring -> ring-to-ring stripes -> inner ring / core stripes
#  -> Metal1 rails -> cell pins. Order below: 3-1 .. 3-7, then checks.

## 3-1. global net connection (power pins and tie cells -> VDD / VSS)
globalNetConnect VDD -type pgpin -pin VDD -instanceBasename *
globalNetConnect VSS -type pgpin -pin VSS -instanceBasename *
globalNetConnect VDD -type tiehi -instanceBasename *
globalNetConnect VSS -type tielo -instanceBasename *
setTieHiLoMode -reset
setTieHiLoMode -cell {TIELO TIEHI} -honorDontTouch false -createHierPort false

setAddRingMode -ring_target default -extend_over_row 0 -ignore_rows 0 -avoid_short 0 \
    -skip_crossing_trunks none -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 \
    -via_using_exact_crossover_size 1 -orthogonal_only true -skip_via_on_pin {standardcell} \
    -skip_via_on_wire_shape {noshape}
setAddStripeMode -ignore_block_check false -break_at none -route_over_rows_only false \
    -rows_without_stripes_only false -extend_to_closest_target none -stop_at_last_wire_for_area false \
    -partial_set_thru_domain false -ignore_nondefault_domains false -trim_antenna_back_to_shape none \
    -spacing_type edge_to_edge -spacing_from_block 0 -stripe_min_length stripe_width \
    -stacked_via_top_layer Metal11 -stacked_via_bottom_layer Metal1 -via_using_exact_crossover_size false \
    -split_vias false -orthogonal_only true -allow_jog {padcore_ring block_ring} \
    -skip_via_on_pin {standardcell} -skip_via_on_wire_shape {noshape}
# Check after every sub-step (3-2 .. 3-7), so a break is found at the step that made it:
#  power opens (VDD / VSS, geometric), DRC count and special wire counts per shape, one line each in
#  the log ("PGCHECK ...") and in report/03_pgcheck.txt
proc pg_check {tag} {
    set rpt report/03_${tag}.open.rpt
    verifyConnectivity -nets {VDD VSS} -type special -geomConnect -noAntenna -error 1000 -warning 50 \
        -report $rpt
    set probs {}
    set fh [open $rpt r]
    foreach l [split [read $fh] "\n"] {
        if {[regexp {(\d+) Problem\(s\) \((IMPVFC-\d+)\)} $l -> n code]} { lappend probs "$code=$n" }
    }
    close $fh
    set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default \
        -check_same_via_cell true -exclude_pg_net false -ignore_trial_route false \
        -ignore_cell_blockage false -use_min_spacing_on_block_obs auto \
        -report report/03_${tag}.drc.rpt -limit 1000
    verify_drc
    set ndrc 0
    set fh [open report/03_${tag}.drc.rpt r]
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
    set fh [open report/03_pgcheck.txt a]
    puts $fh $line
    close $fh
}
# bounding box of all ring wires {x1 y1 x2 y2} (measured from the database, not assumed)
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
file delete -force report/03_pgcheck.txt
# real core box after floorPlan snapped it to the site grid
lassign [concat {*}[dbGet top.fPlan.coreBox]] CX1 CY1 CX2 CY2
puts "core box = $CX1 $CY1 $CX2 $CY2"

# common stripe options: VDD / VSS pair, 5 um wide, 5 um apart, one pair every 100 um
set STRIPE_OPTS {-nets {VDD VSS} -width 5 -spacing 5 -set_to_set_distance 100 \
    -switch_layer_over_obs false -max_same_layer_jog_length 2 -padcore_ring_top_layer_limit Metal11 \
    -padcore_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 \
    -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 -snap_wire_center_to_grid None}

## 3-2. inner ring: around the core box, 5 um away (top / bottom Metal11, left / right Metal10)
addRing -nets {VDD VSS} -type core_rings -follow core \
    -layer {top Metal11 bottom Metal11 left Metal10 right Metal10} \
    -width {top 5 bottom 5 left 5 right 5} -spacing {top 5 bottom 5 left 5 right 5} \
    -offset {top 5 bottom 5 left 5 right 5} -center 0 -threshold 0 -jog_distance 0 \
    -snap_wire_center_to_grid None
set INNER_BOX [ring_bbox]
puts "inner ring box = $INNER_BOX"
pg_check 3-2_inner_ring

## 3-3. standard cell power rails (Metal1 along the rows, joined to the inner ring)
sroute -connect {corePin} -layerChangeRange {Metal1(1) Metal11(11)} -blockPinTarget {nearestTarget} \
    -corePinTarget {firstAfterRowEnd} -allowJogging 1 -crossoverViaLayerRange {Metal1(1) Metal11(11)} \
    -nets {VDD VSS} -allowLayerChange 1 -targetViaLayerRange {Metal1(1) Metal11(11)}
pg_check 3-3_rails

## 3-4. core stripes: area = the inner ring box, so each stripe ends on the inner ring (vias there).
##      (Without -area the stripes covered the core box only and may stop short of the ring.)
##      First pair 10 um inside the core edge; the same margin at the far side keeps the last pair off
##      the parallel ring side on the same layer. Vertical Metal10, then horizontal Metal11.
lassign $INNER_BOX IX1 IY1 IX2 IY2
eval addStripe $STRIPE_OPTS -area [list $INNER_BOX] -layer Metal10 -direction vertical \
    -start_from left -start_offset [expr {$CX1 - $IX1 + 10}] -stop_offset [expr {$IX2 - $CX2 + 10}]
eval addStripe $STRIPE_OPTS -area [list $INNER_BOX] -layer Metal11 -direction horizontal \
    -start_from bottom -start_offset [expr {$CY1 - $IY1 + 10}] -stop_offset [expr {$IY2 - $CY2 + 10}]
pg_check 3-4_core_stripes

## 3-5. outer ring: along the inner edge of the IO ring, OUTER_GAP um inside it ('-follow io').
##      The inner ring is far from the pads (core box in the middle), so the pads connect here instead.
##      (A second '-follow core' ring with a large offset was not created: stripes ended in the air)
addRing -nets {VDD VSS} -type core_rings -follow io \
    -layer {top Metal11 bottom Metal11 left Metal10 right Metal10} \
    -width {top 5 bottom 5 left 5 right 5} -spacing {top 5 bottom 5 left 5 right 5} \
    -offset [list top $OUTER_GAP bottom $OUTER_GAP left $OUTER_GAP right $OUTER_GAP] \
    -center 0 -threshold 0 -jog_distance 0 -snap_wire_center_to_grid None
set n_ring [llength [dbGet -e top.nets.sWires.shape ring]]
puts "ring wires after the outer ring: $n_ring (inner ring alone = 8)"
if {$n_ring <= 8} { error "outer ring was not created - check the addRing messages above" }
set OUTER_BOX [ring_bbox]
puts "outer ring box = $OUTER_BOX (expected about [expr {$PAD_DEPTH + $OUTER_GAP}] from the die edge)"
if {[lindex $OUTER_BOX 0] >= $IX1} { error "outer ring box is not outside the inner ring" }
pg_check 3-5_outer_ring

## 3-6. power pads (PADVDD / PADVSS) -> nearest ring = the outer ring
##      (IMPSR-1256 'no CORE class pad pin' is expected: the pad pins are AREAIO class, found and used)
setSrouteMode -viaConnectToShape {noshape}
sroute -connect {padPin} -layerChangeRange {Metal1(1) Metal11(11)} \
    -padPinPortConnect {allPort oneGeom} -padPinTarget {ring} -allowJogging 1 \
    -crossoverViaLayerRange {Metal1(1) Metal11(11)} -nets {VDD VSS} -allowLayerChange 1 \
    -targetViaLayerRange {Metal1(1) Metal11(11)}
pg_check 3-6_pad_wires
# No 'sroute -connect padRing': the pad ring (pads, IO fillers, corners) is connected by abutment
# inside the cells. Tried 2026-11-17: its wires shorted with the Metal4 blockages of CORNER_* and
# PAD_IROM_DATA_0 (8 DRC shorts). The pad ring bus pieces and the 8 IMPVFC-96 terminals on CORNER_*
# stay in the connectivity report (abutment inside the pad cells is not modeled as wires).

## 3-7. ring-to-ring stripes: area = outer ring box, so each stripe runs from the outer ring across
##      the inner ring and the core to the other side of the outer ring and joins the two rings.
##      x / y range kept over the core, first pair 50 um inside the core edge (between the 3-4 pairs)
lassign $OUTER_BOX OX1 OY1 OX2 OY2
eval addStripe $STRIPE_OPTS -area [list $OUTER_BOX] -layer Metal10 -direction vertical \
    -start_from left -start_offset [expr {$CX1 - $OX1 + 50}] -stop_offset [expr {$OX2 - $CX2 + 50}]
eval addStripe $STRIPE_OPTS -area [list $OUTER_BOX] -layer Metal11 -direction horizontal \
    -start_from bottom -start_offset [expr {$CY1 - $OY1 + 50}] -stop_offset [expr {$OY2 - $CY2 + 50}]
pg_check 3-7_ring_stripes

## 3-8. trim dangling stripe ends: the 3-4 core stripes run past their own inner ring to the outer
##      edge of the ring pair (2026-11-18: 76 IMPVFC-94 dangling Metal10 / Metal11 ends at y 1331.69 /
##      2368.62 in the STEP 7 check, not shown by the special-wire checks above). editTrim cuts each
##      end back to its last connection; tried on the STEP 7 database: IMPVFC-94 76 -> 0, DRC 0.
editTrim -nets {VDD VSS}
pg_check 3-8_trim

## checks: DRC, connectivity, and power grid opens
set_verify_drc_mode -disable_rules {} -check_ndr_spacing auto -check_only default -check_same_via_cell true \
    -exclude_pg_net false -ignore_trial_route false -ignore_cell_blockage false \
    -use_min_spacing_on_block_obs auto -report report/03_power.drc.rpt -limit 1000
verify_drc
verifyConnectivity -type all -noOpen -noAntenna -noWeakConnect -noUnConnPin -noUnroutedNet \
    -error 1000 -warning 50 -report report/03_power.conn.rpt
# power grid opens: the check above uses -noOpen and hides them. A clean grid here (before placement)
# avoids finding VDD / VSS opens only at STEP 7 after a full route run.
verifyConnectivity -nets {VDD VSS} -type special -geomConnect -noAntenna -error 1000 -warning 50 \
    -report report/03_power.open.rpt
saveDesign dbs/03_power

####################################################################
## STEP 4. Placement and optimization
####################################################################

set_db place_global_cong_effort high
place_design
# tie cells for the constant inputs (synthesis does not use TIE cells: syn/common/dont_use.tcl)
addTieHiLo -cell {TIEHI TIELO} -prefix TIE
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

# The clock pad is on the west edge, about 1.8 mm from the logic in the middle of the core.
# First run (2026-11-16) with the CCOpt defaults: a chain of ~35 small buffers (BUFX2, CLKBUFX3/4)
# every ~50 um -> insertion delay 4.1 ns slow / 1.1 ns fast, and CCOpt's IO latency update put a
# source latency of minus that delay on one side of the reg2reg checks -> hold -1.13 ns on 2216 paths.
#  - strong clock buffers / inverters only, a looser transition target -> fewer, larger repeaters
#  - trunk on Metal7-8 (less RC than the low layers), leaves on Metal3-5
#  - no IO latency update: the board clock edge at the CLK pin is time 0 for every path, so IO paths
#    see the real insertion delay (as the chip would)
set CTS_BUFS {}
# (double-height cells left out: no rows for them, see STEP 1; list again after a restoreDesign)
if {![info exists DOUBLE_CELLS]} {
    set DOUBLE_CELLS {}
    foreach lc [dbGet head.libCells] {
        if {[dbGet -e $lc.site.name] eq "CoreSiteDouble"} { lappend DOUBLE_CELLS [dbGet $lc.name] }
    }
    foreach c $DOUBLE_CELLS { setDontUse $c true }
}
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
set_ccopt_property target_skew 0.05
set_ccopt_property update_io_latency false
create_ccopt_clock_tree_spec
ccopt_design
set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [get_clocks clk]
# no source latency on the board clock (removes anything left from an earlier run)
set_clock_latency -source 0 [get_clocks clk]

# Virtual clock vclk (memory read round trip, syn/ch06_chip/cons/rv32i_chip.sdc): its latency = the
# average clock insertion delay (Avg ID) of the skew group report, per corner: dc_slow:setup.late for
# the setup view, dc_fast:hold.early for the hold view. Or given by hand: set VCLK_LAT_SLOW / VCLK_LAT_FAST
# (prompt or environment). (First version used get_property -view, which this Innovus rejected.)
report_ccopt_clock_trees  -file report/05_clock_trees.rpt
report_ccopt_skew_groups  -file report/05_skew_groups.rpt
proc skew_group_avg_id {rpt corner} {
    # summary line: <corner> <skew group> <ID target> <Min ID> <Max ID> <Avg ID> ...
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
foreach {mode view corner var} {FUNC_S view_slow dc_slow:setup.late VCLK_LAT_SLOW
                                FUNC_F view_fast dc_fast:hold.early VCLK_LAT_FAST} {
    if {[info exists $var]} {
        set lat [set $var]
    } elseif {[info exists ::env($var)]} {
        set lat $::env($var)
    } else {
        set lat [skew_group_avg_id report/05_skew_groups.rpt $corner]
    }
    set_interactive_constraint_modes [list $mode]
    set_clock_latency -source $lat [get_clocks vclk]
    puts "vclk latency ($mode, $view) = $lat ns"
}
set_interactive_constraint_modes [all_constraint_modes -active]
optDesign -postCTS
# small hold target margin: the first runs ended at -0.000 ns on one path
setOptMode -holdTargetSlack 0.02
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
# No layer constraint on the pad <-> core nets (2026-11-18). A few input pad nets (about 1.1 mm from
# pad to core, pad driver fixed, no rows in between) end with max_tran up to -0.044 ns, positive slack;
# kept as a known DRV item. Tried: all pad-core nets on Metal7-8 with effort hard -> 499 DRC shorts with
# the Metal4-8 blockages of the pad cells, 19 dangling / open signal nets at the pad pins, max_tran 2 left.
routeDesign -globalDetail

setAnalysisMode -analysisType onChipVariation
setDelayCalMode -SIAware false
optDesign -postRoute -drv
# setup margin for the post-route steps (hold fix, fillers, final SI timing). 2026-11-17 final had
# -0.012 on RAM_RDATA[9] -> regfile (31 paths): the optimizer stops at slack 0 and the hold fix ate it.
setOptMode -setupTargetSlack 0.05
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
# placement legality (cells on the right site, no overlaps): not part of verify_drc / verifyConnectivity
checkPlace report/07_checkplace.rpt
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

# flat netlist without the power pads (they have no logical ports) - gate-level simulation and LEC,
# same form as the earlier lab flow
saveNetlist -flat -excludeCellInst {PADVDD PADVSS PADVDDIOR PADVSSIOR} out/${TOP_DESIGN}_pnr.v
# netlist with every physical instance (fillers, corners) for LVS-like checks.
# (-includePhysicalCell takes a cell list and swallowed the file name: IMPTCM-46 on 2026-11-17)
saveNetlist out/${TOP_DESIGN}_pnr_phys.v -includePhysicalInst
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
