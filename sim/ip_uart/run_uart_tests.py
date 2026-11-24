"""Runs the UART IP testbenches with Vivado xsim (PC). Server Xcelium version: sim/ip_uart/run_uart_tests.sh

    python sim/ip_uart/run_uart_tests.py            # uart_fifo_tb and uart_top_tb
    python sim/ip_uart/run_uart_tests.py --gui uart_top_tb
Bug models (each injected bug must make uart_top_tb fail): python sim/ip_uart/run_bug_models.py
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RTL = ["uart_fifo.v", "uart_baud.v", "uart_tx.v", "uart_rx.v", "uart_regs.v", "uart_top.v"]
TBS = {
    "uart_fifo_tb": ["uart_fifo.v"],
    "uart_top_tb": RTL,
}


def main():
    args = sys.argv[1:]
    gui = "--gui" in args
    names = [a for a in args if a != "--gui"] or list(TBS)
    rc = 0
    for tb in names:
        files = [os.path.join(ROOT, "rtl", "ip_uart", f) for f in TBS[tb]] + \
                [os.path.join(ROOT, "sim", "ip_uart", tb + ".v")]
        cmd = [sys.executable, os.path.join(ROOT, "sim", "run_sim.py"), tb] + files + \
              ["--incdir", os.path.join(ROOT, "sim", "ch14a_mcu"), "--timeout", "900"] + (["--gui"] if gui else [])
        r = subprocess.run(cmd, capture_output=True, text=True)
        lines = [ln for ln in (r.stdout + r.stderr).splitlines() if ln.startswith(("PASS", "FAIL"))]
        print("\n".join(lines) if lines else (r.stdout + r.stderr)[-1500:])
        rc |= r.returncode
    print("Result: all PASS" if rc == 0 else "Result: FAIL")
    sys.exit(rc)


if __name__ == "__main__":
    main()
