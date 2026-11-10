"""Vivado xsim으로 테스트벤치를 실행하고 PASS/FAIL을 판정한다.

    python sim/run_sim.py <테스트벤치 모듈 이름> <Verilog 파일...> [--gui] [--timeout 초]

예) python sim/run_sim.py cnt_tb rtl/ch02_logic/cnt.v sim/ch02_logic/cnt_tb.v

- 빌드 결과는 sim/build/<테스트벤치>/ 에 만든다 (.gitignore 대상).
- 시뮬레이션 출력에 "PASS"가 있고 "FAIL"·"ERROR"가 없으면 통과로 본다.
- --gui: 파형 창(xsim GUI)을 연다. 이때는 판정하지 않는다.
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
    parser = argparse.ArgumentParser(description="xsim 실행·판정")
    parser.add_argument("top", help="테스트벤치 최상위 모듈 이름")
    parser.add_argument("files", nargs="+", help="Verilog 파일들")
    parser.add_argument("--gui", action="store_true", help="파형 창 열기")
    parser.add_argument("--timeout", type=int, default=300, help="단계별 제한 시간(초)")
    args = parser.parse_args()

    files = [os.path.abspath(f) for f in args.files]
    # `include 파일은 각 소스 파일이 있는 폴더에서 찾는다
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
            sys.exit(f"FAIL: {name} 시간 초과 ({args.timeout}초)")
        errors = [line for line in output.splitlines() if line.startswith("ERROR")]
        if code != 0 or errors:
            print("\n".join(errors) or output[-2000:])
            sys.exit(f"FAIL: {name} 단계 오류 (로그: {build})")

    if args.gui:
        return
    sim_lines = [line for line in output.splitlines() if "PASS" in line or "FAIL" in line]
    print("\n".join(sim_lines))
    if any("FAIL" in line for line in sim_lines) or not any("PASS" in line for line in sim_lines):
        sys.exit(f"FAIL: {args.top}")
    print(f"통과: {args.top}")


if __name__ == "__main__":
    main()
