#!/bin/bash
# Runs a testbench with Xcelium (xrun) and judges PASS/FAIL. (school server; runs in bash even if the login shell is csh)
#
#   bash sim/run_xrun.sh <testbench module> <Verilog files...> [--gui]
#
# e.g. bash sim/run_xrun.sh cnt_tb rtl/ch00_sample/cnt.v sim/ch00_sample/cnt_tb.v
#
# - Build output and logs go to sim/build/<testbench>/ (git-ignored).
# - Passes (exit 0) if the output contains "PASS" and no "FAIL"/"*E" (Xcelium error), else exit 1.
# - --gui: opens the SimVision waveform window; no pass/fail judgement in this mode.

if [ $# -lt 2 ]; then
    echo "usage: bash sim/run_xrun.sh <testbench module> <Verilog files...> [--gui]"
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOP="$1"; shift
GUI=0
FILES=()
INCDIRS=()
for arg in "$@"; do
    if [ "$arg" = "--gui" ]; then GUI=1; else
        DIR="$(cd "$(dirname "$arg")" && pwd)"
        FILES+=("$DIR/$(basename "$arg")")
        INCDIRS+=("-incdir" "$DIR")   # `include files are searched in each source file's folder
    fi
done

BUILD="$ROOT/sim/build/$TOP"
rm -rf "$BUILD" && mkdir -p "$BUILD" && cd "$BUILD" || exit 1

if [ $GUI -eq 1 ]; then
    xrun -64bit -access +rwc -top "$TOP" -gui "${INCDIRS[@]}" "${FILES[@]}"
    exit $?
fi

xrun -64bit -top "$TOP" -l xrun.log "${INCDIRS[@]}" "${FILES[@]}" > /dev/null 2>&1
CODE=$?

grep -E "PASS|FAIL" xrun.log
if grep -qE "^xrun: \*E|^\S+: \*E|^\s*\*E" xrun.log; then
    grep -E "\*E" xrun.log | head -10
    echo "FAIL: $TOP (Xcelium error, log: $BUILD/xrun.log)"
    exit 1
fi
if [ $CODE -ne 0 ] || grep -q "FAIL" xrun.log || ! grep -q "PASS" xrun.log; then
    echo "FAIL: $TOP (log: $BUILD/xrun.log)"
    exit 1
fi
echo "Passed: $TOP"
