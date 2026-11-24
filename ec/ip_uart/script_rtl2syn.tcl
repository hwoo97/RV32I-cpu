// UART IP - Conformal LEC: RTL (golden) vs Genus netlist (revised)
// Lab style (same commands as the lab script_rtl2syn.tcl). Run in ec/ip_uart on the LEC server:
//   lec -xl -dofile script_rtl2syn.tcl      (or start lec -xl and paste the lines one by one)
// Before the first run (see README): mkdir log ; link the cell model into lib/ (PDK, not committed)
// Changes from the lab script: paths, one cell model (slow only - the same cell functions as fast,
//   no pads in the block), include folder for uart_defs.vh, flatten options as in the Genus dofile.

set log file ./log/rtl2syn.log -replace

read library -verilog -both \
	./lib/slow_vdd1v0_basicCells.v

read design -verilog -golden -incdir ../../rtl/ip_uart \
	../../rtl/ip_uart/uart_fifo.v \
	../../rtl/ip_uart/uart_baud.v \
	../../rtl/ip_uart/uart_tx.v \
	../../rtl/ip_uart/uart_rx.v \
	../../rtl/ip_uart/uart_regs.v \
	../../rtl/ip_uart/uart_top.v

read design ../../syn/ip_uart/mapped/uart_top_syn_final.v -verilog -revised

// Registers that synthesis made constant are not reported as unmapped (as in the Genus dofile)
set flatten model -seq_constant
set flatten model -seq_constant_x_to 0

set system mode lec

report unmapped points

add compare points -all

compare

report verification
report statistics
