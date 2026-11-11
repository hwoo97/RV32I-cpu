#!/bin/bash
# Runs riscv-tests (MCU build, sim/riscv-tests-hex/rv32ui_mcu) on mcu_top (school server, Xcelium)
# PC xsim version: python sim/ch14a_mcu/run_mcu_tests.py
#
# Batch:
#   bash sim/ch14a_mcu/run_mcu_tests.sh                  # all tests, SIMCTL without wait states
#   bash sim/ch14a_mcu/run_mcu_tests.sh 50               # SIMCTL PREADY random 50 % (stall on the final write)
#   bash sim/ch14a_mcu/run_mcu_tests.sh 0 add lw sw      # only the named tests
# Interactive (SimVision, one test):
#   bash sim/ch14a_mcu/run_mcu_tests.sh 0 --gui lw
#
# Rebuild the hex files (WSL, only when tests or the memory map change):
#   bash sim/riscv-tests-env/build_rv32ui.sh ~/riscv-tests mcu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SIMWAIT="0"
if [[ "$1" =~ ^[0-9]+$ ]]; then SIMWAIT="$1"; shift; fi

export RTL_DIR="$ROOT/rtl/ch14a_mcu"
export TB_FILE="$ROOT/sim/ch14a_mcu/mcu_tb.v"
export TB_TOP="mcu_tb"
export EXTRA_SRC="$ROOT/sim/ch14a_mcu/apb_simctl.v"
export HEX_DIR="$ROOT/sim/riscv-tests-hex/rv32ui_mcu"
export PLUSARGS="SIMWAIT=$SIMWAIT"

echo "mcu_tb: SIMWAIT=$SIMWAIT"
exec bash "$ROOT/sim/run_riscv_tests.sh" "$@"
