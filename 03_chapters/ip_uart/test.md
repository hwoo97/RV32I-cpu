# UART IP (`ip_uart`) 테스트 기록

설계: [design.md](design.md) · RTL: [rtl/ip_uart/](../../rtl/ip_uart/) · 테스트벤치: [sim/ip_uart/](../../sim/ip_uart/)

## 1. 실행 방법

| 환경 | 명령 |
|------|------|
| PC xsim, 두 테스트벤치 | `python sim/ip_uart/run_uart_tests.py` |
| PC xsim, 파형 | `python sim/ip_uart/run_uart_tests.py --gui uart_top_tb` |
| PC xsim, 버그 모델 | `python sim/ip_uart/run_bug_models.py` |
| 서버 Xcelium, 일괄 | `bash sim/ip_uart/run_uart_tests.sh` |
| 서버 Xcelium, SimVision | `bash sim/ip_uart/run_uart_tests.sh --gui uart_top_tb` |
| 서버 xrun 직접 (저장소 루트에서) | `xrun -f sim/ip_uart/uart_rtl.f -top uart_top_tb sim/ip_uart/uart_top_tb.v -l uart_top.log` |
| 서버 게이트 시뮬, 느린 코너 (sim/ip_uart에서, csh) | `source run_post_max.tcl` (PnR 넷리스트·`uart_top_slow.sdf` 복사, `+define+sdf_post_wst`) |
| 서버 pre-layout 게이트 시뮬 (sim/ip_uart에서, csh) | `source run_pre.tcl` (합성 넷리스트·`uart_top_delays.sdf` 복사, `+define+sdf_gate`) |
| 서버 게이트 시뮬, 빠른 코너 | `source run_post_min.tcl` (`uart_top_fast.sdf`, `+define+sdf_post_bst`) |

- 클럭 200 MHz(5 ns). 시험은 시간을 줄이려고 `BAUD = 3`(틱 = 4클럭, 1비트 = 64클럭)으로 돈다. 리셋 값(108) 읽기만 따로 확인
- 판정: 로그의 `PASS:`/`FAIL:` 줄. 실패하면 처음 20개 실패를 시간과 함께 출력
- 게이트 시뮬(실습 방식): 같은 `uart_top_tb`를 PnR 넷리스트 + 표준 셀 Verilog 모델 + SDF로 돌린다. hex 파일은 필요 없다(테스트벤치가 APB 버스를 직접 구동). 게이트 실행에서만 바뀌는 것
  - `$sdf_annotate`: 느린 코너 MAXIMUM, 빠른 코너 MINIMUM (로그 `sdf_post_wst.log`·`sdf_post_bst.log`)
  - `uart_rx` 핀을 다음 클럭 하강 에지로 옮겨 준다(최대 1클럭 지연). 실제 비동기 입력이면 동기화 첫 플립플롭이 setup/hold 검사에 걸려 X가 되기 때문. PC에서 이 경로만 RTL로 켜서 PASS 확인(4,119 검사)
  - 리셋 해제는 RTL·게이트 모두 하강 에지(25 ns)로 옮김(복구·제거 검사)
  - APB 입력을 상승 에지 뒤 1.5 ns(SDC 입력 지연)에 바꾼다(`APB_DRIVE_DELAY`, 공용 `apb_master.vh`에 선택 define 추가). 하강 에지 구동은 SDC가 약속한 3.4 ns보다 짧은 2.5 ns만 남겨, 첫 느린 코너 실행에서 TX FIFO 쓰기가 일부 비트만 저장됨(아래 6절). 트랜잭션 사이 쉬는 사이클이 1개 늘어 폴링 읽기 수가 줄므로 검사 수가 RTL보다 적음(PC에서 이 경로를 RTL로 켜면 3,517 검사 PASS)
  - 확인: `PASS:` 줄, `Timing violation` 줄 없음, SDF 로그에 `*E` 없음, xmelab SDF statistics `Annotated` 경로 지연·타이밍 검사 거의 100 %(`SDFINF` 경고 없음)

## 2. `uart_fifo_tb` — FIFO 단위

| 검사 | 내용 |
|------|------|
| 채우기·비우기 | 18번 쓰기(16 + 넘침 2) → 가득, 쓰기 무시 / 18번 읽기 → 순서, 빈 FIFO 읽기 무시 |
| 동시 쓰기·읽기 | 빈 상태·중간·가득 상태에서 |
| 비우기(clr) | 중간에, 쓰기·읽기와 같은 클럭에 |
| 무작위 | 5000클럭, 기준 큐와 매 클럭 count·full·empty·rdata 비교 |

