"""Runs C firmware (fw/hex/*.hex, built by make in fw/<prog>) on the ch6 mcu_top with the UART decoder (firmware regression) (xsim on this PC).

    python sim/ch06_exception/run_fw_tests.py                 # all tests
    python sim/ch06_exception/run_fw_tests.py hello                 # only the named tests

Server (Xcelium) version: bash sim/ch06_exception/run_fw_tests.sh
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = sys.argv[1:]

env = dict(os.environ)
env.update(
    RTL_DIR=os.path.join(ROOT, "rtl", "ch06_exception"),
    TB_FILE=os.path.join(ROOT, "sim", "ch06_exception", "fw_exc_tb.v"),
    TB_TOP="fw_exc_tb",
    EXTRA_SRC=os.path.join(ROOT, "sim", "ch14a_mcu", "tohost_mon.v"),
    HEX_DIR=os.path.join(ROOT, "fw", "hex"),
    PLUSARGS="",
)
sys.exit(subprocess.run([sys.executable, os.path.join(ROOT, "sim", "run_riscv_tests.py")] + args, env=env).returncode)
