"""riscv-tests를 CPU 테스트벤치로 한꺼번에 실행한다 (이 PC의 xsim).

    python sim/run_riscv_tests.py                 # sim/build/rv32ui/*.hex 전부
    python sim/run_riscv_tests.py add sub lw      # 이름을 준 테스트만

- 설계·테스트벤치는 한 번만 컴파일(xvlog·xelab)하고, 테스트마다 xsim만 다시 실행한다 (+HEX=… 로 프로그램 지정).
- 테스트 hex는 WSL에서 먼저 만든다: bash sim/riscv-tests-env/build_rv32ui.sh
- 모든 테스트가 PASS면 종료 코드 0.
"""
import glob
import os
import subprocess
import sys

VIVADO_BIN = os.environ.get("VIVADO_BIN", r"C:\Xilinx\Vivado\2023.1\bin")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTL = os.environ.get("RTL_DIR", os.path.join(ROOT, "rtl", "ch05_single_cycle"))   # 다른 설계 폴더로 바꿔 돌릴 때 RTL_DIR 지정
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
        sys.exit(f"테스트 hex가 없음: {HEX_DIR} (먼저 build_rv32ui.sh 실행)")

    os.makedirs(BUILD, exist_ok=True)
    sources = sorted(glob.glob(os.path.join(RTL, "*.v"))) + [TB]
    for cmd in ([tool("xvlog"), "-i", RTL] + sources,
                [tool("xelab"), "-debug", "off", TOP, "-s", TOP + "_sim"]):
        r = run(cmd)
        if r.returncode != 0 or "ERROR" in r.stdout:
            print("\n".join(l for l in (r.stdout + r.stderr).splitlines() if "ERROR" in l) or r.stdout[-2000:])
            sys.exit("FAIL: 컴파일 오류")

    passed, failed = 0, []
    for h in hexes:
        name = os.path.splitext(os.path.basename(h))[0]
        # Windows의 .bat는 인자 안의 '='에서 인자를 나누므로 "HEX=…"를 따옴표로 감싸 문자열로 넘긴다
        plusarg = '"HEX=' + h.replace("\\", "/") + '"'
        r = subprocess.run(f'"{tool("xsim")}" {TOP}_sim -R -testplusarg {plusarg}',
                           cwd=BUILD, capture_output=True, text=True, timeout=600, shell=True)
        result = [l for l in r.stdout.splitlines() if l.startswith(("PASS", "FAIL"))]
        line = result[0] if result else "FAIL: 결과 출력 없음"
        if line.startswith("PASS"):
            passed += 1
            print(f"  PASS  {name:10s} {line.split('(')[-1].rstrip(')')}")
        else:
            failed.append(name)
            print(f"  FAIL  {name:10s} {line}")

    print(f"\n결과: {passed} / {len(hexes)} PASS")
    if failed:
        sys.exit("실패: " + ", ".join(failed))


if __name__ == "__main__":
    main()
