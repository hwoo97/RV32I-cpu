# RV32I MCU chip with the UART IP (rtl/ch06_uartip: rv32i_chip = rv32i_mcu + IO pads, UART = rtl/ip_uart)
# RTL function simulation, lab style (same form as the lab run_function.tcl). Run from this folder
# (sim/ch06_uartip) in csh:
#   source run_function.tcl          (or copy the xrun command below into the shell)
#
# -timescale : time unit / precision
# -access    : read/write access to simulation objects (waveforms in SimVision)
# -gui       : opens SimVision; type 'run' in the console (PASS/FAIL is printed at the end)
# -incdir    : `include folders (rv32i_defs.vh, mcu_memmap.vh, uart_defs.vh)
# +HEX       : program loaded into the instruction memory (outside the chip, in chip_tb)
#              uart_irq.hex  : UART IP through the pins (UART_RX = UART_TX), RX interrupt -> handler
#                              -> RXDATA read -> mret (default)
#              ../ch06_exception/tests/hex/irq_timer.hex : timer interrupt,  irq_ext.hex : external
#              interrupt (GPIO[15]),  bus_fault.hex : bus error trap
#              any riscv-tests hex (sim/riscv-tests-hex/rv32ui_mcu_p/*.hex) also works
# Pad models : the PDK signal-pad model (pads_SS_s1vg.v) + pad_power.v (power pads, written here)
#
# Batch regression of all programs (PC xsim): python sim/ch06_uartip/run_chip_tests.py

set GPDK045 = /GPDK045
set HEX = ./tests/hex/uart_irq.hex

xrun -64bit \
     -timescale 1ns/1ps \
     +max_err_count+50 \
     -access +rwc \
     -gui \
     -incdir ../../rtl/ch06_uartip \
     -incdir ../../rtl/ip_uart \
     -incdir ../ch14a_mcu \
     ../../rtl/ch06_uartip/alu.v \
     ../../rtl/ch06_uartip/apb_bridge.v \
     ../../rtl/ch06_uartip/apb_gpio.v \
     ../../rtl/ch06_uartip/apb_timer.v \
     ../../rtl/ch06_uartip/branch_cmp.v \
     ../../rtl/ch06_uartip/bus_mux.v \
     ../../rtl/ch06_uartip/control.v \
     ../../rtl/ch06_uartip/csr.v \
     ../../rtl/ch06_uartip/imm_gen.v \
     ../../rtl/ch06_uartip/lsu.v \
     ../../rtl/ch06_uartip/regfile.v \
     ../../rtl/ch06_uartip/rv32i_core.v \
     ../../rtl/ch06_uartip/rv32i_mcu.v \
     ../../rtl/ch06_uartip/mcu_imem.v \
     ../../rtl/ch06_uartip/mcu_dmem.v \
     ../../rtl/ch06_uartip/rv32i_chip.v \
     ../../rtl/ip_uart/uart_fifo.v \
     ../../rtl/ip_uart/uart_baud.v \
     ../../rtl/ip_uart/uart_tx.v \
     ../../rtl/ip_uart/uart_rx.v \
     ../../rtl/ip_uart/uart_regs.v \
     ../../rtl/ip_uart/uart_top.v \
     $GPDK045/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v \
     ../ch06_exception/pad_power.v \
     ../ch14a_mcu/tohost_mon.v \
     ../ch06_exception/chip_tb.v \
     -top chip_tb \
     +HEX=$HEX \
     -l func_sim.log
