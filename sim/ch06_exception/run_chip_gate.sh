#!/bin/bash
# Gate-level simulation of the chip after PnR (school server, Xcelium): the PnR netlist
# (pnr/ch06_chip/runs/<run>/out/rv32i_chip_pnr.v) + standard-cell and pad models + SDF delays,
# with the same testbench and programs as the RTL chip run (run_chip_tests.sh).
#
# Batch:
#   bash sim/ch06_exception/run_chip_gate.sh                          # slow SDF, rv32ui, rv32mi, trap
#   bash sim/ch06_exception/run_chip_gate.sh --corner fast            # fast SDF (hold side)
#   bash sim/ch06_exception/run_chip_gate.sh --corner none            # no SDF (netlist function only)
#   bash sim/ch06_exception/run_chip_gate.sh trap irq_ext             # one suite, named tests
# Interactive (SimVision, one test):
#   bash sim/ch06_exception/run_chip_gate.sh trap --gui irq_timer
#
# Options (before the suite name):
#   --corner slow|fast|none   SDF corner (default slow)
#   --period <ns>             clock period (default 13 = the PnR target)
# Environment (csh: env NAME=value bash ...):
#   PNR_OUT   folder with rv32i_chip_pnr.v and the SDF files
#             (default pnr/ch06_chip/runs/t13ns/out if it exists, else pnr/ch06_chip/runs/work/out)
#   GPDK045_DIR  GPDK045 folder (cell and pad models are read from it, never copied into the repo)
#
# - Pass: every test prints PASS and no timing-check violation is reported in the run logs
# - SDF: chip_tb.v calls $sdf_annotate when GATE_SDF is defined (slow = MAXIMUM, fast = MINIMUM)
# - Timing checks of the cell models are on (-neg_tchk); violations are counted from the logs
# - Cell models: gsclib045_all_v4.4/gsclib045/verilog (same library folder as the PnR LEF / lib;
#   the lab used the identical copy under gsclib045_svt_v4.4)

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

CORNER=slow
PERIOD=13
while [ $# -gt 0 ]; do
    case "$1" in
        --corner) CORNER="$2"; shift 2 ;;
        --period) PERIOD="$2"; shift 2 ;;
        *) break ;;
    esac
done
case "$CORNER" in slow|fast|none) ;; *) echo "ERROR: --corner must be slow, fast or none"; exit 1 ;; esac

# -- library models (from the PDK, not in the repo) --
if [ -z "$GPDK045_DIR" ]; then
    echo "ERROR: GPDK045_DIR is not set -> in csh: setenv GPDK045_DIR <GPDK045 folder>, then run again"
    exit 1
fi
CELL_V="$GPDK045_DIR/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v"
PAD_V="$GPDK045_DIR/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v"
for f in "$CELL_V" "$PAD_V"; do
    [ -f "$f" ] || { echo "ERROR: model not found: $f"; exit 1; }
done

# -- PnR outputs --
if [ -z "$PNR_OUT" ]; then
    if [ -d "$ROOT/pnr/ch06_chip/runs/t13ns/out" ]; then PNR_OUT="$ROOT/pnr/ch06_chip/runs/t13ns/out"
    else PNR_OUT="$ROOT/pnr/ch06_chip/runs/work/out"; fi
fi
NETLIST="$PNR_OUT/rv32i_chip_pnr.v"
[ -f "$NETLIST" ] || { echo "ERROR: PnR netlist not found: $NETLIST (run STEP 8 of pnr/ch06_chip first)"; exit 1; }
echo "netlist : $NETLIST"

# -- source folder for run_riscv_tests.sh: it compiles RTL_DIR/*.v, so give it a folder with only
#    the PnR netlist and the memory models (the chip RTL must not be compiled) --
SRC="$ROOT/sim/build/chip_gate_src"
rm -rf "$SRC" && mkdir -p "$SRC" || exit 1
ln -s "$NETLIST" "$SRC/rv32i_chip_pnr.v"
for f in mcu_imem.v mcu_dmem.v mcu_memmap.vh; do ln -s "$ROOT/rtl/ch06_exception/$f" "$SRC/$f"; done

XOPTS="-timescale 1ns/1ps -neg_tchk"
if [ "$CORNER" != "none" ]; then
    SDF="$PNR_OUT/rv32i_chip_$CORNER.sdf"
    [ -f "$SDF" ] || { echo "ERROR: SDF not found: $SDF"; exit 1; }
    echo "sdf     : $SDF"
    # same as the lab flow: $sdf_annotate in the testbench, switched on by a define (xrun compiles the SDF)
    XOPTS="$XOPTS +define+GATE_SDF=\"$SDF\""
    [ "$CORNER" = "fast" ] && XOPTS="$XOPTS +define+GATE_SDF_MIN"
fi
PERIOD_PS=$(awk "BEGIN { printf \"%d\", $PERIOD * 1000 }")
echo "corner  : $CORNER, clock period $PERIOD ns"

declare -A SUITES=(
    [rv32ui]="$ROOT/sim/riscv-tests-hex/rv32ui_mcu_p"
    [rv32mi]="$ROOT/sim/riscv-tests-hex/rv32mi_mcu_p"
    [trap]="$ROOT/sim/ch06_exception/tests/hex"
)
if [ -n "$1" ] && [ -n "${SUITES[$1]}" ]; then RUN="$1"; shift; else RUN="rv32ui rv32mi trap"; fi

export RTL_DIR="$SRC"
export TB_FILE="$ROOT/sim/ch06_exception/chip_tb.v"
export TB_TOP="chip_tb"
export EXTRA_SRC="$ROOT/sim/ch14a_mcu/tohost_mon.v $CELL_V $PAD_V $ROOT/sim/ch06_exception/pad_power.v"
export XRUN_OPTS="$XOPTS"
export PLUSARGS="PERIOD_PS=$PERIOD_PS MAXCYC=400000 ${PLUSARGS:-}"
export BUILD_NAME="chip_gate_$CORNER"

RC=0
for s in $RUN; do
    echo "== $s =="
    HEX_DIR="${SUITES[$s]}" bash "$ROOT/sim/run_riscv_tests.sh" "$@" || RC=1
    [ "$1" = "--gui" ] && exit $RC
    # timing-check violations in this suite's run logs
    LOGS=$(ls "$ROOT/sim/build/$BUILD_NAME"/run_*.log 2>/dev/null)
    if [ -n "$LOGS" ]; then
        NV=$(cat $LOGS | grep -c "Timing violation")
        echo "timing-check violations: $NV"
        if [ "$NV" -gt 0 ]; then
            RC=1
            grep -l "Timing violation" $LOGS | head -5
        fi
    fi
done
ANN="$ROOT/sim/build/$BUILD_NAME/sdf_annotate.log"
if [ "$CORNER" != "none" ]; then
    if [ -f "$ANN" ]; then
        echo "SDF annotation: $(grep -c "\*W" "$ANN") warnings, $(grep -c "\*E" "$ANN") errors (log: $ANN)"
    else
        echo "WARNING: no SDF annotation log ($ANN) - check that the SDF was applied (compile.log)"; RC=1
    fi
fi
exit $RC
