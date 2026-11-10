#!/bin/bash
# riscv-tests를 CPU 테스트벤치로 한꺼번에 실행한다 (학교 서버, Xcelium). PC xsim 버전은 run_riscv_tests.py
#
#   bash sim/run_riscv_tests.sh                 # sim/riscv-tests-hex/rv32ui/*.hex 전부
#   bash sim/run_riscv_tests.sh add sub lw      # 이름을 준 테스트만
#
# - 설계·테스트벤치는 한 번만 컴파일·엘라보레이션하고(xrun -elaborate), 테스트마다 실행만 한다(xrun -R +HEX=…)
# - 다른 설계 폴더로 돌릴 때: RTL_DIR=<폴더> bash sim/run_riscv_tests.sh
# - 모든 테스트가 PASS면 종료 코드 0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RTL="${RTL_DIR:-$ROOT/rtl/ch05_single_cycle}"
RTL="$(cd "$RTL" && pwd)"
TB="$ROOT/sim/ch05_single_cycle/rv32i_sc_tb.v"
HEX_DIR="$ROOT/sim/riscv-tests-hex/rv32ui"
BUILD="$ROOT/sim/build/rv32i_sc_tb_xrun"
TOP=rv32i_sc_tb

if [ $# -gt 0 ]; then
    HEXES=(); for n in "$@"; do HEXES+=("$HEX_DIR/$n.hex"); done
else
    HEXES=("$HEX_DIR"/*.hex)
fi

rm -rf "$BUILD" && mkdir -p "$BUILD" && cd "$BUILD" || exit 1

xrun -64bit -elaborate -top "$TOP" -incdir "$RTL" "$RTL"/*.v "$TB" -l compile.log > /dev/null 2>&1
if [ $? -ne 0 ] || grep -q "\*E" compile.log; then
    grep "\*E" compile.log | head -10
    echo "FAIL: 컴파일 오류 (로그: $BUILD/compile.log)"
    exit 1
fi

PASS=0; FAILED=()
for h in "${HEXES[@]}"; do
    name="$(basename "$h" .hex)"
    if [ ! -f "$h" ]; then echo "  FAIL  $name  (hex 없음)"; FAILED+=("$name"); continue; fi
    xrun -64bit -R -l "run_$name.log" "+HEX=$h" > /dev/null 2>&1
    line="$(grep -m1 -E '^(PASS|FAIL)' "run_$name.log")"
    if [[ "$line" == PASS* ]]; then
        PASS=$((PASS+1)); printf "  PASS  %-10s %s\n" "$name" "$(echo "$line" | sed 's/.*(\(.*\))/\1/')"
    else
        FAILED+=("$name"); printf "  FAIL  %-10s %s\n" "$name" "${line:-결과 출력 없음 (로그: $BUILD/run_$name.log)}"
    fi
done

echo ""
echo "결과: $PASS / ${#HEXES[@]} PASS"
if [ ${#FAILED[@]} -gt 0 ]; then echo "실패: ${FAILED[*]}"; exit 1; fi
