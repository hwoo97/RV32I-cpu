#####################################################################
# gpdk045 library setup (shared by Genus scripts) - sourced by each chapter's genus.tcl
#  - The PDK location is not written in the public repo; it comes from the GPDK045_DIR environment variable
#    (GPDK045 folder = the folder that contains digital/gsclib045_all_v4.4/)
#    csh:  setenv GPDK045_DIR <absolute path of the GPDK045 folder>
#  - Errors use 'error' (not exit) so an interactive Genus session stays open
#  - Corner: slow (worst case) only, for setup timing
#  - USE_PHYS = 1 also reads LEF and QRC for a more realistic wire delay estimate (default 1)
#####################################################################

if {![info exists ::env(GPDK045_DIR)]} {
    error "environment variable GPDK045_DIR is not set (csh: setenv GPDK045_DIR <GPDK045 folder>)"
}
set GPDK      $::env(GPDK045_DIR)
set STD_DIR   $GPDK/digital/gsclib045_all_v4.4/gsclib045
set TECH_DIR  $GPDK/digital/gsclib045_all_v4.4/gsclib045_tech

set LIB_SEARCH [list $STD_DIR/timing $STD_DIR/lef $TECH_DIR/lef $TECH_DIR/qrc/qx]
set LIB_LIST   {slow_vdd1v0_basicCells.lib}
set LEF_LIST   {gsclib045_tech.lef gsclib045_macro.lef}
set QRC_LIST   {gpdk045.tch}

if {![file exists $STD_DIR/timing/[lindex $LIB_LIST 0]]} {
    error "$STD_DIR/timing/[lindex $LIB_LIST 0] not found - check GPDK045_DIR"
}

set USE_PHYS [expr {[info exists ::env(USE_PHYS)] ? $::env(USE_PHYS) : 1}]

set_db init_lib_search_path $LIB_SEARCH
read_libs $LIB_LIST
if {$USE_PHYS} {
    read_physical -lef $LEF_LIST
    read_qrc $QRC_LIST
}
