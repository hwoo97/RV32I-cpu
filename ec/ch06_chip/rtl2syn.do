// ======================================================================
// rtl2syn.do - Conformal LEC: RTL (golden) vs Genus netlist (revised), rv32i_chip
//
// Same dofile form as the lab flow (read library / read design / set system mode lec /
// add compare points / compare / report). Paths are relative to the run folder that
// run_lec.sh prepares (runs/<compare>/ or runs/work/):
//   lib/   cell and pad simulation models (links into GPDK045_DIR) + pad_power.v
//   rtl/   link to rtl/ch06_exception (the 15 files Genus read)
//   syn.v  synthesized netlist (syn/ch06_chip/runs/t13ns/mapped/rv32i_chip_syn_final.v)
//   rv32i_defs.vh, mcu_memmap.vh   links for `include
//
// Batch      : bash ec/ch06_chip/run_lec.sh rtl2syn
// Interactive: bash ec/ch06_chip/run_lec.sh -i rtl2syn, then paste one STEP block at a time
//              (or: dofile <repo>/ec/ch06_chip/rtl2syn.do)
// ======================================================================

// ## STEP 0. Log file
set log file log/rtl2syn.log -replace

// ## STEP 1. Library: standard cells, signal pads, power pads (both sides)
read library -verilog -both \
        lib/slow_vdd1v0_basicCells.v \
        lib/pads_SS_s1vg.v \
        lib/pad_power.v

// ## STEP 2. Golden: RTL (same file list as syn/ch06_chip/genus.tcl)
read design -verilog2k -golden \
        rtl/rv32i_core.v rtl/csr.v rtl/control.v rtl/regfile.v rtl/imm_gen.v \
        rtl/alu.v rtl/branch_cmp.v rtl/lsu.v rtl/bus_mux.v rtl/apb_bridge.v \
        rtl/apb_gpio.v rtl/apb_timer.v rtl/apb_uart.v rtl/rv32i_mcu.v rtl/rv32i_chip.v

// ## STEP 3. Revised: Genus netlist
read design syn.v -verilog -revised

// ## STEP 4. Setup: registers that synthesis turned into constants are not counted as unmapped
set flatten model -seq_constant

// ## STEP 5. Mapping (key points: outputs, flip-flops, black boxes)
set system mode lec
report unmapped points

// ## STEP 6. Compare
add compare points -all
compare

// ## STEP 7. Reports
report verification
report statistics
report black box
