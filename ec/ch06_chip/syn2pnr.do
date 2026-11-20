// ======================================================================
// syn2pnr.do - Conformal LEC: Genus netlist (golden) vs Innovus netlist (revised), rv32i_chip
//
// Same dofile form as the lab flow. Paths are relative to the run folder that run_lec.sh
// prepares (runs/<compare>/ or runs/work/):
//   lib/   cell and pad simulation models (links into GPDK045_DIR) + pad_power.v
//   syn.v  synthesized netlist (hierarchical)
//   pnr.v  PnR netlist (saveNetlist -flat: CTS / hold buffers and resized cells added,
//          power pads PADVDD/PADVSS/PADVDDIOR/PADVSSIOR left out)
//
// Batch      : bash ec/ch06_chip/run_lec.sh syn2pnr
// Interactive: bash ec/ch06_chip/run_lec.sh -i syn2pnr, then paste one STEP block at a time
//              (or: dofile <repo>/ec/ch06_chip/syn2pnr.do)
// ======================================================================

// ## STEP 0. Log file
set log file log/syn2pnr.log -replace

// ## STEP 1. Library: standard cells, signal pads, power pads (both sides)
read library -verilog -both \
        lib/slow_vdd1v0_basicCells.v \
        lib/pads_SS_s1vg.v \
        lib/pad_power.v

// ## STEP 2. Golden: Genus netlist
read design syn.v -verilog -golden

// ## STEP 3. Revised: Innovus netlist
read design pnr.v -verilog -revised

// ## STEP 4. Mapping (key points: outputs, flip-flops, black boxes)
// The 4 power pads exist only on the golden side; they have no pins, so they can only
// show up as unmapped black boxes, never as compare points
set system mode lec
report unmapped points

// ## STEP 5. Compare
add compare points -all
compare

// ## STEP 6. Reports
report verification
report statistics
report black box
