#!/bin/bash
# Genus synthesis of the ch05 single-cycle CPU core (rv32i_core) (school server)
#
#   bash syn/ch05_single_cycle/run_syn.sh            # clock period 10 ns
#   bash syn/ch05_single_cycle/run_syn.sh 5          # clock period 5 ns
#
# - Set the GPDK045_DIR environment variable first (csh: setenv GPDK045_DIR <GPDK045 folder>)
# - Run folder: syn/ch05_single_cycle/runs/clk<period>ns/ (log, report, mapped, unmapped; not committed)
# - Prints an area / slack summary at the end

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYN_DIR="$(cd "$(dirname "$0")" && pwd)"
CLK_PERIOD="${1:-10.0}"

if [ -z "$GPDK045_DIR" ]; then
    echo "ERROR: GPDK045_DIR is not set -> in csh: setenv GPDK045_DIR <GPDK045 folder>, then run again"
    exit 1
fi

RUN="$SYN_DIR/runs/clk${CLK_PERIOD}ns"
rm -rf "$RUN" && mkdir -p "$RUN/log" && cd "$RUN" || exit 1

export ROOT SYN_DIR CLK_PERIOD
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
