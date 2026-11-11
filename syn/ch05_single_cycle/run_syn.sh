#!/bin/bash
# Genus synthesis of the ch05 single-cycle CPU core (rv32i_core) (school server)
#
# The argument is the TARGET clock period (what the chip must meet after PnR).
# Synthesis is over-constrained to SYN_MARGIN x target (default 0.8 -> 8 ns target = 6.4 ns synthesis).
#
# Batch (runs the whole flow, quits, prints an area / slack summary):
#   bash syn/ch05_single_cycle/run_syn.sh            # target 8 ns (ch05 target, 125 MHz) -> synthesis 6.4 ns
#   bash syn/ch05_single_cycle/run_syn.sh 5          # target 5 ns  -> synthesis 4 ns
#   -> run folder: syn/ch05_single_cycle/runs/t<target>ns/
#   other margin (csh): env SYN_MARGIN=0.7 bash syn/ch05_single_cycle/run_syn.sh 10
# Interactive (opens Genus and waits at the prompt; you enter the steps yourself):
#   bash syn/ch05_single_cycle/run_syn.sh -i         # target 8 ns
#   bash syn/ch05_single_cycle/run_syn.sh -i 5
#   -> run folder: syn/ch05_single_cycle/runs/work/ (kept between sessions)
#   -> at the genus prompt: "step 0", "step 1", ... "step 8" runs one STEP block of genus.tcl
#      (no copy-paste; see syn/common/steps.tcl), or "source $env(SYN_DIR)/genus.tcl" for all
#
# - Set the GPDK045_DIR environment variable first (csh: setenv GPDK045_DIR <GPDK045 folder>)
# - Run folders (log, report, mapped, unmapped) are not committed

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYN_DIR="$(cd "$(dirname "$0")" && pwd)"

MODE=batch
if [ "$1" = "-i" ]; then MODE=interactive; shift; fi
TARGET_PERIOD="${1:-8}"
SYN_MARGIN="${SYN_MARGIN:-0.8}"
SYN_PERIOD="$(awk -v t="$TARGET_PERIOD" -v m="$SYN_MARGIN" 'BEGIN { printf "%g", t * m }')"

if [ -z "$GPDK045_DIR" ]; then
    echo "ERROR: GPDK045_DIR is not set -> in csh: setenv GPDK045_DIR <GPDK045 folder>, then run again"
    exit 1
fi
export ROOT SYN_DIR TARGET_PERIOD SYN_MARGIN

# -- Interactive: open Genus in runs/work and hand over the prompt --
# genus -f <steps.tcl> loads the step runner and then stays at the prompt
if [ "$MODE" = interactive ]; then
    mkdir -p "$SYN_DIR/runs/work/log" && cd "$SYN_DIR/runs/work" || exit 1
    export SYN_BATCH=0 FLOW_SCRIPT="$SYN_DIR/genus.tcl"
    echo "Genus interactive, folder: $PWD, target $TARGET_PERIOD ns -> synthesis $SYN_PERIOD ns (x $SYN_MARGIN)"
    echo "  step by step : step 0, step 1, ... step 8   (steps = list, show_step <n> = print)"
    echo "  whole flow   : source \$env(SYN_DIR)/genus.tcl"
    exec genus -f "$ROOT/syn/common/steps.tcl" -log log/genus.log
fi

# -- Batch --
RUN="$SYN_DIR/runs/t${TARGET_PERIOD}ns"
rm -rf "$RUN" && mkdir -p "$RUN/log" && cd "$RUN" || exit 1

export SYN_BATCH=1
echo "Target $TARGET_PERIOD ns -> synthesis $SYN_PERIOD ns (x $SYN_MARGIN)" | tee cds_syn_runtime
echo "Syn Start : $(date)" | tee -a cds_syn_runtime
# Progress is shown on screen. stdin is /dev/null so that if the script fails midway,
# Genus exits instead of waiting at its prompt
genus -f "$SYN_DIR/genus.tcl" -log log/genus.log < /dev/null
STATUS=$?
echo "Syn End   : $(date)" | tee -a cds_syn_runtime

# -- Summary --
LOG="$(ls log/genus.log* 2>/dev/null | head -1)"
if [ $STATUS -ne 0 ] || ! grep -q "Synthesis Finished" "$LOG" 2>/dev/null; then
    echo "FAIL: synthesis did not finish (log: $RUN/$LOG)"
    grep -E "^Error|ERROR" "$LOG" 2>/dev/null | head -10
    exit 1
fi
echo ""
echo "== Result: $RUN/report  (target $TARGET_PERIOD ns, synthesized at $SYN_PERIOD ns) =="
echo "-- Area (report_area) --"
grep -E "^\s*rv32i_core\b|^\s*u_" report/09_rv32i_core_area.rpt | head -12
echo "-- Worst path slack (report_timing) --"
grep -iE "slack" report/20_rv32i_core_timing.rpt | head -3
echo "-- Violations (report_constraint) --"
grep -ciE "VIOLATED" report/06_report_constraint.rpt | sed 's/^/violation lines: /'
