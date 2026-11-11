"""Runs a testbench with Vivado xsim and judges PASS/FAIL.

    python sim/run_sim.py <testbench module> <Verilog files...> [--gui] [--timeout sec]

e.g. python sim/run_sim.py cnt_tb rtl/ch00_sample/cnt.v sim/ch00_sample/cnt_tb.v

- Build output goes to sim/build/<testbench>/ (git-ignored).
- Passes if the simulation output contains "PASS" and no "FAIL"/"ERROR".
- --gui: opens the waveform window (xsim GUI); no pass/fail judgement in this mode.
"""
import argparse
import os
import shutil
import subprocess
import sys

VIVADO_BIN = os.environ.get("VIVADO_BIN", r"C:\Xilinx\Vivado\2023.1\bin")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def tool(name):
    return os.path.join(VIVADO_BIN, name + (".bat" if os.name == "nt" else ""))


def run(cmd, cwd, timeout):
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return result.returncode, result.stdout + result.stderr


def main():
    parser = argparse.ArgumentParser(description="run xsim and judge")
    parser.add_argument("top", help="testbench top module name")
    parser.add_argument("files", nargs="+", help="Verilog files")
    parser.add_argument("--gui", action="store_true", help="open the waveform window")
    parser.add_argument("--timeout", type=int, default=300, help="time limit per step (s)")
    args = parser.parse_args()

    files = [os.path.abspath(f) for f in args.files]
    # `include files are searched in the folder of each source file
    incdirs = []
    for d in dict.fromkeys(os.path.dirname(f) for f in files):
        incdirs += ["-i", d]
    build = os.path.join(ROOT, "sim", "build", args.top)
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)

    steps = [
        ("xvlog", [tool("xvlog")] + incdirs + files),
        ("xelab", [tool("xelab"), "-debug", "typical" if args.gui else "off", args.top, "-s", args.top + "_sim"]),
        ("xsim", [tool("xsim"), args.top + "_sim"] + (["-gui"] if args.gui else ["-R"])),
    ]
    output = ""
    for name, cmd in steps:
        try:
            code, output = run(cmd, build, args.timeout)
        except subprocess.TimeoutExpired:
            sys.exit(f"FAIL: {name} timed out ({args.timeout} s)")
        errors = [line for line in output.splitlines() if line.startswith("ERROR")]
        if code != 0 or errors:
            print("\n".join(errors) or output[-2000:])
            sys.exit(f"FAIL: {name} step error (log: {build})")

    if args.gui:
        return
    sim_lines = [line for line in output.splitlines() if "PASS" in line or "FAIL" in line]
    print("\n".join(sim_lines))
    if any("FAIL" in line for line in sim_lines) or not any("PASS" in line for line in sim_lines):
        sys.exit(f"FAIL: {args.top}")
    print(f"Passed: {args.top}")


if __name__ == "__main__":
    main()
