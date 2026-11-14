"""Runs riscv-tests built with the original environment (env mcu_p) on the ch6 MCU (xsim on this PC).

    python sim/ch06_exception/run_mcu_tests.py                  # rv32ui (40), rv32mi (15), trap (3)
    python sim/ch06_exception/run_mcu_tests.py rv32mi           # one suite
    python sim/ch06_exception/run_mcu_tests.py rv32mi csr scall # named tests of one suite

Suites: rv32ui, rv32mi (sim/riscv-tests-hex/<suite>_mcu_p), trap (sim/ch06_exception/tests, ch6 trap tests)
Server (Xcelium) version: bash sim/ch06_exception/run_mcu_tests.sh
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SUITES = {
    "rv32ui": os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32ui_mcu_p"),
    "rv32mi": os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32mi_mcu_p"),
    "trap":   os.path.join(ROOT, "sim", "ch06_exception", "tests", "hex"),
}
args = sys.argv[1:]
suites = [args.pop(0)] if args and args[0] in SUITES else ["rv32ui", "rv32mi", "trap"]

rc = 0
for suite in suites:
    if not os.path.isdir(SUITES[suite]):
        print(f"{suite}: no hex folder {SUITES[suite]}")
        rc = 1
        continue
    env = dict(os.environ)
    env.update(
        RTL_DIR=os.path.join(ROOT, "rtl", "ch06_exception"),
        TB_FILE=os.path.join(ROOT, "sim", "ch06_exception", "mcu_exc_tb.v"),
        TB_TOP="mcu_exc_tb",
        EXTRA_SRC=os.path.join(ROOT, "sim", "ch14a_mcu", "tohost_mon.v"),
        HEX_DIR=SUITES[suite],
        PLUSARGS="",
    )
    print(f"== {suite} ==")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "sim", "run_riscv_tests.py")] + args, env=env)
    rc = rc or r.returncode
sys.exit(rc)
