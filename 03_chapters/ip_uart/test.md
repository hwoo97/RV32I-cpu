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

- 클럭 200 MHz(5 ns). 시험은 시간을 줄이려고 `BAUD = 3`(틱 = 4클럭, 1비트 = 64클럭)으로 돈다. 리셋 값(108) 읽기만 따로 확인
- 판정: 로그의 `PASS:`/`FAIL:` 줄. 실패하면 처음 20개 실패를 시간과 함께 출력

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
| — | 서버 Xcelium | 두 테스트벤치 | 미검증 | `run_uart_tests.sh` |

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
- 무작위 시험(9)만 실패, RX 바이트가 비어 있음 → 테스트벤치의 fork 두 갈래가 같은 반복 변수 `i`를 써서 서로 덮어씀 → 갈래마다 변수를 따로(`ti`, `ri`). RTL 문제 아님
- RX 타임아웃 기준: 처음에는 "시작 비트 확인"에서만 다시 셌는데, 시험을 쓰면서 "마지막 바이트가 들어온 뒤 문자 4개"가 맞다고 보고 바이트 수신(push)에서도 다시 세게 고침 (16550과 같은 뜻). design.md 6절 수정
