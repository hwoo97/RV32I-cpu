#####################################################################
# gpdk045 라이브러리 설정 (Genus 공통) — 장별 genus.tcl이 source 한다
#  - PDK 위치는 공개 저장소에 적지 않고 환경 변수 GPDK045_DIR로 받는다
#    (GPDK045 폴더 = 그 아래에 digital/gsclib045_all_v4.4/ 가 있는 폴더)
#    csh:  setenv GPDK045_DIR <GPDK045 폴더의 절대 경로>
#  - 코너: slow(최악) 한 가지로 setup 타이밍을 본다
#  - USE_PHYS = 1이면 LEF·QRC도 읽어 배선 지연을 더 현실적으로 추정 (기본 1)
#####################################################################

if {![info exists ::env(GPDK045_DIR)]} {
    puts "ERROR: 환경 변수 GPDK045_DIR가 없음 (csh: setenv GPDK045_DIR <GPDK045 폴더>)"
    exit 1
}
set GPDK      $::env(GPDK045_DIR)
set STD_DIR   $GPDK/digital/gsclib045_all_v4.4/gsclib045
set TECH_DIR  $GPDK/digital/gsclib045_all_v4.4/gsclib045_tech

set LIB_SEARCH [list $STD_DIR/timing $STD_DIR/lef $TECH_DIR/lef $TECH_DIR/qrc/qx]
set LIB_LIST   {slow_vdd1v0_basicCells.lib}
set LEF_LIST   {gsclib045_tech.lef gsclib045_macro.lef}
set QRC_LIST   {gpdk045.tch}

if {![file exists $STD_DIR/timing/[lindex $LIB_LIST 0]]} {
    puts "ERROR: $STD_DIR/timing/[lindex $LIB_LIST 0] 이 없음 — GPDK045_DIR 확인"
    exit 1
}

set USE_PHYS [expr {[info exists ::env(USE_PHYS)] ? $::env(USE_PHYS) : 1}]

set_db init_lib_search_path $LIB_SEARCH
read_libs $LIB_LIST
if {$USE_PHYS} {
    read_physical -lef $LEF_LIST
    read_qrc $QRC_LIST
}
