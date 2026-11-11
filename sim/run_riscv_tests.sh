#!/bin/bash
# Runs riscv-tests on the CPU testbench (school server, Xcelium). PC xsim version: run_riscv_tests.py
#
# Batch (all or named tests, PASS/FAIL summary):
#   bash sim/run_riscv_tests.sh                 # all sim/riscv-tests-hex/rv32ui/*.hex
#   bash sim/run_riscv_tests.sh add sub lw      # only the named tests
# Interactive (one test in SimVision, step with "run 200ns" in the console):
#   bash sim/run_riscv_tests.sh --gui add
#   (same as running from the repo root:
#    xrun -f sim/ch05_single_cycle/rv32i_sc.f -access +rwc -gui #         -input sim/ch05_single_cycle/rv32i_sc_probe.tcl +HEX=sim/riscv-tests-hex/rv32ui/add.hex)
#
# - Batch compiles/elaborates once (xrun -elaborate), then only runs per test (xrun -R +HEX=...)
# - To run another design folder: RTL_DIR=<folder> bash sim/run_riscv_tests.sh
# - Exit code 0 if all tests PASS

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="${RTL_DIR:-$ROOT/rtl/ch05_single_cycle}"
RTL="$(cd "$RTL" && pwd)"
TB="$ROOT/sim/ch05_single_cycle/rv32i_sc_tb.v"
HEX_DIR="$ROOT/sim/riscv-tests-hex/rv32ui"
BUILD="$ROOT/sim/build/rv32i_sc_tb_xrun"
TOP=rv32i_sc_tb

# -- Interactive mode: one test in SimVision --
if [ "$1" = "--gui" ]; then
    name="${2:-simple}"
    h="$HEX_DIR/$name.hex"
    [ -f "$h" ] || { echo "FAIL: no hex file $h"; exit 1; }
    GUI_DIR="$ROOT/sim/build/rv32i_sc_tb_gui"
    mkdir -p "$GUI_DIR" && cd "$GUI_DIR" || exit 1
    xrun -64bit -access +rwc -gui -top "$TOP" -incdir "$RTL" "$RTL"/*.v "$TB"          -input "$ROOT/sim/ch05_single_cycle/rv32i_sc_probe.tcl" -l gui.log "+HEX=$h"
    exit $?
fi

if [ $# -gt 0 ]; then
    HEXES=(); for n in "$@"; do HEXES+=("$HEX_DIR/$n.hex"); done
else
    HEXES=("$HEX_DIR"/*.hex)
fi

rm -rf "$BUILD" && mkdir -p "$BUILD" && cd "$BUILD" || exit 1

xrun -64bit -elaborate -top "$TOP" -incdir "$RTL" "$RTL"/*.v "$TB" -l compile.log > /dev/null 2>&1
if [ $? -ne 0 ] || grep -q "\*E" compile.log; then
    grep "\*E" compile.log | head -10
    echo "FAIL: compile error (log: $BUILD/compile.log)"
    exit 1
fi

PASS=0; FAILED=()
for h in "${HEXES[@]}"; do
    name="$(basename "$h" .hex)"
    if [ ! -f "$h" ]; then echo "  FAIL  $name  (no hex file)"; FAILED+=("$name"); continue; fi
    xrun -64bit -R -l "run_$name.log" "+HEX=$h" > /dev/null 2>&1
    line="$(grep -m1 -E '^(PASS|FAIL)' "run_$name.log")"
    if [[ "$line" == PASS* ]]; then
        PASS=$((PASS+1)); printf "  PASS  %-10s %s\n" "$name" "$(echo "$line" | sed 's/.*(\(.*\))/\1/')"
    else
        FAILED+=("$name"); printf "  FAIL  %-10s %s\n" "$name" "${line:-no result output (log: $BUILD/run_$name.log)}"
    fi
done

echo ""
echo "Result: $PASS / ${#HEXES[@]} PASS"
if [ ${#FAILED[@]} -gt 0 ]; then echo "Failed: ${FAILED[*]}"; exit 1; fi
