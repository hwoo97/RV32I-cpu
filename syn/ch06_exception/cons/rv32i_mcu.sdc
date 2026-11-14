#####################################################################
# Timing constraints for rv32i_mcu, ch6 (MCU with traps, without memories) - copy of the stage 4 SDC
#  - CLK_PERIOD is set by the caller before sourcing this file:
#      synthesis (genus.tcl): CLK_PERIOD = TARGET_PERIOD x SYN_MARGIN (8 x 0.8 = 6.4 ns)
#      PnR (later)          : CLK_PERIOD = TARGET_PERIOD
#  - Same memory time model as stage 3 (syn/ch05_single_cycle/cons/rv32i_core.sdc), so the two
#    results can be compared. The data port now goes through the address decoder (bus_mux) and
#    reaches either DMEM (ram_*) or the data-side IMEM port (irom_*); both get the same budget.
#
#   One cycle:
#   pc (flop) -> imem_addr -[IMEM read T_MEM]-> imem_rdata -> decode/regfile/ALU -> decoder
#             -> ram_addr / irom_addr -[read T_MEM]-> ram_rdata / irom_rdata -> decoder mux
#             -> lsu extend / WB mux -> register file (flop)
#
#   T_ADDR : time allowed from the pc flop to the imem_addr port
#   T_MEM  : memory read time (assumption, roughly a 45nm SRAM)
#   T_WB   : core time allowed from the memory data input port to the register file input
#   T_WSU  : DMEM write setup (the write happens at the next clock edge)
#####################################################################

set T_ADDR 0.5
set T_MEM  1.0
# T_WB: share of the core logic time AFTER the memory read (the rest of the cycle, minus memory time,
# is the share BEFORE it). It is a split of core time, not a memory speed. 1.0 ns until 2026-11-12;
# 1.2 ns since then for both stage 3 and the MCU (the MCU adds the read-data select of the address
# decoder after the memory). Set T_WB at the prompt or in the environment to try another split.
if {![info exists T_WB]} {
    set T_WB [expr {[info exists ::env(T_WB)] ? $::env(T_WB) : 1.2}]
}
set T_WSU  0.3
# Pins that leave the chip (GPIO, UART): fraction of the cycle given to the outside
set T_IO_FRAC 0.5

create_clock -name clk -period $CLK_PERIOD [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition  0.05 [get_clocks clk]

# Instruction memory (IMEM port A): pc leaves within T_ADDR, the instruction arrives after T_ADDR + T_MEM
set_output_delay [expr {$CLK_PERIOD - $T_ADDR}]  -clock clk [get_ports {imem_addr[*]}]
set_input_delay  [expr {$T_ADDR + $T_MEM}]       -clock clk [get_ports {imem_rdata[*]}]

# Data reads (DMEM and IMEM port B): T_MEM (read) + T_WB (WB path) must remain after the address
set_output_delay [expr {$T_MEM + $T_WB}]         -clock clk [get_ports {ram_addr[*] irom_addr[*]}]
set_input_delay  [expr {$CLK_PERIOD - $T_WB}]    -clock clk [get_ports {ram_rdata[*] irom_rdata[*]}]

# DMEM write: ready T_WSU before the next edge
set_output_delay $T_WSU                          -clock clk [get_ports {ram_wstrb[*] ram_wdata[*]}]

# Chip pins driven by flops (GPIO outputs, UART TX): half a cycle for the pad and board
set_output_delay [expr {$CLK_PERIOD * $T_IO_FRAC}] -clock clk [get_ports {gpio_out[*] gpio_oe[*] uart_tx}]

# Asynchronous inputs: GPIO inputs, UART RX and ext_irq go through 2-flop synchronizers -> no timing relation
set_false_path -from [get_ports {gpio_in[*] uart_rx ext_irq}]

# Observation / error outputs
set_output_delay 0.0                             -clock clk [get_ports {dbg_pc[*] trap irq_taken bus_err timer_irq}]

# Asynchronous reset is excluded from timing analysis
set_false_path -from [get_ports rst_n]

# Input transition and output load
set_input_transition 0.1 [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.01 [all_outputs]
