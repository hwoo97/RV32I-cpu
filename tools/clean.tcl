#####################################################################
# clean.tcl - delete tool work files (logs, databases, reports, waveforms) to start over
#
# In a work folder (sim/, syn/<chapter>/, pnr/<chapter>/, ec/<chapter>/) - executable copy there:
#   ./clean.tcl            ;# clean that folder's work files (asks y/N)
#   ./clean.tcl -n         ;# dry run
#   ./clean.tcl -y         ;# no prompt
# From the shell (repository root or anywhere):
#   tclsh tools/clean.tcl syn                     ;# all syn/*/runs + Genus files at the repo root
#   tclsh tools/clean.tcl syn ch05_single_cycle   ;# only syn/ch05_single_cycle/runs
#   tclsh tools/clean.tcl all                     ;# sim + syn + pnr + ec
#   tclsh tools/clean.tcl all -n                  ;# dry run: list only, delete nothing
#   tclsh tools/clean.tcl sim -y                  ;# no confirmation prompt
# From a tool prompt (Genus, Innovus, SimVision Tcl console ...):
#   source <repo>/tools/clean.tcl
#   clean syn -n
#   clean syn
#   (a folder the tool is currently working in is skipped - exit the tool first to remove it)
#
# Targets
#   sim : sim/build/ (xsim, xrun batch/GUI builds) and xrun files left at the repo root
#         (xcelium.d, INCA_libs, *.shm, .simvision, xrun.history, xrun.key, xrun.log, *.diag)
#   syn : syn/<chapter>/runs/ and genus.cmd*, genus.log*, fv/ at the repo root
#   pnr : pnr/<chapter>/runs/ and innovus.cmd*, innovus.log* at the repo root
#   ec  : ec/<chapter>/runs/ and lec log files at the repo root
#
# Safety
#   - Only paths inside the repository are deleted, never the repository root itself
#   - Files tracked by git are never deleted (checked with git ls-files when git is available)
#   - Asks y/N before deleting unless -y is given
# New tool flows must add their output folders here (CLAUDE.md tool script rules).
#####################################################################

namespace eval ::clean {
    variable ROOT [file normalize [file join [file dirname [file normalize [info script]]] ..]]
}

# Paths (globs relative to the repo root) for one target; chapter limits the runs folders
proc ::clean::patterns {target chapter} {
    set ch [expr {$chapter eq "" ? "*" : $chapter}]
    switch -- $target {
        sim {
            if {$chapter ne ""} { return [list sim/build/*] }
            return [list sim/build xcelium.d INCA_libs *.shm .simvision xrun.history xrun.key xrun.log *.diag \
                         sim/*/xcelium.d sim/*/*.shm sim/*/xrun.history sim/*/xrun.log]
        }
        syn { return [concat [list syn/$ch/runs] [expr {$chapter eq "" ? {genus.cmd* genus.log* fv} : {}}]] }
        pnr { return [concat [list pnr/$ch/runs] [expr {$chapter eq "" ? {innovus.cmd* innovus.log* innovus.logv*} : {}}]] }
        ec  { return [concat [list ec/$ch/runs]  [expr {$chapter eq "" ? {lec.log* lec.cmd*} : {}}]] }
        default { error "unknown target '$target' (use sim, syn, pnr, ec, all)" }
    }
}

proc ::clean::tracked {path} {
    variable ROOT
    if {[catch {exec git -C $ROOT ls-files -- $path} out]} { return 0 }
    return [expr {[string trim $out] ne ""}]
}

proc ::clean::collect {targets chapter} {
    variable ROOT
    set found {}
    foreach t $targets {
        foreach pat [patterns $t $chapter] {
            foreach p [glob -nocomplain -directory $ROOT -- $pat] {
                set p [file normalize $p]
                if {$p eq $ROOT || [string first "$ROOT/" $p] != 0} { continue }
                if {[lsearch -exact $found $p] < 0} { lappend found $p }
            }
        }
    }
    return [lsort $found]
}

# Contents of dir that do not contain the cwd (recursing into the one that does)
proc ::clean::around_cwd {dir here} {
    if {$here eq $dir} {
        puts "  skip (tool is working in it, exit the tool first): $dir"
        return {}
    }
    set out {}
    foreach c [glob -nocomplain -directory $dir -- * .*] {
        if {[file tail $c] in {. ..}} { continue }   ;# check before normalize (.. would become the parent)
        set c [file normalize $c]
        if {[string first "$dir/" $c] != 0} { continue }
        if {$here eq $c || [string first "$c/" "$here/"] == 0} {
            set out [concat $out [around_cwd $c $here]]
        } else {
            lappend out $c
        }
    }
    return $out
}

proc ::clean::run {args} {
    variable ROOT
    set dry 0; set yes 0; set pos {}
    foreach a $args {
        switch -- $a {
            -n { set dry 1 }
            -y { set yes 1 }
            default { lappend pos $a }
        }
    }
    if {[llength $pos] < 1} {
        puts "usage: clean <sim|syn|pnr|ec|all> \[chapter\] \[-n (dry run)\] \[-y (no prompt)\]"
        return
    }
    set target [lindex $pos 0]
    set chapter [lindex $pos 1]
    set targets [expr {$target eq "all" ? {sim syn pnr ec} : [list $target]}]

    set here [file normalize [pwd]]
    set del {}
    foreach p [collect $targets $chapter] {
        if {[tracked [string range $p [expr {[string length $ROOT] + 1}] end]]} {
            puts "  keep (tracked by git): $p"
        } elseif {$here eq $p || [string first "$p/" "$here/"] == 0} {
            # The tool runs inside this folder: delete everything except the branch holding the cwd
            set del [concat $del [around_cwd $p $here]]
        } else {
            lappend del $p
        }
    }
    # Final safety pass on every path: inside the repo, not the root, not tracked by git
    set safe {}
    foreach p $del {
        if {$p eq $ROOT || [string first "$ROOT/" $p] != 0} { puts "  refuse (outside repo): $p"; continue }
        if {[tracked [string range $p [expr {[string length $ROOT] + 1}] end]]} { puts "  keep (tracked by git): $p"; continue }
        lappend safe $p
    }
    set del $safe
    if {![llength $del]} { puts "clean $target: nothing to delete"; return }

    puts "clean $target[expr {$chapter ne "" ? " ($chapter)" : ""}]: [llength $del] item(s)"
    foreach p $del { puts "  $p" }
    if {$dry} { puts "dry run (-n): nothing deleted"; return }
    if {!$yes} {
        puts -nonewline "delete these? \[y/N\] "
        flush stdout
        if {[gets stdin ans] < 0 || ![string match -nocase y* $ans]} { puts "cancelled"; return }
    }
    foreach p $del { file delete -force -- $p }
    puts "deleted [llength $del] item(s)"
}

proc clean {args} { ::clean::run {*}$args }

# Run directly from the shell (tclsh tools/clean.tcl ...); when sourced (tool prompt or a
# per-folder clean.tcl), only define 'clean'
if {[info exists ::argv0] && [file normalize $::argv0] eq [file normalize [info script]]} {
    if {[catch {::clean::run {*}$::argv} err]} { puts stderr "clean: $err"; exit 1 }
} elseif {![info exists ::CLEAN_QUIET]} {
    puts "clean ready: clean <sim|syn|pnr|ec|all> \[chapter\] \[-n\] \[-y\]"
}
