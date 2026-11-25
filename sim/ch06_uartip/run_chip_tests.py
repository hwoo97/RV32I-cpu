"""Runs the ch6 programs on the chip with the UART IP (rtl/ch06_uartip: the simple apb_uart replaced by
rtl/ip_uart/uart_top) - memories on the chip pins (xsim on this PC, simple pad models
sim/ch06_exception/pad_models.v + pad_power.v; same testbench sim/ch06_exception/chip_tb.v).

    python sim/ch06_uartip/run_chip_tests.py                     # rv32ui, rv32mi, trap, uart
    python sim/ch06_uartip/run_chip_tests.py uart uart_irq       # one suite, named tests

Server (Xcelium, lab style): sim/ch06_uartip/run_function.tcl
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIM = os.path.join(ROOT, "sim", "ch06_exception")          # shared testbench, pad models, trap tests
HERE = os.path.join(ROOT, "sim", "ch06_uartip")
SUITES = {
    "rv32ui": os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32ui_mcu_p"),
    "rv32mi": os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32mi_mcu_p"),
    "trap":   os.path.join(SIM, "tests", "hex"),
    "uart":   os.path.join(HERE, "tests", "hex"),
}
UART_IP = [os.path.join(ROOT, "rtl", "ip_uart", f) for f in
           ("uart_fifo.v", "uart_baud.v", "uart_tx.v", "uart_rx.v", "uart_regs.v", "uart_top.v")]
args = sys.argv[1:]
suites = [args.pop(0)] if args and args[0] in SUITES else ["rv32ui", "rv32mi", "trap", "uart"]

rc = 0
for suite in suites:
    env = dict(os.environ)
    env.update(
        RTL_DIR=os.path.join(ROOT, "rtl", "ch06_uartip"),
        TB_FILE=os.path.join(SIM, "chip_tb.v"),
        TB_TOP="chip_tb",
        EXTRA_SRC=" ".join(UART_IP + [os.path.join(ROOT, "sim", "ch14a_mcu", "tohost_mon.v"),
                            os.path.join(SIM, "pad_models.v"), os.path.join(SIM, "pad_power.v")]),
        HEX_DIR=SUITES[suite],
        PLUSARGS="",
    )
    print(f"== {suite} ==")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "sim", "run_riscv_tests.py")] + args, env=env)
    rc = rc or r.returncode
sys.exit(rc)
