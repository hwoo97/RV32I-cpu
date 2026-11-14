#!/bin/bash
# Innovus place and route of the ch6 single-cycle MCU chip (rv32i_chip with IO pads) (school server)
#
# The argument is the TARGET clock period; the chip netlist comes from the synthesis run of the
# same target: syn/ch06_chip/runs/t<target>ns/mapped/rv32i_chip_syn_final.v (run run_syn.sh first),
# or set NETLIST (csh: env NETLIST=<file> bash pnr/ch06_chip/run_pnr.sh 12)
#
# Batch (no window, whole flow, quits, prints a summary):
#   bash pnr/ch06_chip/run_pnr.sh                 # target 12 ns
#   bash pnr/ch06_chip/run_pnr.sh 14
#   -> run folder: pnr/ch06_chip/runs/t<target>ns/
# GUI (needs an X display: MobaXterm with X11 forwarding):
#   bash pnr/ch06_chip/run_pnr.sh --gui           # Innovus window, the whole flow runs in it (watch the
#                                                 # pads, power grid, placement, clock tree, routing appear);
#                                                 # stays open at the end
#   bash pnr/ch06_chip/run_pnr.sh -i --gui        # window + prompt: step 0 ... step 8 yourself
#   bash pnr/ch06_chip/run_pnr.sh -i              # prompt only (no window)
#   -> run folder: pnr/ch06_chip/runs/work/
#   -> restart from a saved step: restoreDesign dbs/04_place.dat rv32i_chip ; step 5 ...
#
# - Set GPDK045_DIR first (csh: setenv GPDK045_DIR <GPDK045 folder>)
# - Run folders (dbs, report, out, logs) are not committed

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PNR_DIR="$(cd "$(dirname "$0")" && pwd)"

MODE=batch
GUI=0
while [ $# -gt 0 ]; do
    case "$1" in
        -i)    MODE=interactive; shift ;;
        --gui) GUI=1; shift ;;
        *)     break ;;
    esac
done
TARGET_PERIOD="${1:-12}"

if [ -z "$GPDK045_DIR" ]; then
    echo "ERROR: GPDK045_DIR is not set -> in csh: setenv GPDK045_DIR <GPDK045 folder>, then run again"
    exit 1
fi
NETLIST="${NETLIST:-$ROOT/syn/ch06_chip/runs/t${TARGET_PERIOD}ns/mapped/rv32i_chip_syn_final.v}"
if [ ! -f "$NETLIST" ]; then
    echo "ERROR: chip netlist not found: $NETLIST"
    echo "       run: bash syn/ch06_chip/run_syn.sh $TARGET_PERIOD   (or set NETLIST)"
    exit 1
fi
if [ "$GUI" = 1 ] && [ -z "$DISPLAY" ]; then
    echo "ERROR: --gui needs an X display (DISPLAY is empty). Use MobaXterm with X11 forwarding, then run again"
    exit 1
fi
export ROOT PNR_DIR TARGET_PERIOD NETLIST
WIN="-nowin"; [ "$GUI" = 1 ] && WIN=""

# -- Interactive / GUI: runs/work --
if [ "$MODE" = interactive ] || [ "$GUI" = 1 ]; then
    mkdir -p "$PNR_DIR/runs/work/log" && cd "$PNR_DIR/runs/work" || exit 1
    export PNR_BATCH=0 FLOW_SCRIPT="$PNR_DIR/innovus.tcl"
    if [ "$MODE" = interactive ]; then
        echo "Innovus interactive${WIN:- with GUI}, folder: $PWD, target $TARGET_PERIOD ns"
        echo "  step by step : step 0, step 1, ... step 8   (steps = list, show_step <n> = print)"
        echo "  whole flow   : source \$env(PNR_DIR)/innovus.tcl"
        exec innovus $WIN -files "$ROOT/syn/common/steps.tcl" -log log/innovus.log
    fi
    printf 'source %s\nsource %s\n' "$ROOT/syn/common/steps.tcl" "$PNR_DIR/innovus.tcl" > gui_run.tcl
    echo "Innovus GUI run, folder: $PWD, target $TARGET_PERIOD ns"
    echo "  the whole flow runs in the window; Innovus stays open at the end (type exit to close)"
    exec innovus -files gui_run.tcl -log log/innovus.log
fi

# -- Batch --
RUN="$PNR_DIR/runs/t${TARGET_PERIOD}ns"
rm -rf "$RUN" && mkdir -p "$RUN/log" && cd "$RUN" || exit 1
export PNR_BATCH=1
echo "PnR target $TARGET_PERIOD ns, netlist $NETLIST" | tee pnr_runtime
echo "PnR Start : $(date)" | tee -a pnr_runtime
innovus -nowin -files "$PNR_DIR/innovus.tcl" -log log/innovus.log < /dev/null
STATUS=$?
echo "PnR End   : $(date)" | tee -a pnr_runtime

LOG="$(ls log/innovus.log* 2>/dev/null | head -1)"
if [ $STATUS -ne 0 ] || ! grep -q "PnR Finished" $LOG 2>/dev/null; then
    echo "FAIL: PnR did not finish (log: $RUN/log)"
    grep -E "^\*\*ERROR" $LOG 2>/dev/null | head -10
    exit 1
fi
echo ""
echo "== Result: $RUN  (target $TARGET_PERIOD ns) =="
echo "-- Setup / hold (final, timeDesign summary) --"
for d in final final_hold; do
    f="$(ls report/timing/$d/*.summary* 2>/dev/null | head -1)"
    [ -n "$f" ] && { echo "[$d]"; grep -E "WNS|TNS|Violating Paths" "$f" | head -6; }
done
echo "-- DRC / connectivity --"
tail -3 report/07_finish.drc.rpt 2>/dev/null
grep -iE "total|violation" report/07_finish.conn.rpt 2>/dev/null | head -3
echo "-- Area / cells --"
grep -iE "core area|chip area|total area|gate count|instances" report/07_summary.rpt 2>/dev/null | head -8
