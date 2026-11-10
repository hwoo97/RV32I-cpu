#!/bin/bash
# rv32ui 테스트를 최소 테스트 환경으로 빌드해 워드 hex로 변환한다 (WSL rv32i 배포판에서 실행)
#   bash sim/riscv-tests-env/build_rv32ui.sh [riscv-tests 경로]
# 결과: sim/riscv-tests-hex/rv32ui/<테스트>.hex  (커밋함 — 학교 서버에 RISC-V 툴체인이 없어서)
#       sim/build/rv32ui/<테스트>.elf, .dump    (커밋하지 않음, 디버깅용)
# riscv-tests는 BSD 라이선스: 바이너리를 배포할 때 저작권 고지를 함께 둔다 (LICENSE-riscv-tests 복사)
# 제외: fence_i (Zifencei 확장), ma_data (정렬 안 된 접근 — 6장 트랩 이후)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TESTS="${1:-$HOME/riscv-tests}"
OUT="$ROOT/sim/build/rv32ui"
HEX="$ROOT/sim/riscv-tests-hex/rv32ui"
P=riscv64-unknown-elf-
mkdir -p "$OUT" "$HEX"
rm -f "$OUT"/*.dump "$OUT"/*.elf "$HEX"/*.hex
cp "$TESTS/LICENSE" "$ROOT/sim/riscv-tests-hex/LICENSE-riscv-tests"
COMMIT=$(git -C "$TESTS" log -1 --format=%h 2>/dev/null || echo unknown)
n=0
for src in "$TESTS"/isa/rv32ui/*.S; do
    t=$(basename "$src" .S)
    case "$t" in fence_i|ma_data) continue ;; esac
    ${P}gcc -march=rv32i -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles \
        -I"$HERE" -I"$TESTS/isa/macros/scalar" -T"$HERE/link.ld" "$src" -o "$OUT/$t.elf"
    ${P}objcopy -O verilog --verilog-data-width=4 "$OUT/$t.elf" "$HEX/$t.hex"
    ${P}objdump -d -M no-aliases "$OUT/$t.elf" > "$OUT/$t.dump"
    n=$((n+1))
done
echo "$COMMIT" > "$ROOT/sim/riscv-tests-hex/RISCV_TESTS_COMMIT"
echo "built $n tests (riscv-tests $COMMIT) -> $HEX"
