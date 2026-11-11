"""Runs riscv-tests (MCU build, sim/riscv-tests-hex/rv32ui_mcu) on mcu_top (xsim on this PC).

    python sim/ch14a_mcu/run_mcu_tests.py                 # all tests
    python sim/ch14a_mcu/run_mcu_tests.py add lw sw     # only the named tests

Server (Xcelium) version: bash sim/ch14a_mcu/run_mcu_tests.sh
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = sys.argv[1:]

env = dict(os.environ)
env.update(
    RTL_DIR=os.path.join(ROOT, "rtl", "ch14a_mcu"),
    TB_FILE=os.path.join(ROOT, "sim", "ch14a_mcu", "mcu_tb.v"),
    TB_TOP="mcu_tb",
    EXTRA_SRC=os.path.join(ROOT, "sim", "ch14a_mcu", "tohost_mon.v"),
    HEX_DIR=os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32ui_mcu"),
    PLUSARGS="",
)
sys.exit(subprocess.run([sys.executable, os.path.join(ROOT, "sim", "run_riscv_tests.py")] + args, env=env).returncode)
