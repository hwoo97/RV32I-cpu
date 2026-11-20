// xrun argument file: gate-level simulation of the chip after PnR (PnR netlist + cell / pad models + SDF)
// Lab-style direct run, same as the post-layout run of the lab: the netlist and the SDF of the GUI PnR run
// (pnr/ch06_chip/runs/work/out/) are read in place. Paths are relative to the repository root -> run xrun
// from the repository root. Cell and pad models come through GPDK045_DIR (never copied into the repo).
//
// SDF: add +define+GATE_SDF_SLOW (setup side, MAXIMUM) or +define+GATE_SDF_FAST (hold side, MINIMUM);
//      without either, the netlist runs with no delays. The annotation log is sdf_annotate.log.
// Clock: 13 ns (PnR target), set below with +PERIOD_PS.
//
// Interactive (SimVision; type 'run' in the console):
//   xrun -f sim/ch06_exception/chip_gate.f +define+GATE_SDF_SLOW -access +rwc -gui \
//        -input sim/ch06_exception/chip_probe.tcl +HEX=sim/ch06_exception/tests/hex/irq_timer.hex \
//        -l chip_gate_gui.log
// Batch (one program, prints PASS/FAIL; timing-check violations appear as "Timing violation" in the log):
//   xrun -f sim/ch06_exception/chip_gate.f +define+GATE_SDF_SLOW \
//        +HEX=sim/riscv-tests-hex/rv32ui_mcu_p/add.hex -l chip_gate.log
// All tests, both corners, with a summary: bash sim/ch06_exception/run_chip_gate.sh [--corner fast]

-64bit
-timescale 1ns/1ps
-neg_tchk
-top chip_tb
-incdir rtl/ch06_exception
-incdir sim/ch14a_mcu
+PERIOD_PS=13000
+MAXCYC=400000

pnr/ch06_chip/runs/work/out/rv32i_chip_pnr.v
rtl/ch06_exception/mcu_imem.v
rtl/ch06_exception/mcu_dmem.v
${GPDK045_DIR}/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v
${GPDK045_DIR}/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v
sim/ch06_exception/pad_power.v
sim/ch14a_mcu/tohost_mon.v
sim/ch06_exception/chip_tb.v
