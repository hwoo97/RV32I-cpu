# ch06_uartip — 6장 MCU 칩에 UART IP 붙이기

> 6장 MCU 칩(`rv32i_chip`)의 단순 UART(`apb_uart`: 8N1, 1바이트 버퍼, 인터럽트 없음)를 직접 만든 [UART IP](../ip_uart/design.md)(`uart_top`)로 바꾼 칩입니다.
> 이 칩으로 실습 형식 흐름(RTL 시뮬 → 합성 → Pre-layout → PnR → Post-layout → STA·ECO → LEC)을 다시 진행합니다.
> 기존 6장 칩(`rtl/ch06_exception`, 프로젝트 방식 흐름 `syn/pnr/ec ch06_chip`)과 그 결과는 그대로 둡니다.
> 상태: RTL·PC 회귀 완료(2026-11-26). 서버 흐름은 진행 중입니다.

## 1. 바꾼 점
| 항목 | ch06_exception | ch06_uartip |
|------|------|------|
| UART | `apb_uart` (TXDATA·RXDATA·STATUS·BAUDDIV) | `rtl/ip_uart/uart_top` (FIFO 16단, 프레임 5~8비트·패리티·정지 비트, 인터럽트 8종) |
| APB 슬롯 | 2 (`0x4000_2000`, 4 KB) | 같음. UART IP는 원래 이 슬롯에 맞게 주소 12비트로 설계 |
| 인터럽트 | 타이머 → MTIP, EXT_IRQ 핀(2단 동기화) → MEIP | 타이머 → MTIP, **(EXT_IRQ 동기화 \| UART irq)** → MEIP |
| 보율 리셋 값 | BAUDDIV 433 (클럭/비트 − 1) | BAUD 26 (`PCLK / (16 × (DIV + 1))`, 50 MHz → 115,741 bps) |
| 칩 핀·패드 | `UART_RX`, `UART_TX` | 같음 (패드·핀 수 변화 없음) |
| 코어·CSR | — | 바뀌지 않음 |

- `rtl/ch06_uartip/`은 `rtl/ch06_exception/`을 복사해 `rv32i_mcu.v`(UART 인스턴스, irq OR)와 `mcu_top.v`(보율 파라미터)만 고쳤고, `apb_uart.v`는 뺐습니다. UART IP 파일은 `rtl/ip_uart/`를 그대로 읽습니다(`uart_defs.vh` include 폴더 추가).
- UART irq는 코어와 같은 클럭에서 나오므로 동기화하지 않고 OR합니다. 외부 인터럽트 처리기가 UART `ISR`을 읽어 두 원인(핀, UART)을 구분합니다. 레벨 인터럽트이므로 처리기가 원인을 지워야 합니다(RXDATA 읽기, W1C 등).

## 2. 검증 (PC xsim)
- `python sim/ch06_uartip/run_chip_tests.py`: 기존 칩 테스트벤치(`sim/ch06_exception/chip_tb.v`, `UART_RX = UART_TX` 핀 루프백) 그대로
- 새 시험 `sim/ch06_uartip/tests/uart_irq.S`
  1. 폴링: TXDATA에 쓴 바이트가 핀을 돌아 RXDATA로 들어옴
  2. RX 임계값 인터럽트: IER = RXTHR → mcause `0x8000000B` 한 번, 처리기에서 ISR.RXTHR 확인 → RXDATA 읽기 → `mret`, 두 번째 인터럽트 없음
  3. MIE = 0이면 `mip.MEIP`에만 보이고, MIE = 1이 되면 처리됨

| 날짜 | 묶음 | 결과 |
|------|------|------|
| 2026-11-26 | rv32ui / rv32mi / trap / uart | **40/40, 15/15, 3/3, 1/1 PASS** (`uart_irq` 1,590 사이클, 인터럽트 2) |
| 2026-11-26 | 버그 확인: irq OR를 뺀 RTL | `uart_irq` 시험 3(인터럽트)에서 FAIL → 시험이 연결을 확인함 |

- 미검증: C 펌웨어(`fw/common/uart.c`)는 아직 예전 UART 레지스터 맵이라 이 칩에서 `printf`가 동작하지 않음(펌웨어 시험은 ch06_exception 칩으로만 실행). FPGA(`mcu_top.v`)는 실행하지 않음

