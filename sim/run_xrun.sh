#!/bin/bash
# Xcelium(xrun)으로 테스트벤치를 실행하고 PASS/FAIL을 판정한다. (학교 서버용, 로그인 셸이 csh여도 bash로 실행됨)
#
#   bash sim/run_xrun.sh <테스트벤치 모듈 이름> <Verilog 파일...> [--gui]
#
# 예) bash sim/run_xrun.sh cnt_tb rtl/ch00_sample/cnt.v sim/ch00_sample/cnt_tb.v
#
# - 빌드 결과·로그는 sim/build/<테스트벤치>/ 에 만든다 (.gitignore 대상).
# - 시뮬레이션 출력에 "PASS"가 있고 "FAIL"·"*E"(Xcelium 오류)가 없으면 통과(종료 코드 0), 아니면 1.
# - --gui: SimVision 파형 창을 연다. 이때는 판정하지 않는다.

if [ $# -lt 2 ]; then
    echo "사용법: bash sim/run_xrun.sh <테스트벤치 모듈> <Verilog 파일...> [--gui]"
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOP="$1"; shift
GUI=0
FILES=()
for arg in "$@"; do
    if [ "$arg" = "--gui" ]; then GUI=1; else FILES+=("$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"); fi
done

BUILD="$ROOT/sim/build/$TOP"
rm -rf "$BUILD" && mkdir -p "$BUILD" && cd "$BUILD" || exit 1

if [ $GUI -eq 1 ]; then
    xrun -64bit -access +rwc -top "$TOP" -gui "${FILES[@]}"
    exit $?
fi

xrun -64bit -top "$TOP" -l xrun.log "${FILES[@]}" > /dev/null 2>&1
CODE=$?

grep -E "PASS|FAIL" xrun.log
if grep -qE "^xrun: \*E|^\S+: \*E|^\s*\*E" xrun.log; then
    grep -E "\*E" xrun.log | head -10
    echo "FAIL: $TOP (Xcelium 오류, 로그: $BUILD/xrun.log)"
    exit 1
fi
if [ $CODE -ne 0 ] || grep -q "FAIL" xrun.log || ! grep -q "PASS" xrun.log; then
    echo "FAIL: $TOP (로그: $BUILD/xrun.log)"
    exit 1
fi
echo "통과: $TOP"
