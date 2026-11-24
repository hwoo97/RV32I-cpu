"""Bug models for the UART IP: checks that uart_top_tb catches each injected bug (xsim).

    python sim/ip_uart/run_bug_models.py [--keep]

For each bug, a copy of rtl/ip_uart is made in sim/build/uart_bugs/<name>/ with ONE line changed,
then uart_top_tb is run on the copy through sim/run_sim.py. "detected" = the testbench fails.
The real RTL is never modified. The clean RTL is also run first and must pass.
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RTL = os.path.join(ROOT, "rtl", "ip_uart")
BUILD = os.path.join(ROOT, "sim", "build", "uart_bugs")
FILES = ["uart_fifo.v", "uart_baud.v", "uart_tx.v", "uart_rx.v", "uart_regs.v", "uart_top.v"]

# (name, file, original text, buggy text, description)
BUGS = [
    ("tx_parity", "uart_tx.v",
     "S_PAR:   txd_c = f_peven ? par : ~par;", "S_PAR:   txd_c = f_peven ? ~par : par;",
     "TX parity bit inverted"),
    ("tx_stop2", "uart_tx.v",
     "if (f_stop2 && bitn == 3'd0) begin", "if (1'b0 && bitn == 3'd0) begin",
     "TX always sends one stop bit"),
    ("rx_one_sample", "uart_rx.v",
     "wire maj     = (s7 & s8) | (s7 & rx_s) | (s8 & rx_s);", "wire maj     = s8;",
     "RX uses sample 8 only (no majority vote)"),
    ("rx_no_glitch_filter", "uart_rx.v",
     "if (maj) state <= S_IDLE;", "if (1'b0) state <= S_IDLE;",
     "RX takes a short low pulse as a start bit"),
    ("rx_align_7bit", "uart_rx.v",
     "2'd2:    data_al = {1'b0,   shift[7:1]};", "2'd2:    data_al = {2'b00,  shift[7:2]};",
     "RX 7-bit data aligned one bit wrong"),
    ("fifo_full_early", "uart_fifo.v",
     "assign full  = (count == DEPTH);", "assign full  = (count == DEPTH - 1);",
     "FIFO reports full one entry early"),
    ("rxto_no_push_reset", "uart_regs.v",
     "end else if (rx_empty || rx_rd || rx_push || rx_start || rx_clr) begin",
     "end else if (rx_empty || rx_rd || rx_start || rx_clr) begin",
     "RX timeout not restarted when a byte arrives"),
    ("w1c_clears_all", "uart_regs.v",
     "else if (w1c & pwdata[`UART_ISR_PERR])  st_perr  <= 1'b0;",
     "else if (w1c)  st_perr  <= 1'b0;",
     "any ISR write clears PERR"),
    ("loopback_pin", "uart_top.v",
     "assign uart_tx = loopback ? 1'b1 : txd;", "assign uart_tx = txd;",
     "uart_tx pin not held idle in loopback"),
]


def run_tb(rtl_dir, tag):
    files = [os.path.join(rtl_dir, f) for f in FILES] + [os.path.join(ROOT, "sim", "ip_uart", "uart_top_tb.v")]
    cmd = [sys.executable, os.path.join(ROOT, "sim", "run_sim.py"), "uart_top_tb"] + files + \
          ["--incdir", os.path.join(ROOT, "sim", "ch14a_mcu"), "--incdir", RTL, "--timeout", "900"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    out = r.stdout + r.stderr
    first = next((ln for ln in out.splitlines() if ln.startswith("FAIL:")), "")
    return r.returncode == 0, first


def main():
    shutil.rmtree(BUILD, ignore_errors=True)
    ok, _ = run_tb(RTL, "clean")
    print("clean RTL:", "PASS" if ok else "FAIL")
    if not ok:
        sys.exit("FAIL: the clean RTL must pass first")
    detected = 0
    for name, fname, old, new, desc in BUGS:
        d = os.path.join(BUILD, name)
        os.makedirs(d)
        for f in FILES + ["uart_defs.vh"]:
            shutil.copy(os.path.join(RTL, f), d)
        p = os.path.join(d, fname)
        src = open(p, encoding="ascii").read()
        if src.count(old) != 1:
            sys.exit(f"FAIL: bug {name}: original text not found once in {fname}")
        open(p, "w", encoding="ascii").write(src.replace(old, new))
        ok, first = run_tb(d, name)
        hit = not ok
        detected += hit
        print(f"{'detected' if hit else 'MISSED  '}  {name:20s} {desc}")
        if hit and first:
            print("          " + first[:110])
    print(f"Result: {detected} / {len(BUGS)} bugs detected")
    if detected == len(BUGS):
        print("PASS: all bug models detected")
    else:
        sys.exit("FAIL: some bug models were not detected")


if __name__ == "__main__":
    main()
