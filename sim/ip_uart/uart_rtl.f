// xrun argument file: UART IP RTL (rtl/ip_uart) + include folders. Paths are relative to the repository
// root -> run xrun from the repository root. The testbench file and -top are given on the command line.
//
// Interactive (SimVision; type 'run' in the console):
//   xrun -f sim/ip_uart/uart_rtl.f -top uart_top_tb sim/ip_uart/uart_top_tb.v -access +rwc -gui \
//        -input sim/ip_uart/uart_probe.tcl -l uart_top_gui.log
// Batch (prints PASS/FAIL):
//   xrun -f sim/ip_uart/uart_rtl.f -top uart_top_tb  sim/ip_uart/uart_top_tb.v  -l uart_top.log
//   xrun -f sim/ip_uart/uart_rtl.f -top uart_fifo_tb sim/ip_uart/uart_fifo_tb.v -l uart_fifo.log
// Both testbenches through the wrapper: bash sim/ip_uart/run_uart_tests.sh
//
// Keep this list in sync with rtl/ip_uart/*.v when modules are added.

-64bit
-timescale 1ns/1ps
-incdir rtl/ip_uart
-incdir sim/ch14a_mcu

rtl/ip_uart/uart_fifo.v
rtl/ip_uart/uart_baud.v
rtl/ip_uart/uart_tx.v
rtl/ip_uart/uart_rx.v
rtl/ip_uart/uart_regs.v
rtl/ip_uart/uart_top.v
