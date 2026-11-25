#####################################################################
# dont_use_45nm.tcl - library cells synthesis must not use (gpdk045 gsclib045), lab style:
# sourced by script/rv32i_chip_45nm.tcl after the libraries are read (same list as the lab flow)
#   ANTENNA* : antenna diodes      - inserted by the router only when needed
#   DLY*     : delay cells         - only for hold fixing in PnR
#   HOLD*    : hold buffers        - only for hold fixing in PnR
#   TIE*     : tie-high / tie-low  - inserted in PnR (addTieHiLo), constants stay as 1'b0 / 1'b1 here
#   TLA*     : latches             - the design has no latches; a latch would be a coding error
#   DFFS*    : flops with set      - a reset-to-1 flop is built from a reset flop and inverters
#   SDFF*    : scan flops          - no scan chain in this project
# FILL* and DFFRH* stay allowed (fillers are never chosen by synthesis anyway)
#####################################################################

foreach pattern {ANTENNA* DLY* HOLD* TIE* TLA* DFFS* SDFF*} {
    set cells [get_lib_cells -quiet */$pattern]
    if {[llength $cells] > 0} {
        set_dont_use $cells
    }
    puts "dont_use: $pattern -> [llength $cells] library cells"
}
