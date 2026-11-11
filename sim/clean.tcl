#!/bin/sh
# Per-folder clean: deletes the tool work files that belong to this folder.  Usage: ./clean.tcl [-n] [-y]
# The same file is used in every work folder (sim/, syn/<chapter>/, pnr/<chapter>/, ec/<chapter>/):
#   target  = first folder under the repo root (sim, syn, pnr, ec)
#   chapter = the folder below it, if any (e.g. ch05_single_cycle)
# The real work is done by tools/clean.tcl. The sh line below restarts this file with tclsh \
for t in tclsh tclsh8.6 tclsh8.5; do command -v $t >/dev/null 2>&1 && exec $t "$0" "$@"; done; echo "clean.tcl: tclsh not found" >&2; exit 1

set here [file dirname [file normalize [info script]]]
set root $here
while {![file exists [file join $root tools clean.tcl]]} {
    set up [file dirname $root]
    if {$up eq $root} { puts stderr "clean.tcl: tools/clean.tcl not found above $here"; exit 1 }
    set root $up
}
set rel [file split [string range $here [expr {[string length $root] + 1}] end]]
set target  [lindex $rel 0]
set chapter [lindex $rel 1]

set ::CLEAN_QUIET 1
source [file join $root tools clean.tcl]
if {$chapter eq ""} {
    clean $target {*}$argv
} else {
    clean $target $chapter {*}$argv
}
