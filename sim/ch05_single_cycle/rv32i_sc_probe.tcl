# Xcelium simulator Tcl for interactive runs of rv32i_sc_tb (used with xrun -gui -input <this file>)
# - Opens an SHM waveform database and probes every signal in the testbench hierarchy.
# - Does NOT start the simulation: run it yourself in the SimVision console, e.g.
#     run 200ns        ;# advance 20 cycles (10 ns clock)
#     run              ;# run until $finish (PASS/FAIL)
# - Memory arrays (regfile regs, imem/dmem mem) are not probed by default;
#   add them in SimVision (Design Browser -> select -> Send to Waveform) when needed.

database -open waves -shm -into waves.shm -default
probe -create rv32i_sc_tb -all -depth all -database waves
puts "probes ready: type 'run 200ns' or 'run' in the console"
