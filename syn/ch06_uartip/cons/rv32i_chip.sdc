###############################################################
# rv32i_chip.sdc - RV32I MCU chip synthesis constraints, lab style (plain numbers, no variables)
#  Same constraints as the project flow (syn/ch06_chip/cons/rv32i_chip.sdc) with its values filled in.
#  Target clock 13 ns. Synthesis is over-constrained to 13 ns x 0.8 = 10.4 ns so that PnR (real wires,
#  clock tree) can still meet 13 ns. PnR reads the same constraints with 13.0 (pnr/ch06_uartip).
#
#  The memories are OUTSIDE the chip: each memory read crosses an output pad and an input pad.
#   pc (flop) -> [out pad] -> IMEM_ADDR pin -[memory 1.0]-> IMEM_DATA pin -> [in pad] -> decode/ALU
#     -> [out pad] -> DADDR pin -[memory 1.0]-> RAM_RDATA / IROM_DATA pin -> [in pad] -> regs
#   address at the pin  2.0 ns after the clock edge (pc flop + output pad)
#   memory read time    1.0 ns (asynchronous memory, assumption)
#   pin -> regfile      2.3 ns (input pad + load / write-back logic)
#   DMEM write setup    0.3 ns at the pins (memory writes at the board clock edge)
#  Virtual clock vclk: the memory READ round trip is referenced to vclk, whose latency follows the
#  clock arrival at the chip flops (0 here = ideal clock; PnR sets the measured CTS insertion delay).
###############################################################
current_design rv32i_chip

## Clocks
create_clock -name clk -period 10.400 [get_ports CLK]
set_clock_uncertainty 0.1  [get_clocks clk]
set_clock_transition  0.05 [get_clocks clk]
create_clock -name vclk -period 10.400
set_clock_uncertainty 0.1  [get_clocks vclk]
set_clock_latency -source 0.0 [get_clocks vclk]

## Instruction fetch (vclk): address at the pin by 2.0 ns, the instruction arrives 1.0 ns later
set_output_delay 8.400 -clock vclk [get_ports {IMEM_ADDR[*]}]          ;# 10.4 - 2.0
set_input_delay  3.000 -clock vclk [get_ports {IMEM_DATA[*]}]          ;# 2.0 + 1.0

## Data reads (vclk; DMEM and the IMEM data-side port share DADDR): 1.0 + 2.3 must remain
set_output_delay 3.300 -clock vclk [get_ports {DADDR[*]}]              ;# 1.0 + 2.3
set_input_delay  8.100 -clock vclk [get_ports {RAM_RDATA[*] IROM_DATA[*]}]   ;# 10.4 - 2.3

## DMEM write (clk, board edge)
set_output_delay 0.300 -clock clk [get_ports {RAM_WSTRB[*] RAM_WDATA[*]}]

## GPIO, UART TX: half a cycle for the board. Status outputs: observation only
set_output_delay 5.200 -clock clk [get_ports {GPIO[*] UART_TX}]
set_output_delay 0.000 -clock clk [get_ports {TRAP IRQ_TAKEN BUS_ERR TIMER_IRQ}]

## Asynchronous inputs (synchronized inside): reset, GPIO, UART RX, external interrupt
set_false_path -from [get_ports {RST_N GPIO[*] UART_RX EXT_IRQ}]

## Board loads and input transitions
set_load 5.0 [all_outputs]
set_input_transition 0.5 [remove_from_collection [all_inputs] [get_ports CLK]]
