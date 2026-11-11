#!/bin/bash
# Builds the rv32ui tests with the minimal test environment and converts them to word hex (run in the WSL rv32i distro)
#   bash sim/riscv-tests-env/build_rv32ui.sh [path to riscv-tests]
# Output: sim/riscv-tests-hex/rv32ui/<test>.hex  (committed - the school server has no RISC-V toolchain)
#         sim/build/rv32ui/<test>.elf, .dump    (not committed, for debugging)
# riscv-tests is BSD licensed: distribute the copyright notice with the binaries (copies LICENSE-riscv-tests)
# Excluded: fence_i (Zifencei extension), ma_data (misaligned access - after ch6 traps)
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
