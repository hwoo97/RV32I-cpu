#!/bin/bash
# Runs the ch6 programs on the chip (rv32i_chip: rv32i_mcu + IO pads) with memories on the chip pins
# (school server, Xcelium, PDK pad models). PC xsim version: python sim/ch06_exception/run_chip_tests.py
#
# Batch:
#   bash sim/ch06_exception/run_chip_tests.sh                    # rv32ui (40), rv32mi (15), trap (3)
#   bash sim/ch06_exception/run_chip_tests.sh trap irq_ext       # one suite, named tests
# Interactive (SimVision, one test):
#   bash sim/ch06_exception/run_chip_tests.sh trap --gui irq_timer
#
# - Signal pads: the PDK model pads_SS_s1vg.v (found through GPDK045_DIR, never copied into the repo),
#   power pads: sim/ch06_exception/pad_power.v (the PDK signal-pad file has none)

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -z "$GPDK045_DIR" ]; then
    echo "ERROR: GPDK045_DIR is not set -> in csh: setenv GPDK045_DIR <GPDK045 folder>, then run again"
    exit 1
fi
PAD_V="$GPDK045_DIR/digital/giolib045_v3.5/vlog/pads_SS_s1vg.v"
[ -f "$PAD_V" ] || { echo "ERROR: pad model not found: $PAD_V"; exit 1; }

declare -A SUITES=(
    [rv32ui]="$ROOT/sim/riscv-tests-hex/rv32ui_mcu_p"
    [rv32mi]="$ROOT/sim/riscv-tests-hex/rv32mi_mcu_p"
    [trap]="$ROOT/sim/ch06_exception/tests/hex"
)
if [ -n "$1" ] && [ -n "${SUITES[$1]}" ]; then RUN="$1"; shift; else RUN="rv32ui rv32mi trap"; fi

export RTL_DIR="$ROOT/rtl/ch06_exception"
export TB_FILE="$ROOT/sim/ch06_exception/chip_tb.v"
export TB_TOP="chip_tb"
export EXTRA_SRC="$ROOT/sim/ch14a_mcu/tohost_mon.v $PAD_V $ROOT/sim/ch06_exception/pad_power.v"
export XRUN_OPTS="-timescale 1ns/1ps"
export PLUSARGS="${PLUSARGS:-}"

RC=0
for s in $RUN; do
    echo "== $s =="
    HEX_DIR="${SUITES[$s]}" bash "$ROOT/sim/run_riscv_tests.sh" "$@" || RC=1
done
exit $RC
