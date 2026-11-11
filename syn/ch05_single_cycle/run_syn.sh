#!/bin/bash
# Genus synthesis of the ch05 single-cycle CPU core (rv32i_core) (school server)
#
# Batch (runs the whole flow, quits, prints an area / slack summary):
#   bash syn/ch05_single_cycle/run_syn.sh            # clock period 10 ns
#   bash syn/ch05_single_cycle/run_syn.sh 5          # clock period 5 ns
#   -> run folder: syn/ch05_single_cycle/runs/clk<period>ns/
# Interactive (opens Genus and waits at the prompt; you enter the steps yourself):
#   bash syn/ch05_single_cycle/run_syn.sh -i         # clock period 10 ns
#   bash syn/ch05_single_cycle/run_syn.sh -i 5
#   -> run folder: syn/ch05_single_cycle/runs/work/ (kept between sessions)
#   -> at the genus prompt: "source $SYN_DIR/genus.tcl" (whole flow, stays open)
#      or copy-paste the STEP 0 .. STEP 8 blocks of genus.tcl one at a time
#
# - Set the GPDK045_DIR environment variable first (csh: setenv GPDK045_DIR <GPDK045 folder>)
# - Run folders (log, report, mapped, unmapped) are not committed

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYN_DIR="$(cd "$(dirname "$0")" && pwd)"

MODE=batch
if [ "$1" = "-i" ]; then MODE=interactive; shift; fi
CLK_PERIOD="${1:-10.0}"

if [ -z "$GPDK045_DIR" ]; then
    echo "ERROR: GPDK045_DIR is not set -> in csh: setenv GPDK045_DIR <GPDK045 folder>, then run again"
    exit 1
fi
export ROOT SYN_DIR CLK_PERIOD

# -- Interactive: open Genus in runs/work and hand over the prompt --
if [ "$MODE" = interactive ]; then
    mkdir -p "$SYN_DIR/runs/work/log" && cd "$SYN_DIR/runs/work" || exit 1
    echo "Genus interactive, folder: $PWD, CLK_PERIOD = $CLK_PERIOD ns"
    echo "  whole flow : source \$env(SYN_DIR)/genus.tcl"
    echo "  step by step: copy-paste STEP 0 .. STEP 8 from $SYN_DIR/genus.tcl"
    export SYN_BATCH=0
    exec genus -log log/genus.log
fi

# -- Batch --
RUN="$SYN_DIR/runs/clk${CLK_PERIOD}ns"
rm -rf "$RUN" && mkdir -p "$RUN/log" && cd "$RUN" || exit 1

export SYN_BATCH=1
echo "Syn Start : $(date)" | tee cds_syn_runtime
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
echo "== Result: $RUN/report =="
echo "-- Area (report_area) --"
grep -E "^\s*rv32i_core\b|^\s*u_" report/09_rv32i_core_area.rpt | head -12
echo "-- Worst path slack (report_timing) --"
grep -iE "slack" report/20_rv32i_core_timing.rpt | head -3
echo "-- Violations (report_constraint) --"
grep -ciE "VIOLATED" report/06_report_constraint.rpt | sed 's/^/violation lines: /'
