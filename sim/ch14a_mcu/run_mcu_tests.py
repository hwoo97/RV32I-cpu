"""Runs riscv-tests (MCU build, sim/riscv-tests-hex/rv32ui_mcu) on mcu_top (xsim on this PC).

    python sim/ch14a_mcu/run_mcu_tests.py                 # all tests, SIMCTL without wait states
    python sim/ch14a_mcu/run_mcu_tests.py 50              # SIMCTL PREADY random 50 %
    python sim/ch14a_mcu/run_mcu_tests.py 0 add lw sw     # only the named tests

Server (Xcelium) version: bash sim/ch14a_mcu/run_mcu_tests.sh
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
    TB_FILE=os.path.join(ROOT, "sim", "ch14a_mcu", "mcu_tb.v"),
    TB_TOP="mcu_tb",
    EXTRA_SRC=os.path.join(ROOT, "sim", "ch14a_mcu", "apb_simctl.v"),
    HEX_DIR=os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32ui_mcu"),
    PLUSARGS=f"SIMWAIT={simwait}",
)
print(f"mcu_tb: SIMWAIT={simwait}")
sys.exit(subprocess.run([sys.executable, os.path.join(ROOT, "sim", "run_riscv_tests.py")] + args, env=env).returncode)
