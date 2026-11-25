###############################################################
# rv32i_chip_func.sdc - PnR constraints of the RV32I MCU chip with the UART IP (lab style, plain
# numbers), read by rv32i_chip.mmmc.view. Same constraints as the synthesis SDC
# (syn/ch06_uartip/cons/rv32i_chip.sdc) with the target period 13 ns instead of 10.4 ns:
#   address at the pin  2.0 ns after the clock edge, memory read 1.0 ns, pin -> regfile 2.3 ns,
#   DMEM write setup 0.3 ns, GPIO / UART TX half a cycle, status pins observation only.
#  Virtual clock vclk (memory read round trip): latency 0 here; after CTS all.tcl sets it to the
#  measured average clock insertion delay of each view (FUNC_S slow, FUNC_F fast).
###############################################################
current_design rv32i_chip

## Clocks
create_clock -name clk -period 13.000 [get_ports CLK]
set_clock_uncertainty 0.1  [get_clocks clk]
set_clock_transition  0.05 [get_clocks clk]
create_clock -name vclk -period 13.000
set_clock_uncertainty 0.1  [get_clocks vclk]
set_clock_latency -source 0.0 [get_clocks vclk]

## Instruction fetch (vclk)
set_output_delay 11.000 -clock vclk [get_ports {IMEM_ADDR[*]}]         ;# 13.0 - 2.0
set_input_delay   3.000 -clock vclk [get_ports {IMEM_DATA[*]}]         ;# 2.0 + 1.0

## Data reads (vclk)
set_output_delay  3.300 -clock vclk [get_ports {DADDR[*]}]             ;# 1.0 + 2.3
set_input_delay  10.700 -clock vclk [get_ports {RAM_RDATA[*] IROM_DATA[*]}]  ;# 13.0 - 2.3

## DMEM write (clk, board edge)
set_output_delay  0.300 -clock clk [get_ports {RAM_WSTRB[*] RAM_WDATA[*]}]

## GPIO, UART TX: half a cycle for the board. Status outputs: observation only
set_output_delay  6.500 -clock clk [get_ports {GPIO[*] UART_TX}]
set_output_delay  0.000 -clock clk [get_ports {TRAP IRQ_TAKEN BUS_ERR TIMER_IRQ}]

## Asynchronous inputs (synchronized inside): reset, GPIO, UART RX, external interrupt
set_false_path -from [get_ports {RST_N GPIO[*] UART_RX EXT_IRQ}]

## Board loads and input transitions
set_load 5.0 [all_outputs]
set_input_transition 0.5 [remove_from_collection [all_inputs] [get_ports CLK]]
