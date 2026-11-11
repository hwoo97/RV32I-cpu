"""Runs riscv-tests on rv32i_core with random data-port wait states (xsim on this PC).

    python sim/ch14a_mcu/run_core_wait.py                 # all tests, WAITPCT=30
    python sim/ch14a_mcu/run_core_wait.py 0               # no waits (cycle counts must equal stage 3)
    python sim/ch14a_mcu/run_core_wait.py 50 add lw sw    # 50 %, only the named tests
    (set SEED=<n> in the environment for another random sequence)

Uses sim/run_riscv_tests.py with TB_FILE / RTL_DIR / EXTRA_SRC / PLUSARGS set for this testbench.
Server (Xcelium) version: bash sim/ch14a_mcu/run_core_wait.sh
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = sys.argv[1:]
waitpct = "30"
if args and args[0].isdigit():
    waitpct = args.pop(0)

env = dict(os.environ)
env.update(
    RTL_DIR=os.path.join(ROOT, "rtl", "ch14a_mcu"),
    TB_FILE=os.path.join(ROOT, "sim", "ch14a_mcu", "core_wait_tb.v"),
    TB_TOP="core_wait_tb",
    EXTRA_SRC=" ".join(os.path.join(ROOT, "rtl", "ch05_single_cycle", f) for f in ("imem.v", "dmem.v")),
    PLUSARGS=f"WAITPCT={waitpct} SEED={os.environ.get('SEED', '1')}",
)
print(f"core_wait_tb: WAITPCT={waitpct} SEED={os.environ.get('SEED', '1')}")
sys.exit(subprocess.run([sys.executable, os.path.join(ROOT, "sim", "run_riscv_tests.py")] + args, env=env).returncode)
