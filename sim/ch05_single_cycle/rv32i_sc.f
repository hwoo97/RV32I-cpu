// xrun argument file for the single-cycle CPU testbench (rv32i_sc_tb)
// Paths are relative to the repository root -> run xrun from the repository root.
//
// Interactive (SimVision, step through with "run 100ns" etc.):
//   xrun -f sim/ch05_single_cycle/rv32i_sc.f -access +rwc -gui \
//        -input sim/ch05_single_cycle/rv32i_sc_probe.tcl \
//        +HEX=sim/riscv-tests-hex/rv32ui/add.hex
// Batch (one test, prints PASS/FAIL):
//   xrun -f sim/ch05_single_cycle/rv32i_sc.f +HEX=sim/riscv-tests-hex/rv32ui/add.hex
//
// Keep this list in sync with rtl/ch05_single_cycle/*.v when modules are added.

-64bit
-top rv32i_sc_tb
-incdir rtl/ch05_single_cycle

rtl/ch05_single_cycle/rv32i_sc.v
rtl/ch05_single_cycle/rv32i_core.v
rtl/ch05_single_cycle/control.v
rtl/ch05_single_cycle/regfile.v
rtl/ch05_single_cycle/imm_gen.v
rtl/ch05_single_cycle/alu.v
rtl/ch05_single_cycle/branch_cmp.v
rtl/ch05_single_cycle/lsu.v
rtl/ch05_single_cycle/imem.v
rtl/ch05_single_cycle/dmem.v
sim/ch05_single_cycle/rv32i_sc_tb.v
