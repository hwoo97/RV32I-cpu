#!/bin/bash
# Runs riscv-tests built with the original environment (env mcu_p) and the ch6 trap tests on the
# ch6 MCU (school server, Xcelium). PC xsim version: python sim/ch06_exception/run_mcu_tests.py
#
# Batch:
#   bash sim/ch06_exception/run_mcu_tests.sh                      # rv32ui (40), rv32mi (15), trap (3)
#   bash sim/ch06_exception/run_mcu_tests.sh rv32mi               # one suite
#   bash sim/ch06_exception/run_mcu_tests.sh rv32mi csr scall     # named tests of one suite
# Interactive (SimVision, one test):
#   bash sim/ch06_exception/run_mcu_tests.sh trap --gui irq_timer
#   (add +TRACE to PLUSARGS to print every trap: env PLUSARGS=TRACE bash ...)
#
# Rebuild the hex files (WSL, only when tests, the environment or the memory map change):
#   bash sim/riscv-tests-env/build_rv32ui.sh ~/riscv-tests mcu_p
#   bash sim/ch06_exception/tests/build.sh

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
declare -A SUITES=(
    [rv32ui]="$ROOT/sim/riscv-tests-hex/rv32ui_mcu_p"
    [rv32mi]="$ROOT/sim/riscv-tests-hex/rv32mi_mcu_p"
    [trap]="$ROOT/sim/ch06_exception/tests/hex"
)
if [ -n "$1" ] && [ -n "${SUITES[$1]}" ]; then RUN="$1"; shift; else RUN="rv32ui rv32mi trap"; fi

export RTL_DIR="$ROOT/rtl/ch06_exception"
export TB_FILE="$ROOT/sim/ch06_exception/mcu_exc_tb.v"
export TB_TOP="mcu_exc_tb"
export EXTRA_SRC="$ROOT/sim/ch14a_mcu/tohost_mon.v"
export PLUSARGS="${PLUSARGS:-}"

RC=0
for s in $RUN; do
    echo "== $s =="
    HEX_DIR="${SUITES[$s]}" bash "$ROOT/sim/run_riscv_tests.sh" "$@" || RC=1
done
exit $RC
