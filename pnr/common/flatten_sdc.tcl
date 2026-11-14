#####################################################################
# flatten_sdc <in.sdc> <out.sdc> <var value> ...
#  Evaluates one of the project SDC files (which use Tcl variables such as CLK_PERIOD, T_WB and
#  'if / expr / info exists') in a separate safe interpreter and writes a plain SDC with numbers only.
#  Innovus reads the plain file through the MMMC constraint mode; the project SDC stays the single source.
#  - Object queries (get_ports, get_clocks, all_inputs, ...) are written back as queries
#  - The SDC commands listed below are written with their arguments evaluated
#  - Environment variables of the tool session (e.g. T_WB_PIN) are visible to the SDC as ::env(...)
#####################################################################

proc flatten_sdc {in out args} {
    # a safe interpreter: needs no Tcl library files and cannot touch the tool's own commands
    set ip [interp create -safe]
    $ip eval [list array set ::env [array get ::env]]
    foreach {k v} $args { $ip eval [list set $k $v] }
    $ip eval {
        set ::_out {}
        # one argument as SDC text: a query stays as it is, anything with a space or [ ] is braced
        proc _arg {a} {
            if {[string index $a 0] eq "\["} { return $a }
            if {[regexp {[ \[\]]} $a]} { return "{$a}" }
            return $a
        }
        proc _text {name args} {
            set r [list $name]
            foreach a $args { lappend r [_arg $a] }
            return [join $r " "]
        }
        proc _query {name args} { return "\[[_text $name {*}$args]\]" }
        proc _record {name args} { lappend ::_out [_text $name {*}$args]; return {} }
    }
    foreach q {get_ports get_clocks get_pins get_cells get_nets all_inputs all_outputs all_registers
               remove_from_collection} {
        $ip eval [list interp alias {} $q {} _query $q]
    }
    foreach c {create_clock create_generated_clock set_clock_uncertainty set_clock_transition
               set_clock_latency set_input_delay set_output_delay set_false_path set_multicycle_path
               set_max_delay set_min_delay set_load set_input_transition set_driving_cell
               set_max_transition set_max_fanout set_case_analysis set_dont_touch} {
        $ip eval [list interp alias {} $c {} _record $c]
    }
    set fh [open $in r]
    set text [read $fh]
    close $fh
    $ip eval $text
    set lines [$ip eval {set ::_out}]
    interp delete $ip
    set fh [open $out w]
    puts $fh "# flattened from $in by pnr/common/flatten_sdc.tcl ($args)"
    foreach l $lines { puts $fh $l }
    close $fh
    puts "flatten_sdc: [llength $lines] commands -> $out"
}
