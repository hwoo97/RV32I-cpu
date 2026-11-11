#####################################################################
# Worst path per path class (Genus) - shows WHERE the timing is tight, not only the single worst path
#
#   source $env(ROOT)/syn/common/path_groups.tcl
#   report_path_groups <file> {<name> <from> <to>} ...
#
# Each class is one report_timing -max_paths 1 (from / to are Tcl expressions evaluated by Genus,
# e.g. {[all_inputs]} or {[get_ports {ram_rdata[*]}]}; "-" = no restriction). The file gets one
# section per class. Used by genus.tcl STEP 7; can also be run after read_db on a saved design:
#   cd syn/ch14a_mcu/runs/t8ns ; genus
#   source ../../../common/gpdk045.tcl ; read_db mapped/syn_opt.db
#   source ../../../common/path_groups.tcl ; source ../../path_classes.tcl
#####################################################################

proc report_path_groups {file args} {
    set fh [open $file w]
    puts $fh "# Worst path per class (report_timing -max_paths 1)"
    close $fh
    foreach cls $args {
        lassign $cls name from to
        set cmd "report_timing -max_paths 1"
        if {$from ne "-"} { append cmd " -from $from" }
        if {$to   ne "-"} { append cmd " -to $to" }
        set fh [open $file a]
        puts $fh "\n######## CLASS: $name"
        puts $fh "######## $cmd"
        close $fh
        if {[catch {uplevel #0 "$cmd >> $file"} msg]} {
            set fh [open $file a]
            puts $fh "(no path or error: $msg)"
            close $fh
        }
    }
    puts "path classes written to $file"
}
