#!/bin/bash
# ch05 단일 사이클 CPU 코어(rv32i_core) Genus 합성 (학교 서버)
#
#   bash syn/ch05_single_cycle/run_syn.sh            # 클럭 주기 10 ns
#   bash syn/ch05_single_cycle/run_syn.sh 5          # 클럭 주기 5 ns
#
# - 먼저 GPDK045_DIR 환경 변수를 설정한다 (csh: setenv GPDK045_DIR <GPDK045 폴더>)
# - 실행 폴더: syn/ch05_single_cycle/runs/clk<주기>ns/ (log·report·mapped·unmapped, 커밋 안 함)
# - 끝나면 면적·slack 요약을 출력한다

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SYN_DIR="$(cd "$(dirname "$0")" && pwd)"
CLK_PERIOD="${1:-10.0}"

if [ -z "$GPDK045_DIR" ]; then
    echo "ERROR: GPDK045_DIR가 없음 → csh에서 setenv GPDK045_DIR <GPDK045 폴더> 후 다시 실행"
    exit 1
fi

RUN="$SYN_DIR/runs/clk${CLK_PERIOD}ns"
rm -rf "$RUN" && mkdir -p "$RUN/log" && cd "$RUN" || exit 1

export ROOT SYN_DIR CLK_PERIOD
echo "Syn Start : $(date)" | tee cds_syn_runtime
# 진행 상황은 화면에 그대로 보인다. stdin을 /dev/null로 두어, 스크립트 중간에 오류가 나도
# Genus 프롬프트에서 멈춰 기다리지 않고 끝나게 한다
genus -f "$SYN_DIR/genus.tcl" -log log/genus.log < /dev/null
STATUS=$?
echo "Syn End   : $(date)" | tee -a cds_syn_runtime

# ── 요약 ──
LOG="$(ls log/genus.log* 2>/dev/null | head -1)"
if [ $STATUS -ne 0 ] || ! grep -q "Synthesis Finished" "$LOG" 2>/dev/null; then
    echo "FAIL: 합성이 끝나지 않음 (로그: $RUN/$LOG)"
    grep -E "^Error|ERROR" "$LOG" 2>/dev/null | head -10
    exit 1
fi
echo ""
echo "== 결과: $RUN/report =="
echo "-- 면적 (report_area) --"
grep -E "^\s*rv32i_core\b|^\s*u_" report/09_rv32i_core_area.rpt | head -12
echo "-- 가장 나쁜 경로 slack (report_timing) --"
grep -iE "slack" report/20_rv32i_core_timing.rpt | head -3
echo "-- 위반 (report_constraint) --"
grep -ciE "VIOLATED" report/06_report_constraint.rpt | sed 's/^/위반 줄 수: /'
