#!/bin/bash
# Builds the ch6 trap tests (sim/ch06_exception/tests/*.S) with the riscv-tests environment for the
# ch6 MCU (env mcu_p) and converts them to word hex (run in the WSL rv32i distro)
#   bash sim/ch06_exception/tests/build.sh [path to riscv-tests]
# Output: sim/ch06_exception/tests/hex/<test>.hex (committed), sim/build/ch06_trap/<test>.elf, .dump
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
TESTS="${1:-$HOME/riscv-tests}"
ENVDIR="$ROOT/sim/riscv-tests-env/mcu_p"
OUT="$ROOT/sim/build/ch06_trap"
HEX="$HERE/hex"
P=riscv64-unknown-elf-
mkdir -p "$OUT" "$HEX"
rm -f "$HEX"/*.hex
n=0
for src in "$HERE"/*.S; do
    t=$(basename "$src" .S)
    ${P}gcc -march=rv32i_zicsr -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles \
        -I"$ENVDIR" -I"$TESTS/env" -I"$ROOT/fw/common" -L"$ROOT/fw/common" -I"$TESTS/isa/macros/scalar" \
        -T"$ENVDIR/link.ld" "$src" -o "$OUT/$t.elf"
    ${P}objcopy -O verilog --verilog-data-width=4 "$OUT/$t.elf" "$HEX/$t.hex"
    ${P}objdump -d -M no-aliases "$OUT/$t.elf" > "$OUT/$t.dump"
    n=$((n+1))
done
echo "built $n ch6 trap tests -> $HEX"
