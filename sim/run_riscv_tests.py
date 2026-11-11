"""Runs riscv-tests on the CPU testbench in one go (xsim on this PC).

    python sim/run_riscv_tests.py                 # all sim/riscv-tests-hex/rv32ui/*.hex
    python sim/run_riscv_tests.py add sub lw      # only the named tests

- The design and testbench are compiled once (xvlog, xelab); only xsim is rerun per test (+HEX=... selects the program).
- Build the test hex files in WSL first: bash sim/riscv-tests-env/build_rv32ui.sh
- Exit code 0 if all tests PASS.
"""
import glob
import os
import subprocess
import sys

VIVADO_BIN = os.environ.get("VIVADO_BIN", r"C:\Xilinx\Vivado\2023.1\bin")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTL = os.environ.get("RTL_DIR", os.path.join(ROOT, "rtl", "ch05_single_cycle"))   # set RTL_DIR to run another design folder
TB = os.path.join(ROOT, "sim", "ch05_single_cycle", "rv32i_sc_tb.v")
HEX_DIR = os.path.join(ROOT, "sim", "riscv-tests-hex", "rv32ui")
BUILD = os.path.join(ROOT, "sim", "build", "rv32i_sc_tb")
TOP = "rv32i_sc_tb"


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
    sources = sorted(glob.glob(os.path.join(RTL, "*.v"))) + [TB]
    for cmd in ([tool("xvlog"), "-i", RTL] + sources,
                [tool("xelab"), "-debug", "off", TOP, "-s", TOP + "_sim"]):
        r = run(cmd)
        if r.returncode != 0 or "ERROR" in r.stdout:
            print("\n".join(l for l in (r.stdout + r.stderr).splitlines() if "ERROR" in l) or r.stdout[-2000:])
            sys.exit("FAIL: compile error")

    passed, failed = 0, []
    for h in hexes:
        name = os.path.splitext(os.path.basename(h))[0]
        # Windows .bat files split arguments at '=', so pass "HEX=..." quoted as one string
        plusarg = '"HEX=' + h.replace("\\", "/") + '"'
        r = subprocess.run(f'"{tool("xsim")}" {TOP}_sim -R -testplusarg {plusarg}',
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
