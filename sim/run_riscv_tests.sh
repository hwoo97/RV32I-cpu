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
# - Exit code 0 if all tests PASS
# - Environment variables to run another testbench (defaults = stage 3 rv32i_sc_tb), csh: env NAME=value bash ...
#     RTL_DIR    design folder, all *.v in it are compiled        (default rtl/ch05_single_cycle)
#     TB_FILE    testbench file                                   (default sim/ch05_single_cycle/rv32i_sc_tb.v)
#     TB_TOP     testbench top module                             (default rv32i_sc_tb)
#     EXTRA_SRC  extra Verilog files, space separated              (default none)
#     PLUSARGS   extra plusargs, space separated, e.g. "WAITPCT=30 SEED=7"
#     HEX_DIR    folder of the test hex files                     (default sim/riscv-tests-hex/rv32ui)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="${RTL_DIR:-$ROOT/rtl/ch05_single_cycle}"
RTL="$(cd "$RTL" && pwd)"
TB="$(cd "$(dirname "${TB_FILE:-$ROOT/sim/ch05_single_cycle/rv32i_sc_tb.v}")" && pwd)/$(basename "${TB_FILE:-rv32i_sc_tb.v}")"
TOP="${TB_TOP:-rv32i_sc_tb}"
HEX_DIR="$(cd "${HEX_DIR:-$ROOT/sim/riscv-tests-hex/rv32ui}" && pwd)"
BUILD="$ROOT/sim/build/${TOP}_xrun"

# Extra sources (absolute paths) and their folders as include dirs
EXTRA=(); INCS=(-incdir "$RTL")
for f in $EXTRA_SRC; do
    d="$(cd "$(dirname "$f")" && pwd)"; EXTRA+=("$d/$(basename "$f")"); INCS+=(-incdir "$d")
done
PLUS=(); for a in $PLUSARGS; do PLUS+=("+$a"); done

# -- Interactive mode: one test in SimVision --
if [ "$1" = "--gui" ]; then
    name="${2:-simple}"
    h="$HEX_DIR/$name.hex"
    [ -f "$h" ] || { echo "FAIL: no hex file $h"; exit 1; }
    GUI_DIR="$ROOT/sim/build/${TOP}_gui"
    mkdir -p "$GUI_DIR" && cd "$GUI_DIR" || exit 1
    # probe script for this top (same content as sim/ch05_single_cycle/rv32i_sc_probe.tcl)
    printf 'database -open waves -shm -into waves.shm -default
probe -create %s -all -depth all -database waves
puts "probes ready: type run 200ns or run"
' "$TOP" > probe.tcl
    xrun -64bit -access +rwc -gui -top "$TOP" "${INCS[@]}" "$RTL"/*.v "${EXTRA[@]}" "$TB"          -input probe.tcl -l gui.log "+HEX=$h" "${PLUS[@]}"
    exit $?
fi

if [ $# -gt 0 ]; then
    HEXES=(); for n in "$@"; do HEXES+=("$HEX_DIR/$n.hex"); done
else
    HEXES=("$HEX_DIR"/*.hex)
fi

rm -rf "$BUILD" && mkdir -p "$BUILD" && cd "$BUILD" || exit 1

xrun -64bit -elaborate -top "$TOP" "${INCS[@]}" "$RTL"/*.v "${EXTRA[@]}" "$TB" -l compile.log > /dev/null 2>&1
if [ $? -ne 0 ] || grep -q "\*E" compile.log; then
    grep "\*E" compile.log | head -10
    echo "FAIL: compile error (log: $BUILD/compile.log)"
    exit 1
fi

PASS=0; FAILED=()
for h in "${HEXES[@]}"; do
    name="$(basename "$h" .hex)"
    if [ ! -f "$h" ]; then echo "  FAIL  $name  (no hex file)"; FAILED+=("$name"); continue; fi
    xrun -64bit -R -l "run_$name.log" "+HEX=$h" "${PLUS[@]}" > /dev/null 2>&1
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
