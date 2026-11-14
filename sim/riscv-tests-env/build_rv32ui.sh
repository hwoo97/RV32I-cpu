#!/bin/bash
# Builds riscv-tests for one test environment and converts them to word hex (run in the WSL rv32i distro)
#   bash sim/riscv-tests-env/build_rv32ui.sh [path to riscv-tests] [env]
#   env = min   (default) stage 3 single-cycle CPU, minimal environment without CSRs (sim/riscv-tests-env/)
#         mcu   stage 4 MCU memory map, minimal environment (sim/riscv-tests-env/mcu/)
#         mcu_p ch6 MCU with traps: the ORIGINAL environment env/p (sim/riscv-tests-env/mcu_p/),
#               suites rv32ui and rv32mi, -march=rv32i_zicsr
# Output: sim/riscv-tests-hex/<suite><suffix>/<test>.hex  (committed - the school server has no RISC-V toolchain)
#           suffix: "" (min), "_mcu" (mcu), "_mcu_p" (mcu_p); suite: rv32ui (+ rv32mi for mcu_p)
#         sim/build/<suite><suffix>/<test>.elf, .dump    (not committed, for debugging)
# riscv-tests is BSD licensed: distribute the copyright notice with the binaries (copies LICENSE-riscv-tests)
# Excluded (all environments): fence_i (writes instructions to memory: Zifencei, and the MCU IMEM is
#   read only from the data side), ma_data (needs misaligned loads/stores done in hardware or emulated;
#   this design traps on them - ch6 decision E)
#   pmpaddr (rv32mi: needs physical memory protection entries - not implemented, ch12)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
TESTS="${1:-$HOME/riscv-tests}"
ENV="${2:-min}"
MARCH=rv32i
SUITES="rv32ui"
case "$ENV" in
    min)   ENVDIR="$HERE";       SUFFIX="";       EXTRA_INC="" ;;
    mcu)   ENVDIR="$HERE/mcu";   SUFFIX="_mcu";   EXTRA_INC="-I$ROOT/fw/common -L$ROOT/fw/common" ;;
    mcu_p) ENVDIR="$HERE/mcu_p"; SUFFIX="_mcu_p"; EXTRA_INC="-I$TESTS/env -I$ROOT/fw/common -L$ROOT/fw/common"
           MARCH=rv32i_zicsr; SUITES="rv32ui rv32mi" ;;
    *)     echo "unknown env '$ENV' (min, mcu or mcu_p)"; exit 1 ;;
esac
P=riscv64-unknown-elf-
cp "$TESTS/LICENSE" "$ROOT/sim/riscv-tests-hex/LICENSE-riscv-tests"
COMMIT=$(git -C "$TESTS" log -1 --format=%h 2>/dev/null || echo unknown)
for suite in $SUITES; do
    OUT="$ROOT/sim/build/$suite$SUFFIX"
    HEX="$ROOT/sim/riscv-tests-hex/$suite$SUFFIX"
    mkdir -p "$OUT" "$HEX"
    rm -f "$OUT"/*.dump "$OUT"/*.elf "$HEX"/*.hex
    n=0
    for src in "$TESTS"/isa/$suite/*.S; do
        t=$(basename "$src" .S)
        case "$t" in fence_i|ma_data|pmpaddr) continue ;; esac
        ${P}gcc -march=$MARCH -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles \
            -I"$ENVDIR" $EXTRA_INC -I"$TESTS/isa/macros/scalar" -T"$ENVDIR/link.ld" "$src" -o "$OUT/$t.elf"
        ${P}objcopy -O verilog --verilog-data-width=4 "$OUT/$t.elf" "$HEX/$t.hex"
        ${P}objdump -d -M no-aliases "$OUT/$t.elf" > "$OUT/$t.dump"
        n=$((n+1))
    done
    echo "built $n $suite tests (riscv-tests $COMMIT, env $ENV) -> $HEX"
done
echo "$COMMIT" > "$ROOT/sim/riscv-tests-hex/RISCV_TESTS_COMMIT"