## 3. `uart_top_tb` — IP 전체

| # | 시험 | 확인 |
|:---:|------|------|
| 1 | 리셋 값, PSLVERR | 레지스터 리셋 값, TXDATA 읽기·RXDATA/STATUS 쓰기·없는 오프셋·정렬 안 된 주소 → PSLVERR, 값 안 바뀜 |
| 2 | 송신 24형식 | 데이터 5~8 × 패리티 없음/홀/짝 × 정지 1/2, 형식마다 2바이트를 감시기가 받아 비교(시작·패리티·정지 비트 포함) |
| 3 | 수신 24형식 | 같은 24형식을 BFM이 보내고 RXDATA로 비교 |
| 4 | FIFO | TX 끈 채 16개 → TX_FULL, 17번째 TXOVR, W1C / 수신 17개 → RX_FULL, RXOVR, 앞 16개 순서 / CTRL[9:8] 비우기 |
| 5 | 오류 | 패리티 틀림 → RXDATA[8]·PERR, 정지 비트 0 → RXDATA[9]·FERR, 깨진 정지 비트 뒤 가짜 바이트 없음, W1C(FERR만 지우면 PERR는 남음) |
| 6 | 인터럽트 | RXTHR(임계값 4), TXTHR(임계값 2), TXDONE, RXTO(문자 4개 시간 앞뒤), 오류(PERR) + W1C |
| 7 | 루프백 | TX → RX 8바이트, `uart_tx` 핀은 계속 1, `uart_rx` 핀(0으로 둠)은 무시 |
| 8 | 잡음·오차 | 빈 선의 짧은 0 펄스 4번 → 바이트·오류 없음 / 모든 데이터 비트에서 가운데 근처를 0.9틱 뒤집기(위치를 비트마다 반 틱씩 옮겨 어느 비트에선 8번째 샘플에 맞음, 한 비트에 샘플 둘은 안 걸림) → 다수결로 정상 / 보내는 쪽 보율 +3 %·−3 %(8N1, 8E2) |
| 9 | 무작위 | 30회: 무작위 형식, CPU 쪽 송신(TX_FULL 확인하며 1~20바이트)과 선 쪽 수신(1~12바이트, 간격 무작위)을 동시에 |

## 4. 결과

| 날짜 | 환경 | 테스트벤치 | 결과 | 비고 |
|------|------|------|------|------|
| 2026-11-24 | PC xsim | uart_fifo_tb | **PASS** (19,756 검사) | |
| 2026-11-24 | PC xsim | uart_top_tb | **PASS** (4,119 검사, TX 프레임 344) | 버그 모델 보강 뒤 |
| 2026-11-24 | 서버 Xcelium | uart_fifo_tb, uart_top_tb | **PASS** (19,756 / 4,119 검사, TX 프레임 344) | `run_uart_tests.sh`, 검사 수가 PC xsim과 같음 |
| 2026-11-24 | 서버 Xcelium SimVision | uart_top_tb | **PASS** (`errors` 0, `checks` 4119, 끝 시각 1,701,588,500 ps) | 실습 방식 `run_function.tcl`, 파형 확인 |
| 2026-11-25 | 서버 Xcelium, 게이트 느린 코너 | uart_top_tb | **PASS** (3,517 검사, TX 프레임 344, 끝 시각 1,703,528,500 ps) | `run_post_max.tcl`, 계층 넷리스트 + slow SDF. SDF 경로 지연 100 %(3,796), 타이밍 검사 87.54 %(2,599/2,969), SDFINF 없음, `Timing violation` 0 |
| 2026-11-25 | 서버 Xcelium, 게이트 빠른 코너 | uart_top_tb | **PASS** (3,517 검사, TX 프레임 344, 끝 시각 1,703,528,500 ps) | `run_post_min.tcl`, fast SDF(MINIMUM). SDF 경로 지연 100 %, 타이밍 검사 87.54 %, `Timing violation` 0 |

## 5. 버그 모델

`run_bug_models.py`가 RTL 복사본(`sim/build/uart_bugs/<이름>/`)에서 한 줄만 바꿔 `uart_top_tb`를 돌린다. 실제 RTL은 바꾸지 않는다.

