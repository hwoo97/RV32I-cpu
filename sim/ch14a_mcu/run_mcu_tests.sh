#!/bin/bash
# Runs riscv-tests (MCU build, sim/riscv-tests-hex/rv32ui_mcu) on mcu_top (school server, Xcelium)
# PC xsim version: python sim/ch14a_mcu/run_mcu_tests.py
#
# Batch:
#   bash sim/ch14a_mcu/run_mcu_tests.sh                  # all tests
#   bash sim/ch14a_mcu/run_mcu_tests.sh add lw sw            # only the named tests
# Interactive (SimVision, one test):
#   bash sim/ch14a_mcu/run_mcu_tests.sh --gui lw
#
# Rebuild the hex files (WSL, only when tests or the memory map change):
#   bash sim/riscv-tests-env/build_rv32ui.sh ~/riscv-tests mcu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

export RTL_DIR="$ROOT/rtl/ch14a_mcu"
export TB_FILE="$ROOT/sim/ch14a_mcu/mcu_tb.v"
export TB_TOP="mcu_tb"
export EXTRA_SRC="$ROOT/sim/ch14a_mcu/tohost_mon.v"
export HEX_DIR="$ROOT/sim/riscv-tests-hex/rv32ui_mcu"
export PLUSARGS=""

exec bash "$ROOT/sim/run_riscv_tests.sh" "$@"
