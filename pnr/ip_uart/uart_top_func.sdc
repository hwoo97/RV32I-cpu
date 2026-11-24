###############################################################
# uart_top_func.sdc - UART IP PnR constraints (lab style, hand written), read by uart_top.mmmc.view
#  Target clock 200 MHz (5 ns) - the period PnR must meet. Same as syn/ip_uart/cons/uart_top.sdc
#  except the period (synthesis uses 4.0 ns = 5 ns x 0.8) and the IO delays (30 % of the period).
#  APB inputs / outputs: 30 % of the period for the logic outside the block (assumption).
#  uart_rx is asynchronous (2-flop synchronizer inside): no timing path from it.
###############################################################
current_design uart_top

## Clock (same form as the lab SDC)
create_clock [get_ports {pclk}] -name PCLK -period 5.000 -waveform {0.000 2.500}
set_clock_latency -source -early -max 0.2 [get_clocks {PCLK}]
set_clock_latency -source -late  -max 0.2 [get_clocks {PCLK}]
set_clock_transition -rise -min 0.1 [get_clocks {PCLK}]
set_clock_transition -rise -max 0.1 [get_clocks {PCLK}]
set_clock_transition -fall -min 0.1 [get_clocks {PCLK}]
set_clock_transition -fall -max 0.1 [get_clocks {PCLK}]
set_clock_uncertainty -setup 0.1 [get_clocks {PCLK}]
set_clock_uncertainty -hold  0.05 [get_clocks {PCLK}]

## Inputs: driven by a buffer, arrive 30 % into the period
set_driving_cell -lib_cell BUFX2 -pin Y [remove_from_collection [all_inputs] [get_ports {pclk uart_rx}]]
set_input_delay -clock PCLK -max 1.500 [remove_from_collection [all_inputs] [get_ports {pclk uart_rx}]]
set_input_delay -clock PCLK -min 0.100 [remove_from_collection [all_inputs] [get_ports {pclk uart_rx}]]

## Outputs: 30 % of the period used outside, load 3 fF (same load as the lab SDC)
set_output_delay -clock PCLK -max 1.500 [all_outputs]
set_output_delay -clock PCLK -min 0.100 [all_outputs]
set_load -pin_load -max 0.003 [all_outputs]
set_load -pin_load -min 0.003 [all_outputs]

## Asynchronous serial input (synchronized inside)
set_false_path -from [get_ports {uart_rx}]
