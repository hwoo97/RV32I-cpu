#####################################################################
# Timing constraints for rv32i_core (ch05 single cycle)
#  - CLK_PERIOD is set by the caller before sourcing this file:
#      synthesis (genus.tcl): CLK_PERIOD = TARGET_PERIOD x SYN_MARGIN (ch05 target 8 x 0.8 = 6.4 ns)
#      PnR (later)          : CLK_PERIOD = TARGET_PERIOD (the real target, with propagated clocks)
#  - Memories are outside the core, so the memory access time is split into I/O delays (see README sec. 2-1)
#
#   What happens in one cycle (single cycle):
#   pc (flop) -> imem_addr -[imem read T_MEM]-> imem_rdata -> decode/regfile/ALU -> dmem_addr
#             -[dmem read T_MEM]-> dmem_rdata -> lsu extend / WB mux -> register file (flop)
#
#   T_ADDR : time allowed from the pc flop to the imem_addr port
#   T_MEM  : memory read time (assumption, roughly a 45nm 8 KB SRAM)
#   T_WB   : core time allowed from the dmem_rdata port to the register file input
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
set T_WSU  0.3     ;# dmem write setup (the write happens at the next clock edge)

create_clock -name clk -period $CLK_PERIOD [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition  0.05 [get_clocks clk]

# Instruction memory: pc leaves the port within T_ADDR, the instruction arrives after T_ADDR + T_MEM
set_output_delay [expr {$CLK_PERIOD - $T_ADDR}]  -clock clk [get_ports {imem_addr[*]}]
set_input_delay  [expr {$T_ADDR + $T_MEM}]       -clock clk [get_ports {imem_rdata[*]}]

# Data memory read: T_MEM (read) + T_WB (WB path) must remain after dmem_addr
set_output_delay [expr {$T_MEM + $T_WB}]         -clock clk [get_ports {dmem_addr[*] dmem_re}]
set_input_delay  [expr {$CLK_PERIOD - $T_WB}]    -clock clk [get_ports {dmem_rdata[*]}]

# Data memory write: before T_WSU ahead of the next edge
set_output_delay $T_WSU                          -clock clk [get_ports {dmem_wstrb[*] dmem_wdata[*]}]

# Observation outputs
set_output_delay 0.0                             -clock clk [get_ports {dbg_pc[*] trap}]

# Asynchronous reset is excluded from timing analysis
set_false_path -from [get_ports rst_n]

# Input transition and output load
set_input_transition 0.1 [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.01 [all_outputs]
