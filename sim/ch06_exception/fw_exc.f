// xrun argument file: C firmware (fw/hex/*.hex) on the ch6 mcu_top with the UART decoder (fw_exc_tb)
// Lab-style direct run. Paths are relative to the repository root -> run xrun from the repository root.
//
// Interactive (SimVision; type 'run' in the console, the UART text is printed as "UART| ..."):
//   xrun -f sim/ch06_exception/fw_exc.f -access +rwc -gui -input sim/ch06_exception/fw_exc_probe.tcl \
//        +HEX=fw/hex/hello.hex -l fw_exc_gui.log
// Batch (one program, prints PASS/FAIL):
//   xrun -f sim/ch06_exception/fw_exc.f +HEX=fw/hex/hello.hex -l fw_exc.log
// Same tests through the wrapper: bash sim/ch06_exception/run_fw_tests.sh [--gui hello]
//
// Keep this list in sync with rtl/ch06_exception/*.v when modules are added.

-64bit
-top fw_exc_tb
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
rtl/ch06_exception/mcu_top.v
sim/ch14a_mcu/tohost_mon.v
sim/ch06_exception/fw_exc_tb.v
