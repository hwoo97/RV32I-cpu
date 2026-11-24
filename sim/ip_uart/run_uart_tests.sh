#!/bin/bash
# Runs the UART IP testbenches with Xcelium (school server). PC xsim version: python sim/ip_uart/run_uart_tests.py
#
# Batch (both testbenches, PASS/FAIL summary):
#   bash sim/ip_uart/run_uart_tests.sh
#   bash sim/ip_uart/run_uart_tests.sh uart_top_tb          # one testbench
# Interactive (SimVision, waves probed by uart_probe.tcl; type 'run' in the console):
#   bash sim/ip_uart/run_uart_tests.sh --gui uart_top_tb
#
# Build folders and logs: sim/build/<testbench>/ (git-ignored). Runs in bash even if the login shell is csh.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUI=0
TBS=()
for a in "$@"; do
    if [ "$a" = "--gui" ]; then GUI=1; else TBS+=("$a"); fi
done
[ ${#TBS[@]} -eq 0 ] && TBS=(uart_fifo_tb uart_top_tb)

RC=0
for tb in "${TBS[@]}"; do
    src="$ROOT/sim/ip_uart/$tb.v"
    [ -f "$src" ] || { echo "ERROR: no testbench $src"; exit 1; }
    build="$ROOT/sim/build/$tb"
    rm -rf "$build" && mkdir -p "$build"
    cd "$ROOT" || exit 1
    if [ $GUI -eq 1 ]; then
        xrun -f sim/ip_uart/uart_rtl.f -top "$tb" "$src" -access +rwc -gui \
             -input sim/ip_uart/uart_probe.tcl -xmlibdirpath "$build" -l "$build/xrun_gui.log"
        exit $?
    fi
    xrun -f sim/ip_uart/uart_rtl.f -top "$tb" "$src" -xmlibdirpath "$build" -l "$build/xrun.log" > /dev/null 2>&1
    res=$(grep -E "^(PASS|FAIL)" "$build/xrun.log")
    errs=$(grep -c "^xmvlog: \*E\|^xmelab: \*E\|^xrun: \*E" "$build/xrun.log")
    echo "${res:-FAIL: $tb (no PASS line, see $build/xrun.log)}"
    if [ "$errs" != "0" ] || ! echo "$res" | grep -q "^PASS" || echo "$res" | grep -q "FAIL"; then RC=1; fi
done
[ $RC -eq 0 ] && echo "Result: all PASS" || echo "Result: FAIL"
exit $RC
