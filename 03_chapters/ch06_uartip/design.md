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
| PnR | `pnr/ch06_uartip/all.tcl`, `rv32i_chip.mmmc.view`, `rv32i_chip_func.sdc`, `rv32i_chip.io` | 첫 실행 InitDesign에서 오류 2개 → 수정(아래), 합성부터 다시 |
| Post-layout, STA·ECO, LEC | (다음 단계) | — |

### 결과 (학교 서버)
| 날짜 | 단계 | 결과 |
|------|------|------|
| 2026-11-26 | RTL 시뮬 (Xcelium, PDK 패드 모델) | **PASS** `uart_irq.hex` — 1,589 사이클, 예외 5, 인터럽트 2, 끝 15,930 ns (PC xsim 1,590 사이클로 표시, 사이클 세는 시점 차이로 보임) |
| 2026-11-26 | 합성 (Genus, slow, 10.4 ns) | **MET, slack 0 ps** — `IMEM_DATA[23]` → 입력 패드 → 레지스터 파일 읽기 → ALU(주소 계산) → `DADDR[6]` (vclk, 입력 지연 3.0 + 데이터 경로 4.0 + 출력 지연 3.3 + 불확실성 0.1 = 10.4) |
| 2026-11-26 | 면적 | MCU(`u_mcu`) 셀 **34,840.9 µm²** (9,686셀) — UART IP(`u_uart`) 5,393.0 µm²(1,365셀), 레지스터 파일 14,902.7, ALU 5,232.6, CSR 4,029.8. 칩 전체 2,871,651.9 µm²는 패드 포함 |

| 2026-11-26 | Pre-layout (Genus SDF slow, 13 ns) | **PASS** `uart_irq.hex` — 1,589 사이클(RTL과 같음), 인터럽트 2, `Timing violation` 0, SDFINF 0. SDF 경로 지연 99.75 %(26,271/26,337), 타이밍 검사 58.07 %(setuphold 6,329/6,331 = 99.97 %, recovery 97.23 %, $hold·$width 0 % — Genus SDF에 없는 검사). 예외 수가 14로 나옴(RTL 5) → 아래 |

- **Pre-layout 예외 수 14 (RTL 5):** 결과 판정(TOHOST)과 사이클 수·인터럽트 수는 RTL과 같다. 예외 수는 `chip_tb`가 관찰 핀 `TRAP`을 **하강 에지**(13 ns 클럭의 6.5 ns)에서 세는데, `TRAP`은 pc → 패드 → 메모리 → 패드 → 디코드를 거치는 조합 출력이라 게이트 지연이 들어가면 하강 에지 뒤에야 안정된다. 그래서 중간 값이 세어진 것으로 본다(`IRQ_TAKEN`은 짧은 경로라 2로 맞음). SDC는 이 핀을 다음 상승 에지 기준(출력 지연 0)으로 제약하므로, 게이트 실행(`GATE_SDF*` 정의)에서는 **상승 에지**에서 세도록 `sim/ch06_exception/chip_tb.v`를 고쳤다(RTL 실행은 그대로, PC 회귀 같은 값). 서버 재실행(2026-11-26): **PASS, 1,589 사이클, 예외 5, 인터럽트 2** — RTL과 모두 같음
- UART IP 없는 칩(프로젝트 흐름, 같은 10.4 ns)은 MCU 30,531.7 µm²(8,599셀)였다. 차이 +4,309 µm²(+1,087셀)는 UART IP(5,393)에서 빠진 `apb_uart` 몫을 뺀 값으로 보임(코어 쪽 최적화 차이 포함, 정확한 분해는 미확인)
- 최악 경로는 예전과 같은 종류(명령어 핀 → 데이터 주소 핀, 메모리 왕복 예산 그대로)라 UART IP가 임계 경로에 들어오지 않음

