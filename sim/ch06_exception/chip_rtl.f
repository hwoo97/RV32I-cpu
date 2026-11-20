// xrun argument file: the ch6 chip RTL (rv32i_chip = rv32i_mcu + IO pads) with memories on the chip pins (chip_tb)
// Lab-style direct run. Paths are relative to the repository root -> run xrun from the repository root.
// Pad models: the PDK model, found through the environment variable GPDK045_DIR (never copied into the repo).
//
// Interactive (SimVision; type 'run' in the console):
//   xrun -f sim/ch06_exception/chip_rtl.f -access +rwc -gui -input sim/ch06_exception/chip_probe.tcl \
//        +HEX=sim/ch06_exception/tests/hex/irq_timer.hex -l chip_rtl_gui.log
// Batch (one program, prints PASS/FAIL):
//   xrun -f sim/ch06_exception/chip_rtl.f +HEX=sim/riscv-tests-hex/rv32ui_mcu_p/add.hex -l chip_rtl.log
// Same tests through the wrapper: bash sim/ch06_exception/run_chip_tests.sh
//
// Keep this list in sync with rtl/ch06_exception/*.v when modules are added.

-64bit
-timescale 1ns/1ps
-top chip_tb
-incdir rtl/ch06_exception
-incdir sim/ch14a_mcu

rtl/ch06_exception/alu.v
rtl/ch06_exception/apb_bridge.v
rtl/ch06_exception/apb_gpio.v
rtl/ch06_exception/apb_timer.v
rtl/ch06_exception/apb_uart.v
rtl/ch06_exception/branch_cmp.v
rtl/ch06_exception/bus_mux.v
rtl/ch06_exception/control.v
rtl/ch06_exception/csr.v
rtl/ch06_exception/imm_gen.v
rtl/ch06_exception/lsu.v
rtl/ch06_exception/regfile.v
rtl/ch06_exception/rv32i_core.v
rtl/ch06_exception/rv32i_mcu.v
rtl/ch06_exception/mcu_imem.v
rtl/ch06_exception/mcu_dmem.v
rtl/ch06_exception/rv32i_chip.v
${GPDK045_DIR}/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v
sim/ch06_exception/pad_power.v
sim/ch14a_mcu/tohost_mon.v
sim/ch06_exception/chip_tb.v
