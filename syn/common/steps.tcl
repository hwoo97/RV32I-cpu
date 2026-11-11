#####################################################################
# Step runner for interactive tool sessions (Genus now, Innovus later)
#  - Runs one "## STEP <n>. ..." block of a flow script without copy-paste:
#      step 0          ;# run STEP 0 of the flow script
#      step 4          ;# run STEP 4
#      steps           ;# list the STEP titles
#      show_step 5     ;# print STEP 5 without running it
#  - The flow script is $FLOW_SCRIPT (set by the wrapper, e.g. run_syn.sh -i),
#    or give it explicitly: step 3 /path/to/genus.tcl
#  - A block runs at global level, the same as typing it at the prompt.
#    A block ends at the next "## STEP" line or the end of the file.
#####################################################################

if {![info exists FLOW_SCRIPT]} {
    if {[info exists ::env(FLOW_SCRIPT)]} {
        set FLOW_SCRIPT $::env(FLOW_SCRIPT)
    } elseif {[info exists ::env(SYN_DIR)]} {
        set FLOW_SCRIPT $::env(SYN_DIR)/genus.tcl
    }
}

# Returns a dict: step number -> {title body}
proc _read_steps {script} {
    set f [open $script r]
    set lines [split [read $f] "\n"]
    close $f
    set blocks [dict create]
    set cur ""
    foreach l $lines {
        if {[regexp {^## STEP (\d+)\.\s*(.*)$} $l -> k title]} {
            set cur $k
            dict set blocks $cur [list $title {}]
            continue
        }
        if {$cur ne ""} {
            lassign [dict get $blocks $cur] title body
            dict set blocks $cur [list $title [concat $body [list $l]]]
        }
    }
    return $blocks
}

proc _flow_script {script} {
    if {$script ne ""} { return $script }
    if {[info exists ::FLOW_SCRIPT]} { return $::FLOW_SCRIPT }
    error "no flow script: set FLOW_SCRIPT <path to genus.tcl> or use: step <n> <path>"
}

proc steps {{script ""}} {
    set script [_flow_script $script]
    puts "steps in $script:"
    dict for {k v} [_read_steps $script] { puts "  step $k  : [lindex $v 0]" }
}

proc show_step {n {script ""}} {
    set script [_flow_script $script]
    set blocks [_read_steps $script]
    if {![dict exists $blocks $n]} { error "STEP $n not found in $script" }
    puts [join [lindex [dict get $blocks $n] 1] "\n"]
}

proc step {n {script ""}} {
    set script [_flow_script $script]
    set blocks [_read_steps $script]
    if {![dict exists $blocks $n]} { error "STEP $n not found in $script" }
    lassign [dict get $blocks $n] title body
    puts "==== STEP $n. $title ===="
    uplevel #0 [join $body "\n"]
    puts "==== STEP $n done ===="
}

if {[info exists FLOW_SCRIPT]} {
    puts "step runner ready: flow script = $FLOW_SCRIPT"
    puts "  steps / show_step <n> / step <n>   (start with: step 0)"
}
