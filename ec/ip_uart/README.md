# ec/ip_uart — UART IP 등가성 검사 (Conformal LEC, 실습 방식)

합성과 PnR이 UART IP의 논리 기능을 바꾸지 않았는지 Conformal LEC로 확인합니다.
스크립트는 교수님 실습 LEC 스크립트(`script_rtl2syn.tcl`, `script_syn2pnr.tcl`)와 같은 명령 순서입니다. 순서는 `read library` → `read design` → `set system mode lec` → `add compare points -all` → `compare` → `report`이고, 경로와 파일만 바꿨습니다.

| 비교 | golden (기준) | revised (비교 대상) | 스크립트 |
|------|------|------|------|
| RTL ↔ 합성 | `rtl/ip_uart` 6개 파일 | `syn/ip_uart/mapped/uart_top_syn_final.v` | [script_rtl2syn.tcl](script_rtl2syn.tcl) |
| 합성 ↔ PnR | 위 합성 넷리스트 | `pnr/ip_uart/uart_top_pnr.v` (계층 넷리스트) | [script_syn2pnr.tcl](script_syn2pnr.tcl) |

## 실습 스크립트와 다른 점
- **경로:** 이 폴더(`ec/ip_uart`)에서 실행하는 저장소 상대 경로입니다.
- **라이브러리:** 표준 셀 Verilog 모델은 slow 하나만 읽습니다. 셀의 논리 기능은 slow와 fast가 같고, 블록에는 패드가 없어 패드 모델도 읽지 않습니다. 모델 파일은 PDK 원본이라 저장소에 넣지 않으므로, 실행 폴더의 `lib/`에 링크합니다.
- **include 파일:** RTL이 `` `include "uart_defs.vh" ``를 쓰므로 실행 폴더에 `uart_defs.vh` 링크를 둡니다. `read design`에는 include 폴더 옵션이 없습니다(`-incdir`는 `not a legal option`). ch06 LEC와 같은 방식입니다.
- **rtl2syn 매핑 옵션:** `set flatten model -seq_constant`와 `-seq_constant_x_to 0`을 넣었습니다. Genus가 만드는 dofile, ch06 LEC와 같은 설정입니다.
- **매핑 확인:** 비교 전에 `report unmapped points`로 매핑되지 않은 점을 출력합니다.

## 실행 순서

1. **학교 서버에서 묶기.** 저장소 루트에서 실행합니다. 합성과 PnR(계층 넷리스트)이 끝난 상태여야 합니다.
   ```
   tar czf ~/lec_ip_uart.tar.gz ec/ip_uart rtl/ip_uart syn/ip_uart/mapped/uart_top_syn_final.v pnr/ip_uart/uart_top_pnr.v
   ```
2. **LEC 서버로 옮겨 풀기.** 이전에 풀어 둔 폴더가 있으면 먼저 지웁니다.
   ```
   cd ~ ; rm -rf uart_lec ; mkdir uart_lec ; cd uart_lec ; tar xzf ~/lec_ip_uart.tar.gz
   cd ec/ip_uart ; mkdir log lib
   ln -s ../../rtl/ip_uart/uart_defs.vh .
   ln -s <GPDK045 폴더>/digital/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v lib/
   ```
   `<GPDK045 폴더>`는 LEC 서버에서도 루트(`/`) 바로 아래의 GPDK045입니다. `ls -l lib/`로 링크가 실제 파일을 가리키는지 확인합니다. 링크가 깨져 있으면 `read library`에서 `Cannot open file`이 납니다.
3. **실행.** 둘 중 하나로 합니다.
   - 일괄: `lec -xl -dofile script_rtl2syn.tcl`. 끝나면 `exit`로 닫고, `script_syn2pnr.tcl`도 같은 방법으로 실행합니다.
   - 대화형: `lec -xl`로 띄운 뒤 스크립트 줄을 차례로 붙여 넣으며 중간 결과를 봅니다. 다른 비교로 넘어가기 전에는 `reset`을 입력합니다.

## 확인할 것
- `read design`에서 `Error`가 없어야 합니다.
- top 모듈이 `uart_top`이어야 합니다.
- `report unmapped points` 결과:
  - rtl2syn은 합성이 상수로 바꾸거나 지운 레지스터만 나와야 합니다.
  - syn2pnr은 아무것도 나오지 않아야 합니다.
- `compare` 요약에 `Non-equivalent` 0, `Abort` 0이 나오면 PASS입니다.

## 결과
두 비교 모두 PASS입니다. 첫 시도에서 나온 문제는 두 가지였습니다. `lib/` 링크가 없어 `Cannot open file`이 났고(GPDK045는 `/` 아래), `-incdir`가 허용되지 않는 옵션이었습니다. 두 번째는 `uart_defs.vh` 링크로 바꿨습니다.

| 날짜 | 비교 | 결과 | 비고 |
|------|------|------|------|
| 2026-11-25 | rtl2syn | **PASS** — 매핑 PI 50·PO 36·DFF 455(unmapped 0), Equivalent PO 36·DFF 455 = 491 | 대화형 붙여 넣기, `uart_defs.vh` 링크. 계층 golden·revised 같음(u_baud, u_regs, u_rx, u_rxf, u_tx, u_txf). Verification Report 나머지 항목 0 |
| 2026-11-25 | syn2pnr | **PASS** — 매핑 PI 50·PO 36·DFF 455(unmapped 0), Equivalent PO 36·DFF 455 = 491 | `reset` 뒤 같은 창. revised 최상위 셀 46개(golden 10개): PnR이 최상위에 넣은 버퍼로 보이며, 비교 점에는 영향 없음. Verification Report 나머지 항목 0 |
