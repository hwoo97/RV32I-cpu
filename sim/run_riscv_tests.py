"""Runs riscv-tests on the CPU testbench in one go (xsim on this PC).

    python sim/run_riscv_tests.py                 # all sim/riscv-tests-hex/rv32ui/*.hex
    python sim/run_riscv_tests.py add sub lw      # only the named tests

- The design and testbench are compiled once (xvlog, xelab); only xsim is rerun per test (+HEX=... selects the program).
- Build the test hex files in WSL first: bash sim/riscv-tests-env/build_rv32ui.sh
- Exit code 0 if all tests PASS.

Environment variables to run another testbench (defaults = stage 3 rv32i_sc_tb):
  RTL_DIR    design folder, all *.v in it are compiled        (default rtl/ch05_single_cycle)
  TB_FILE    testbench file                                   (default sim/ch05_single_cycle/rv32i_sc_tb.v)
  TB_TOP     testbench top module                             (default rv32i_sc_tb)
  EXTRA_SRC  extra Verilog files, space separated              (default none)
  PLUSARGS   extra plusargs, space separated, e.g. "WAITPCT=30 SEED=7"
"""
import glob
import os
import subprocess
import sys

VIVADO_BIN = os.environ.get("VIVADO_BIN", r"C:\Xilinx\Vivado\2023.1\bin")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTL = os.path.abspath(os.environ.get("RTL_DIR", os.path.join(ROOT, "rtl", "ch05_single_cycle")))
TB = os.path.abspath(os.environ.get("TB_FILE", os.path.join(ROOT, "sim", "ch05_single_cycle", "rv32i_sc_tb.v")))
TOP = os.environ.get("TB_TOP", "rv32i_sc_tb")
EXTRA = [os.path.abspath(f) for f in os.environ.get("EXTRA_SRC", "").split()]
PLUSARGS = os.environ.get("PLUSARGS", "").split()
HEX_DIR = os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32ui")
BUILD = os.path.join(ROOT, "sim", "build", TOP)


def tool(name):
    return os.path.join(VIVADO_BIN, name + (".bat" if os.name == "nt" else ""))


def run(cmd, timeout=600):
    return subprocess.run(cmd, cwd=BUILD, capture_output=True, text=True, timeout=timeout)


def main():
    names = sys.argv[1:]
    hexes = sorted(glob.glob(os.path.join(HEX_DIR, "*.hex")))
    if names:
        hexes = [h for h in hexes if os.path.splitext(os.path.basename(h))[0] in names]
    if not hexes:
        sys.exit(f"no test hex files: {HEX_DIR} (run build_rv32ui.sh first)")

    os.makedirs(BUILD, exist_ok=True)
    sources = sorted(glob.glob(os.path.join(RTL, "*.v"))) + EXTRA + [TB]
    incs = []
    for d in sorted({RTL} | {os.path.dirname(f) for f in EXTRA}):
        incs += ["-i", d]
    for cmd in ([tool("xvlog")] + incs + sources,
                [tool("xelab"), "-debug", "off", TOP, "-s", TOP + "_sim"]):
        r = run(cmd)
        if r.returncode != 0 or "ERROR" in r.stdout:
            print("\n".join(l for l in (r.stdout + r.stderr).splitlines() if "ERROR" in l) or r.stdout[-2000:])
            sys.exit("FAIL: compile error")

    passed, failed = 0, []
    for h in hexes:
        name = os.path.splitext(os.path.basename(h))[0]
        # Windows .bat files split arguments at '=', so pass "HEX=..." quoted as one string
        plusargs = " ".join(f'-testplusarg "{a}"' for a in ["HEX=" + h.replace("\\", "/")] + PLUSARGS)
        r = subprocess.run(f'"{tool("xsim")}" {TOP}_sim -R {plusargs}',
                           cwd=BUILD, capture_output=True, text=True, timeout=600, shell=True)
        result = [l for l in r.stdout.splitlines() if l.startswith(("PASS", "FAIL"))]
        line = result[0] if result else "FAIL: no result output"
        if line.startswith("PASS"):
            passed += 1
            print(f"  PASS  {name:10s} {line.split('(')[-1].rstrip(')')}")
        else:
            failed.append(name)
            print(f"  FAIL  {name:10s} {line}")

    print(f"\nResult: {passed} / {len(hexes)} PASS")
    if failed:
        sys.exit("Failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()
