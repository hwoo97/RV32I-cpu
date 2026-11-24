# UART IP - RTL function simulation, lab style (same form as the lab run_function.tcl)
# Run from this folder (sim/ip_uart) in the shell (csh):  source run_function.tcl
# or copy the xrun command below and paste it into the shell.
#
# -timescale : time unit / precision
# -access    : read/write access to simulation objects (waveforms in SimVision)
# -gui       : opens SimVision; type 'run' in the console (PASS/FAIL is printed at $finish)
# -incdir    : `include folders (uart_defs.vh, apb_master.vh)
# -top       : testbench top. For the FIFO testbench use -top uart_fifo_tb and uart_fifo_tb.v
#
# Batch run with PASS/FAIL summary (project style): bash run_uart_tests.sh

xrun -64bit \
     -timescale 1ns/1ps \
     +max_err_count+50 \
     -access +rwc \
     -gui \
     -incdir ../../rtl/ip_uart \
     -incdir ../ch14a_mcu \
     ../../rtl/ip_uart/uart_fifo.v \
     ../../rtl/ip_uart/uart_baud.v \
     ../../rtl/ip_uart/uart_tx.v \
     ../../rtl/ip_uart/uart_rx.v \
     ../../rtl/ip_uart/uart_regs.v \
     ../../rtl/ip_uart/uart_top.v \
     ./uart_top_tb.v \
     -top uart_top_tb \
     -l func_sim.log
