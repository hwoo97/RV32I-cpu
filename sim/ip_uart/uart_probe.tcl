# Xcelium simulator Tcl for interactive runs of the UART IP testbenches (xrun -gui -input <this file>)
# - Opens an SHM waveform database and probes every signal below the testbench top.
# - Does NOT start the simulation: type 'run 100us' or 'run' (until $finish, PASS/FAIL) in the console.

database -open waves -shm -into waves.shm -default
probe -create [scope -tops] -all -depth all -database waves
puts "probes ready: type 'run 100us' or 'run' in the console"
