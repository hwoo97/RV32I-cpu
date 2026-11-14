#####################################################################
# Timing constraints for rv32i_chip (ch6 single-cycle MCU with IO pads) - at the chip pins
#  - CLK_PERIOD is set by the caller: synthesis = TARGET_PERIOD x SYN_MARGIN, PnR = TARGET_PERIOD
#  - Same memory time model as the core SDC (syn/ch06_exception/cons/rv32i_mcu.sdc), but the memories
#    are now OUTSIDE the chip, so each memory access crosses an output pad and an input pad.
#    The pads are inside this design, so their delays are calculated by the tool from the pad library;
#    the budgets below only add room for them at the chip pins:
#
#   pc (flop) -> [out pad] -> IMEM_ADDR pin -[IMEM T_MEM]-> IMEM_DATA pin -> [in pad] -> decode/ALU
#     -> [out pad] -> DADDR pin -[DMEM/IMEM T_MEM]-> RAM_RDATA / IROM_DATA pin -> [in pad] -> lsu/WB -> regs
#
#   T_ADDR_PIN : clock edge -> address valid at the chip pin  (core T_ADDR 0.5 + output pad)
#   T_MEM      : memory read time outside the chip (same assumption as the core SDC: 1.0)
#   T_WB_PIN   : data at the chip pin -> register file input  (core T_WB 1.2 + input pad)
#   T_WSU      : DMEM write setup at the chip pins
#   The pad allowances (2.0 ns out, 1.0 ns in) are first guesses from the pad model (A -> PAD 1.4 ns at
#   the slow corner without load); the timing reports show the real pad delays - adjust them then.
#####################################################################

set T_MEM  1.0
set T_WSU  0.3
if {![info exists T_ADDR_PIN]} {
    set T_ADDR_PIN [expr {[info exists ::env(T_ADDR_PIN)] ? $::env(T_ADDR_PIN) : 2.5}]
}
if {![info exists T_WB_PIN]} {
    set T_WB_PIN [expr {[info exists ::env(T_WB_PIN)] ? $::env(T_WB_PIN) : 2.2}]
}
# board side of the pins
set PAD_LOAD   5.0      ;# load on every output pin (library capacitance unit, pF expected)
set PIN_TRAN   0.5      ;# transition of the signals arriving at the input pins
set T_IO_FRAC  0.5      ;# GPIO / UART outputs: half a cycle for the board

create_clock -name clk -period $CLK_PERIOD [get_ports CLK]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition  0.05 [get_clocks clk]

# Instruction fetch: address at the pin within T_ADDR_PIN, the instruction arrives T_MEM later
set_output_delay [expr {$CLK_PERIOD - $T_ADDR_PIN}]  -clock clk [get_ports {IMEM_ADDR[*]}]
set_input_delay  [expr {$T_ADDR_PIN + $T_MEM}]       -clock clk [get_ports {IMEM_DATA[*]}]

# Data reads (DMEM and the IMEM data-side port share DADDR): T_MEM + T_WB_PIN must remain
set_output_delay [expr {$T_MEM + $T_WB_PIN}]         -clock clk [get_ports {DADDR[*]}]
set_input_delay  [expr {$CLK_PERIOD - $T_WB_PIN}]    -clock clk [get_ports {RAM_RDATA[*] IROM_DATA[*]}]

# DMEM write: ready T_WSU before the next edge
set_output_delay $T_WSU                              -clock clk [get_ports {RAM_WSTRB[*] RAM_WDATA[*]}]

# GPIO (bidirectional, asynchronous inputs through the GPIO synchronizer), UART TX: board budget
set_output_delay [expr {$CLK_PERIOD * $T_IO_FRAC}]   -clock clk [get_ports {GPIO[*] UART_TX}]
# Status outputs (trap, interrupt, bus error, timer irq): observation only
set_output_delay 0.0                                 -clock clk [get_ports {TRAP IRQ_TAKEN BUS_ERR TIMER_IRQ}]

# Asynchronous inputs: reset (synchronized inside), GPIO, UART RX, external interrupt (2-flop synchronizers)
set_false_path -from [get_ports {RST_N GPIO[*] UART_RX EXT_IRQ}]

# Board loads and input transitions
set_load $PAD_LOAD [all_outputs]
set_input_transition $PIN_TRAN [remove_from_collection [all_inputs] [get_ports CLK]]
