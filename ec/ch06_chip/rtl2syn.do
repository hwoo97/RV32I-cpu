// ======================================================================
// rtl2syn.do - Conformal LEC: RTL (golden) vs Genus netlist (revised), rv32i_chip
//
// Same dofile form as the lab flow (read library / read design / set system mode lec /
// add compare points / compare / report). Paths are relative to the run folder that
// run_lec.sh prepares (runs/<compare>/ or runs/work/):
//   lib/   cell and pad Liberty files (links into GPDK045_DIR, the same .lib files Genus mapped to)
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

// ## STEP 1. Library: Liberty cell functions (both sides), the same .lib files Genus mapped to
// (the dofile Genus writes reads them the same way)
// Power pads (PADVDD ...) that are not in the libraries become empty black boxes on both sides
set undefined cell black_box -noascend -both
read library -liberty -both \
        lib/slow_vdd1v0_basicCells.lib \
        lib/pads_SS_s1vg.lib

// Undriven RTL nets are 0, as Genus treats them
set undriven signal 0 -golden

// ## STEP 2. Golden: RTL (same file list as syn/ch06_chip/genus.tcl)
read design -verilog2k -golden \
        rtl/rv32i_core.v rtl/csr.v rtl/control.v rtl/regfile.v rtl/imm_gen.v \
        rtl/alu.v rtl/branch_cmp.v rtl/lsu.v rtl/bus_mux.v rtl/apb_bridge.v \
        rtl/apb_gpio.v rtl/apb_timer.v rtl/apb_uart.v rtl/rv32i_mcu.v rtl/rv32i_chip.v

// ## STEP 3. Revised: Genus netlist
read design syn.v -verilog -revised

// ## STEP 4. Setup (same flatten options as the Genus dofile): registers that synthesis turned
// into constants are not counted as unmapped, constant-X registers are taken as 0
set flatten model -seq_constant
set flatten model -seq_constant_x_to 0

// pc[1:0] is always 0 in the RTL (reset 0, trap / mret targets have [1:0] = 0, pc + 4 keeps
// [1:0], a jump or branch target with [1:0] != 0 raises jmp_misalign and the pc gets the
// trap target instead). Genus proved this and removed the two flip-flops; LEC does not find
// it (the constant only holds through the register's own feedback), so the RTL bits would be
// free inputs and every point that depends on the pc (pc, register file, CSRs, TRAP) would
// compare as non-equivalent. Constrain them to 0 on the golden side.
// (set flatten model -seq_constant_feedback was tried first and did not remove them)
add instance constraints 0 /u_mcu/u_core/pc_reg[0] -golden
add instance constraints 0 /u_mcu/u_core/pc_reg[1] -golden

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
report compare data -class nonequivalent -class abort > log/rtl2syn_noneq.rpt
