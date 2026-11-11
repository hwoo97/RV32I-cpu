#!/bin/bash
# Runs C firmware (fw/hex/*.hex) on mcu_top with the UART decoder (school server, Xcelium)
# PC xsim version: python sim/ch14a_mcu/run_fw_tests.py
#
# Batch:
#   bash sim/ch14a_mcu/run_fw_tests.sh                  # all tests
#   bash sim/ch14a_mcu/run_fw_tests.sh hello                # only the named tests
# Interactive (SimVision, one test):
#   bash sim/ch14a_mcu/run_fw_tests.sh --gui hello
#
# Rebuild the hex files (WSL, after changing firmware or the memory map):
#   make -C fw/<prog>

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

export RTL_DIR="$ROOT/rtl/ch14a_mcu"
export TB_FILE="$ROOT/sim/ch14a_mcu/fw_tb.v"
export TB_TOP="fw_tb"
export EXTRA_SRC="$ROOT/sim/ch14a_mcu/tohost_mon.v"
export HEX_DIR="$ROOT/fw/hex"
export PLUSARGS=""

exec bash "$ROOT/sim/run_riscv_tests.sh" "$@"
