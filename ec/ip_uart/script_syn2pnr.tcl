// UART IP - Conformal LEC: Genus netlist (golden) vs Innovus netlist (revised)
// Lab style (same commands as the lab script_syn2pnr.tcl). Run in ec/ip_uart on the LEC server:
//   lec -xl -dofile script_syn2pnr.tcl      (or start lec -xl and paste the lines one by one)
// Before the first run (see README): mkdir log ; link the cell model into lib/ (PDK, not committed)
// The PnR netlist is the hierarchical one (pnr/ip_uart/all.tcl saveNetlist, no -flat);
// CTS / hold buffers and resized cells sit inside the combinational logic and add no compare points.

set log file ./log/syn2pnr.log -replace

read library -verilog -both \
	./lib/slow_vdd1v0_basicCells.v

read design ../../syn/ip_uart/mapped/uart_top_syn_final.v -verilog -golden

read design ../../pnr/ip_uart/uart_top_pnr.v -verilog -revised

set system mode lec

report unmapped points

add compare points -all

compare

report verification
report statistics