## 3. 실습 형식 흐름 (학교 서버, 저장소 안에서 실행)
| 단계 | 파일 | 상태 |
|------|------|------|
| RTL 시뮬 | `sim/ch06_uartip/run_function.tcl` (기본 프로그램 `uart_irq.hex`) | **PASS** (2026-11-26) |
| 합성 | `syn/ch06_uartip/run_synthesis`, `script/rv32i_chip_45nm.tcl`, `cons/rv32i_chip.sdc` | **MET** (2026-11-26) |
| Pre-layout | `sim/ch06_uartip/run_pre.tcl` (합성 넷리스트 + Genus SDF, 13 ns) | **PASS** (2026-11-26) |
| PnR, Post-layout, STA·ECO, LEC | (다음 단계) | — |

### 결과 (학교 서버)
| 날짜 | 단계 | 결과 |
|------|------|------|
| 2026-11-26 | RTL 시뮬 (Xcelium, PDK 패드 모델) | **PASS** `uart_irq.hex` — 1,589 사이클, 예외 5, 인터럽트 2, 끝 15,930 ns (PC xsim 1,590 사이클로 표시, 사이클 세는 시점 차이로 보임) |
| 2026-11-26 | 합성 (Genus, slow, 10.4 ns) | **MET, slack 0 ps** — `IMEM_DATA[23]` → 입력 패드 → 레지스터 파일 읽기 → ALU(주소 계산) → `DADDR[6]` (vclk, 입력 지연 3.0 + 데이터 경로 4.0 + 출력 지연 3.3 + 불확실성 0.1 = 10.4) |
| 2026-11-26 | 면적 | MCU(`u_mcu`) 셀 **34,840.9 µm²** (9,686셀) — UART IP(`u_uart`) 5,393.0 µm²(1,365셀), 레지스터 파일 14,902.7, ALU 5,232.6, CSR 4,029.8. 칩 전체 2,871,651.9 µm²는 패드 포함 |

| 2026-11-26 | Pre-layout (Genus SDF slow, 13 ns) | **PASS** `uart_irq.hex` — 1,589 사이클(RTL과 같음), 인터럽트 2, `Timing violation` 0, SDFINF 0. SDF 경로 지연 99.75 %(26,271/26,337), 타이밍 검사 58.07 %(setuphold 6,329/6,331 = 99.97 %, recovery 97.23 %, $hold·$width 0 % — Genus SDF에 없는 검사). 예외 수가 14로 나옴(RTL 5) → 아래 |

- **Pre-layout 예외 수 14 (RTL 5):** 결과 판정(TOHOST)과 사이클 수·인터럽트 수는 RTL과 같다. 예외 수는 `chip_tb`가 관찰 핀 `TRAP`을 **하강 에지**(13 ns 클럭의 6.5 ns)에서 세는데, `TRAP`은 pc → 패드 → 메모리 → 패드 → 디코드를 거치는 조합 출력이라 게이트 지연이 들어가면 하강 에지 뒤에야 안정된다. 그래서 중간 값이 세어진 것으로 본다(`IRQ_TAKEN`은 짧은 경로라 2로 맞음). SDC는 이 핀을 다음 상승 에지 기준(출력 지연 0)으로 제약하므로, 게이트 실행(`GATE_SDF*` 정의)에서는 **상승 에지**에서 세도록 `sim/ch06_exception/chip_tb.v`를 고쳤다(RTL 실행은 그대로, PC 회귀 같은 값). 재실행으로 5가 나오는지 확인 필요(미검증)
- UART IP 없는 칩(프로젝트 흐름, 같은 10.4 ns)은 MCU 30,531.7 µm²(8,599셀)였다. 차이 +4,309 µm²(+1,087셀)는 UART IP(5,393)에서 빠진 `apb_uart` 몫을 뺀 값으로 보임(코어 쪽 최적화 차이 포함, 정확한 분해는 미확인)
- 최악 경로는 예전과 같은 종류(명령어 핀 → 데이터 주소 핀, 메모리 왕복 예산 그대로)라 UART IP가 임계 경로에 들어오지 않음
