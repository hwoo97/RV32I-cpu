# UART IP - post-layout gate simulation, slow corner (FUNC_SS_WORST, max delays)
# Lab style (same form as the lab run_post_max.tcl). Run from this folder (sim/ip_uart) in csh
# after the block PnR (pnr/ip_uart, all.tcl):  source run_post_max.tcl
#
# - copies the PnR netlist and the slow SDF into this folder (not committed)
# - +define+sdf_post_wst : the testbench calls $sdf_annotate("uart_top_slow.sdf", dut, ..., "MAXIMUM")
#                    and moves uart_rx to the falling clock edge (no X from the synchronizer flop)
# - -neg_tchk    : keep negative setup/hold values from the SDF (as in the ch06 chip gate run)
# - the testbench needs no HEX file: it drives the APB bus itself (the lab MCU testbench loaded a program)
# - the cell model is the slow library Verilog; the fast run takes its delays from the fast SDF
# - check: "PASS" summary at $finish, no "Timing violation" lines, sdf_post_wst.log has no *E
# - GPDK045 folder: one variable (csh syntax). In bash, use  GPDK045=/GPDK045  instead
# - -gui opens SimVision (type 'run'); delete the -gui line for a batch run

set GPDK045 = /GPDK045

cp ../../pnr/ip_uart/uart_top_pnr.v ./
cp ../../pnr/ip_uart/uart_top_slow.sdf ./

xrun -64bit      -timescale 1ns/1ps      +max_err_count+50      +define+sdf_post_wst      -neg_tchk      -access +rwc      -gui      -incdir ../../rtl/ip_uart      -incdir ../ch14a_mcu      ./uart_top_tb.v      uart_top_pnr.v      $GPDK045/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v      -top uart_top_tb      -l post_sim_max.log
