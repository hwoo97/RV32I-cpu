#####################################################################
# MMMC (multi-mode multi-corner) view definition for rv32i_chip - read by init_design (init_mmmc_file)
#  - setup: slow corner (std cells slow_vdd1v0, pads SS), hold: fast corner (fast_vdd1v0, pads FF)
#  - one RC corner from the gpdk045 QRC tech file
#  - constraints: the flattened chip SDC written by STEP 0 of innovus.tcl (./pnr.sdc, CLK_PERIOD = target)
#  - library paths come from GPDK045_DIR (never written in the repo)
#####################################################################

set _G   $::env(GPDK045_DIR)/digital
set _STD $_G/gsclib045_all_v4.4/gsclib045
set _PAD $_G/giolib045_v3.5

create_library_set -name libs_slow \
    -timing [list $_STD/timing/slow_vdd1v0_basicCells.lib $_PAD/timing/pads_SS_s1vg.lib]
create_library_set -name libs_fast \
    -timing [list $_STD/timing/fast_vdd1v0_basicCells.lib $_PAD/timing/pads_FF_s1vg.lib]

create_rc_corner -name rc_typ -qx_tech_file $_G/gsclib045_all_v4.4/gsclib045_tech/qrc/qx/gpdk045.tch

create_delay_corner -name dc_slow -library_set libs_slow -rc_corner rc_typ
create_delay_corner -name dc_fast -library_set libs_fast -rc_corner rc_typ

create_constraint_mode -name FUNC -sdc_files [list ./pnr.sdc]

create_analysis_view -name view_slow -constraint_mode FUNC -delay_corner dc_slow
create_analysis_view -name view_fast -constraint_mode FUNC -delay_corner dc_fast

set_analysis_view -setup [list view_slow] -hold [list view_fast]
