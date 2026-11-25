# RV32I MCU chip with the UART IP - pre-layout gate simulation (Genus netlist + Genus SDF, slow cells,
# no wires). Lab style (same form as the lab run_pre.tcl). Run from this folder (sim/ch06_uartip) in
# csh after synthesis (syn/ch06_uartip, run_synthesis):  source run_pre.tcl
#
# - copies the synthesized netlist and the Genus SDF into this folder (not committed)
# - +define+GATE_SDF : chip_tb calls $sdf_annotate(<file>, dut, ..., "MAXIMUM") (slow corner)
# - -neg_tchk        : keep negative setup / hold values from the SDF
# - +PERIOD_PS=13000 : the 13 ns target clock (synthesis used 10.4 ns, the PnR target is 13 ns)
# - memories (mcu_imem / mcu_dmem) stay behavioral models outside the chip, as in the RTL run
# - compare with the RTL run (run_function.tcl): same PASS line and the same program; in the waveform
#   the chip outputs (IMEM_ADDR, DADDR, UART_TX, ...) move a little after the clock edge
#   (flip-flop clk -> q + output pad delay from the SDF)
# - check: PASS line, no "Timing violation" lines, sdf_annotate.log has no *E,
#   xmelab SDF statistics "Annotated" close to 100 % and no SDFINF warnings
# - GPDK045 folder: one variable (csh syntax). In bash, use  GPDK045=/GPDK045  instead
# - -gui opens SimVision (type 'run'); delete the -gui line for a batch run

set GPDK045 = /GPDK045
set HEX = ./tests/hex/uart_irq.hex

cp ../../syn/ch06_uartip/mapped/rv32i_chip_syn_final.v ./
cp ../../syn/ch06_uartip/mapped/rv32i_chip_delays.sdf ./

xrun -64bit \
     -timescale 1ns/1ps \
     +max_err_count+50 \
     +define+GATE_SDF=\"rv32i_chip_delays.sdf\" \
     -neg_tchk \
     -access +rwc \
     -gui \
     -incdir ../../rtl/ch06_uartip \
     -incdir ../ch14a_mcu \
     ./rv32i_chip_syn_final.v \
     ../../rtl/ch06_uartip/mcu_imem.v \
     ../../rtl/ch06_uartip/mcu_dmem.v \
     $GPDK045/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v \
     $GPDK045/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v \
     ../ch06_exception/pad_power.v \
     ../ch14a_mcu/tohost_mon.v \
     ../ch06_exception/chip_tb.v \
     -top chip_tb \
     +HEX=$HEX \
     +PERIOD_PS=13000 \
     +MAXCYC=400000 \
     -l pre_sim.log
