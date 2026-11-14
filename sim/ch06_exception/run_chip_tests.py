"""Runs the ch6 programs on the chip (rv32i_chip: rv32i_mcu + IO pads) with memories on the chip pins
(xsim on this PC, simple pad models sim/ch06_exception/pad_models.v + pad_power.v).

    python sim/ch06_exception/run_chip_tests.py                  # rv32ui, rv32mi, trap
    python sim/ch06_exception/run_chip_tests.py trap irq_ext     # one suite, named tests

Server (Xcelium, PDK pad models): bash sim/ch06_exception/run_chip_tests.sh
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIM = os.path.join(ROOT, "sim", "ch06_exception")
SUITES = {
    "rv32ui": os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32ui_mcu_p"),
    "rv32mi": os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32mi_mcu_p"),
    "trap":   os.path.join(SIM, "tests", "hex"),
}
args = sys.argv[1:]
suites = [args.pop(0)] if args and args[0] in SUITES else ["rv32ui", "rv32mi", "trap"]

rc = 0
for suite in suites:
    env = dict(os.environ)
    env.update(
        RTL_DIR=os.path.join(ROOT, "rtl", "ch06_exception"),
        TB_FILE=os.path.join(SIM, "chip_tb.v"),
        TB_TOP="chip_tb",
        EXTRA_SRC=" ".join([os.path.join(ROOT, "sim", "ch14a_mcu", "tohost_mon.v"),
                            os.path.join(SIM, "pad_models.v"), os.path.join(SIM, "pad_power.v")]),
        HEX_DIR=SUITES[suite],
        PLUSARGS="",
    )
    print(f"== {suite} ==")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "sim", "run_riscv_tests.py")] + args, env=env)
    rc = rc or r.returncode
sys.exit(rc)