| 버그 | 바꾼 곳 | 검출 | 잡은 검사 |
|------|------|:---:|------|
| TX 패리티 비트 반전 | uart_tx.v | ✓ | 송신 프레임 패리티 |
| TX 정지 비트 항상 1개 | uart_tx.v | ✓ | 송신 프레임 정지 비트 |
| RX 다수결 대신 8번째 샘플만 | uart_rx.v | ✓ (시험 8 보강 뒤) | 잡음 수신 데이터 |
| RX 시작 비트 잡음 거르기 없음 | uart_rx.v | ✓ | 잡음 뒤 RXDATA |
| RX 7비트 데이터 정렬 한 칸 어긋남 | uart_rx.v | ✓ | 수신 24형식 |
| FIFO가 한 칸 일찍 가득 | uart_fifo.v | ✓ | STATUS TX 개수 |
| RX 타임아웃이 바이트 수신에서 다시 세지 않음 | uart_regs.v | ✓ | RXTO 시점 |
| ISR 아무 쓰기나 PERR를 지움 | uart_regs.v | ✓ (시험 5 보강 뒤) | W1C 한 비트만 |
| 루프백에서 uart_tx 핀을 1로 두지 않음 | uart_top.v | ✓ | 루프백 핀 |

- 2026-11-24 PC xsim: **9/9 검출**. 처음 돌렸을 때는 7/9였다
  - 다수결 버그를 놓친 이유: 비트 하나만 1/20비트(약 0.8틱) 뒤집어서, 8번째 샘플에 맞지 않을 때가 있었음 → 모든 데이터 비트에서 위치를 옮겨 가며 뒤집도록 바꿈
  - W1C 버그를 놓친 이유: 두 비트를 한 번에 지우는 경우만 시험함 → 한 비트만 지우고 다른 비트가 남는지 확인 추가

## 6. 문제와 해결

### 게이트 시뮬 첫 실행: TX 데이터 412개 오류 (2026-11-24)
- 증상: 느린 코너에서 `FAIL: uart_top_tb (412 errors in 4108 checks)`. 처음 20개가 모두 test 2 `TX data`, 첫 프레임 `XX`, 이후 값은 기댓값과 직전 값의 비트가 섞임. `Timing violation` 0, SDF 경고 12·오류 0
- 원인(추정): 테스트벤치가 APB 입력을 하강 에지에서 바꿔 `penable` → TX FIFO 쓰기 경로에 2.5 ns만 남음. PnR은 SDC(입력 지연 1.5 ns → 3.4 ns 예산)로 이 경로를 slack +0.100으로 맞춤(default 그룹 최악). 데이터가 다음 에지의 hold 창보다도 늦게 도착하면 셀 모델은 위반 없이 이전 값을 잡으므로, 같은 FIFO 칸의 이전 값과 새 값이 비트마다 섞임
- 해결: 게이트 실행에서만 BFM이 상승 에지 뒤 1.5 ns에 구동 (회로는 그대로). 서버 재실행으로 확인 필요(미검증)
- **정정 (같은 날, 재실행 로그):** 이 실행은 SDF가 거의 적용되지 않은 상태였다. xmelab `*W,SDFINF: Instance u_tx (u_txf, u_regs, u_rxf, u_baud, u_rx) not found` 12개, `Annotated = 1.32 % (50/3796)` 경로 지연, `0.00 % (0/2969)` 타이밍 검사. 원인은 PnR 넷리스트를 `saveNetlist -flat`으로 써서 계층(u_tx …)이 없어졌는데 SDF는 계층 이름으로 쓰였기 때문. 타이밍 검사가 적용되지 않았으니 `Timing violation` 0도 의미가 없고, 위 원인 추정은 확인되지 않은 것으로 둔다
  - 해결: all.tcl을 계층 넷리스트(`saveNetlist uart_top_pnr.v`)로 바꿈. APB 구동 시점 수정은 SDC 가정에 맞춘 것이라 그대로 둔다
  - 게이트 실행 확인 항목에 추가: SDF statistics의 `Annotated`가 경로 지연·타이밍 검사 모두 100 %에 가까운지, `SDFINF` 경고가 없는지
- 무작위 시험(9)만 실패, RX 바이트가 비어 있음 → 테스트벤치의 fork 두 갈래가 같은 반복 변수 `i`를 써서 서로 덮어씀 → 갈래마다 변수를 따로(`ti`, `ri`). RTL 문제 아님
- RX 타임아웃 기준: 처음에는 "시작 비트 확인"에서만 다시 셌는데, 시험을 쓰면서 "마지막 바이트가 들어온 뒤 문자 4개"가 맞다고 보고 바이트 수신(push)에서도 다시 세게 고침 (16550과 같은 뜻). design.md 6절 수정
