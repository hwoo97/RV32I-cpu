"""Runs C firmware (fw/hex/*.hex, built by make in fw/<prog>) on mcu_top with the UART decoder (xsim on this PC).

    python sim/ch14a_mcu/run_fw_tests.py                 # all tests, SIMCTL without wait states
    python sim/ch14a_mcu/run_fw_tests.py 50              # SIMCTL PREADY random 50 %
    python sim/ch14a_mcu/run_fw_tests.py 0 hello                # only the named tests

Server (Xcelium) version: bash sim/ch14a_mcu/run_fw_tests.sh
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = sys.argv[1:]
simwait = "0"
if args and args[0].isdigit():
    simwait = args.pop(0)

env = dict(os.environ)
env.update(
    RTL_DIR=os.path.join(ROOT, "rtl", "ch14a_mcu"),
    TB_FILE=os.path.join(ROOT, "sim", "ch14a_mcu", "fw_tb.v"),
    TB_TOP="fw_tb",
    EXTRA_SRC=os.path.join(ROOT, "sim", "ch14a_mcu", "apb_simctl.v"),
    HEX_DIR=os.path.join(ROOT, "fw", "hex"),
    PLUSARGS=f"SIMWAIT={simwait}",
)
print(f"fw_tb: SIMWAIT={simwait}")
sys.exit(subprocess.run([sys.executable, os.path.join(ROOT, "sim", "run_riscv_tests.py")] + args, env=env).returncode)