### PnR 첫 실행에서 나온 문제 (2026-11-26)
| 오류 | 원인 | 수정 |
|------|------|------|
| `IMPSP-365` init 직후: `CoreSiteDouble` 사이트 인스턴스 있음 | 처음에는 합성이 gsclib045의 유일한 이중 높이 셀 `BUFX2`를 썼다고 추정했으나, `BUFX2`를 막고 다시 합성한 결과가 면적까지 똑같아 **첫 넷리스트에도 `BUFX2`는 없었던 것으로 보임 — 원인 미확인** | 합성 dont_use에 `BUFX2` 추가(안전장치, 결과 영향 없음). `all.tcl`은 init 뒤 넷리스트에 이중 높이 인스턴스가 있으면 이름과 함께 멈추도록 검사 추가. 다음 실행에서 `IMPSP-365`가 다시 나오면 `CoreSiteDouble` 인스턴스 목록으로 원인 확인 |
| `IMPFP-7251`: IO 패드가 격자 위에 없음 | 1차 추정(전원 패드 좌표)은 틀림: 2·3차 실행에서 이 오류가 **`floorPlan`보다 앞(init 직후 `checkDesign`)**에 나옴. IO 파일에 오프셋이 없어 init이 패드를 끝수 있는 좌표(예 y 1463.505)로 고르게 펼침 → 서쪽 변 확인 결과 **모든 패드 옆에 0.3 µm 정도 틈**(필러 뒤 1463.2 → 패드 1463.505 등), 가장 좁은 IO 필러 1 µm로 못 메워 IO 링이 끊김. 오류와 틈은 같은 원인으로 추정(제조 격자 0.005 위반은 0, 어떤 격자 기준인지는 미확인) | 1차 0.1 µm 맞춤, 2차 앞 패드 기준 정수 µm(3차 실행은 붙여 넣은 내용이 1차 코드였음 — 좌표가 1차 계산값과 같음) → **3차: 변마다 모든 패드를 코너 기준 정수 µm 위치에 다시 배치**, `addIoFiller` 뒤 `ring_gaps`로 틈 수 출력. 다음 실행에서 IMPFP-7251·틈 0 확인 |
| IO 링 틈 5개 (`ring_gaps`, 4차 실행) | ① 패드 위치를 한 단계씩 반올림해 오차가 쌓임 → 변 끝 패드가 코너 안으로 4 µm 들어가고 필러가 겹침 ② 다이 3700이 높이만 0.19 격자로 3700.06이 되어 위 코너(3460.06) 옆에 0.06 µm 틈 | ① 패드마다 정확한 균등 위치를 반올림(오차가 쌓이지 않음, PC에서 패드 45~52개로 계산 확인) ② 다이 **3705 µm**(19 µm 배수). `ring_gaps`의 표준 셀(아직 (0,0)) 제외 버그도 수정 |
| `IMPFP-7251` (4차 실행) | 패드는 정수 µm에 놓였지만 배치 격자(y 0.19) 밖 인스턴스 477개로 그대로 → IO 셀이 표준 셀 배치 격자에 맞지 않는다는 검사로 봄(추정) | 1 µm 필러와 0.19 격자를 함께 맞출 수 없어 기록만 하고 진행. Chip Finish DRC·verifyConnectivity로 판단 |
| 4차 실행 결과 (InitDesign ~ CTS) | InitDesign: `IO ring gaps: 0`, 코어 박스 1150.0 1149.91 2555.0 2555.09. PowerPlan: 모든 하위 단계 DRC 0, 마지막 끊김 IMPVFC-200 2·-92 16(이전 칩 -96 12·-200 2·-92 398, IO 링 틈이 없어져 줄어든 것으로 봄). Placement: checkPlace 위반 0, 밀도 1.80 %, preCTS reg2reg +4.682. CTS 뒤 hold +0.008 위반 0 | — |
| CTS 뒤 IO setup −0.818(880 경로), max_tran 97넷(최대 1.154 ns, 한계 0.28) | 위반 넷은 모두 입력 패드 → 코어 넷(`gpio_in_*`, `imem_rdata_*`, `ram_rdata_*`, `irom_rdata_*`), 최악 경로는 `pc_reg` → 버퍼 → `PAD_IMEM_ADDR_0`(패드 줄 1.881 ns, 약 0.9 mm 배선 포함). SDC·코어·패드는 이전 칩과 같고 RC 코너만 다름: 실습 mmmc의 `-cap_table cln28hpl_...capTbl`은 28 nm 공정용 → 배선 RC 과대로 추정 | 사용자 결정: RC 코너에서 `-cap_table`을 빼고 45 nm QRC tech 파일만 사용(이전 칩과 같은 추출 데이터). init부터 다시 실행해 확인 |
| `IMPFP-7238` 경고: 코어 모서리(1150, 1149.91), (2550, 2550.15)가 배치 격자(0.2 × 0.19) 위에 없음 | AREAIO 패드로 줄어든 코어 박스를 `floorPlan`이 행 높이(1.71)에 맞춤 | 경고만, 행은 `createRow`로 다시 만듦. 영향은 배치 단계에서 확인 |

- 재합성(2026-11-26, `BUFX2` dont_use): Path 1 MET slack 0(같은 경로), `BUFX2` 인스턴스 0, MCU 34,840.908 µm²·9,686셀, UART IP 5,392.998 µm²·1,365셀 — 첫 합성과 같음. 그래서 위 합성·Pre-layout 결과는 그대로 유효

