#!/bin/bash
# Runs riscv-tests on rv32i_core with random data-port wait states (school server, Xcelium)
# PC xsim version: python sim/ch14a_mcu/run_core_wait.py
#
# Batch:
#   bash sim/ch14a_mcu/run_core_wait.sh                  # all tests, WAITPCT=30 (30 % of cycles not ready)
#   bash sim/ch14a_mcu/run_core_wait.sh 0                # no waits (cycle counts must equal stage 3)
#   bash sim/ch14a_mcu/run_core_wait.sh 50 add lw sw     # 50 %, only the named tests
#   env SEED=7 bash sim/ch14a_mcu/run_core_wait.sh 30    # another random sequence
# Interactive (SimVision, one test):
#   bash sim/ch14a_mcu/run_core_wait.sh 30 --gui lw
#
# Uses sim/run_riscv_tests.sh with TB_FILE / RTL_DIR / EXTRA_SRC / PLUSARGS set for this testbench.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WAITPCT="30"
if [[ "$1" =~ ^[0-9]+$ ]]; then WAITPCT="$1"; shift; fi

export RTL_DIR="$ROOT/rtl/ch14a_mcu"
export TB_FILE="$ROOT/sim/ch14a_mcu/core_wait_tb.v"
export TB_TOP="core_wait_tb"
export EXTRA_SRC="$ROOT/rtl/ch05_single_cycle/imem.v $ROOT/rtl/ch05_single_cycle/dmem.v"
export PLUSARGS="WAITPCT=$WAITPCT SEED=${SEED:-1}"

echo "core_wait_tb: WAITPCT=$WAITPCT SEED=${SEED:-1}"
exec bash "$ROOT/sim/run_riscv_tests.sh" "$@"
