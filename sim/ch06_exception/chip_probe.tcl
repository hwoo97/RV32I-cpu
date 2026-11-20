# Xcelium simulator Tcl for interactive runs of chip_tb, RTL and gate-level (xrun -gui -input <this file>)
# - Opens an SHM waveform database and probes every signal in the testbench hierarchy.
# - Does NOT start the simulation: type 'run 1us' or 'run' (until $finish, PASS/FAIL) in the console.
# - Memory arrays are not probed; add them in SimVision when needed.

database -open waves -shm -into waves.shm -default
probe -create chip_tb -all -depth all -database waves
puts "probes ready: type 'run 1us' or 'run' in the console"
