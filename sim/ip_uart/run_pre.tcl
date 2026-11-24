# UART IP - pre-layout gate simulation (Genus netlist + Genus SDF, slow library, no wires)
# Lab style (same form as the lab run_pre.tcl). Run from this folder (sim/ip_uart) in csh
# after synthesis (syn/ip_uart, run_synthesis):  source run_pre.tcl
#
# - copies the synthesized netlist and the Genus SDF into this folder (not committed)
# - +define+sdf_gate : the testbench calls $sdf_annotate("uart_top_delays.sdf", dut, ..., "MAXIMUM")
#                      and uses the gate-run timing (APB inputs 1.5 ns after the rising edge,
#                      uart_rx moved to the falling edge) - same as run_post_max.tcl
# - -neg_tchk        : keep negative setup/hold values from the SDF
# - compare with the RTL run (run_function.tcl): same PASS line, and in the waveform the outputs
#   of the flip-flops move a little after the clock edge (clk -> q and gate delays from the SDF)
# - check: "PASS" summary at $finish, no "Timing violation" lines, sdf_gate.log has no *E,
#   SDF statistics "Annotated" close to 100 % and no SDFINF warnings
# - GPDK045 folder: one variable (csh syntax). In bash, use  GPDK045=/GPDK045  instead
# - -gui opens SimVision (type 'run'); delete the -gui line for a batch run

set GPDK045 = /GPDK045

cp ../../syn/ip_uart/mapped/uart_top_syn_final.v ./
cp ../../syn/ip_uart/mapped/uart_top_delays.sdf ./

xrun -64bit \
     -timescale 1ns/1ps \
     +max_err_count+50 \
     +define+sdf_gate \
     -neg_tchk \
     -access +rwc \
     -gui \
     -incdir ../../rtl/ip_uart \
     -incdir ../ch14a_mcu \
     ./uart_top_tb.v \
     uart_top_syn_final.v \
     $GPDK045/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
     -top uart_top_tb \
     -l pre_sim.log
