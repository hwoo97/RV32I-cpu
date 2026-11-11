# ch14a MCU 테스트 기록

## 1. 코어 대기(stall) — `rtl/ch14a_mcu/rv32i_core.v`
3단계 코어에 `dmem_ready` 입력을 더했다 ([design.md](design.md) 3절). load/store를 냈는데 `dmem_ready = 0`이면 PC와 레지스터 파일을 그대로 두어 같은 명령어를 다음 사이클에 다시 실행한다.

실행 방법
- 이 PC (xsim)
```bash
python sim/ch14a_mcu/run_core_wait.py 30
```
- 학교 서버 (Xcelium) — 일괄
```bash
bash sim/ch14a_mcu/run_core_wait.sh 30
```
- 학교 서버 — 대화형 (테스트 하나를 SimVision으로, 콘솔에서 `run 200ns`)
```bash
bash sim/ch14a_mcu/run_core_wait.sh 30 --gui lw
```
- 첫 인자 = 대기 비율 %(매 사이클 `dmem_ready = 0`일 확률, 기본 30). 다른 무작위 순서: csh에서 `env SEED=7 bash sim/ch14a_mcu/run_core_wait.sh 30`
- 테스트벤치 [core_wait_tb.v](../../sim/ch14a_mcu/core_wait_tb.v): 3단계 메모리 모델(8 KB)과 같은 riscv-tests hex 사용, DMEM 쓰기는 대기가 끝나는 클럭 에지에서만

테스트벤치가 확인하는 것
- riscv-tests 판정 (tohost, trap, 타임아웃)
- **대기 중 요청 고정**: 기다리는 동안 `dmem_re`·`dmem_addr`·`dmem_wstrb`·`dmem_wdata`가 바뀌면 FAIL
- 요청이 없을 때도 `dmem_ready`를 무작위로 0으로 만듦 → 코어가 무시해야 함
- 끝난 명령어 수(retired = 전체 사이클 − 대기 사이클)를 출력 → 3단계 사이클 수와 같아야 함

| 날짜 | 대기 비율 | 결과 | 전체 사이클 (40개 합) | 대기 사이클 | retired = 3단계 사이클 | 비고 |
|------|---------:|------|---------------------:|-----------:|:---------------------:|------|
| 2026-11-12 | 0 % | **40 / 40 PASS** | 13,067 | 0 | 40 / 40 같음 | xsim, SEED 1. 대기가 없으면 3단계와 완전히 같은 동작 |
| 2026-11-12 | 30 % | **40 / 40 PASS** | 13,460 | 393 | 40 / 40 같음 | 예: ld_st 1,160 사이클 = 957 + 대기 203 |
| 2026-11-12 | 70 % | **40 / 40 PASS** | 15,118 | 2,051 | 40 / 40 같음 | |
| 2026-11-12 | 30 % | **40 / 40 PASS** | | | | 학교 서버 Xcelium (`run_core_wait.sh 30`). SimVision 파형으로 대기 중 PC·요청 유지, 완료 사이클에만 레지스터 쓰기 확인 (사용자) |

버그 모델 (일부러 고장 낸 코어로 테스트벤치가 잡는지 확인, 대기 30 %)
| 버그 | 결과 | 잡은 방법 |
|------|------|-----------|
| 대기 중에도 레지스터 파일에 씀 | 1 FAIL (ld_st) | `lw x?, 0(x?)`처럼 rd = rs1인 load에서 대기 중 주소 레지스터가 바뀌어 "요청 변경" 검출 |
| 대기 중에도 PC가 넘어감 | 17 FAIL | 요청 변경 검출 |
| store일 때 대기하지 않음 (load만 대기) | 16 FAIL | tohost 쓰기가 사라져 타임아웃 |
- 레지스터 파일 버그는 rd = rs1인 load에서만 드러난다. rv32ui 안에서는 ld_st 하나뿐이라, MCU 단계 테스트에서 이 경우를 직접 넣은 시험을 추가할 예정

## 2. 주소 표 생성 — `tools/gen_memmap.py`
| 날짜 | 시험 | 결과 | 비고 |
|------|------|------|------|
| 2026-11-12 | 생성·`--check` | 통과 | 표 7개 영역 → `mcu_memmap.vh`·`memmap.h`·`memmap.ld`, 다시 실행하면 변화 없음 |
| 2026-11-12 | Verilog 매크로 (xsim) | PASS | 영역 첫·끝·끝+1 주소의 `_HIT`, APB 슬롯 비트, `_AW` — 14개 검사 |
| 2026-11-12 | C·어셈블리·링커 (WSL `riscv64-unknown-elf-gcc`) | 통과 | `memmap.h`를 .c와 .S에서 include, `INCLUDE memmap.ld`로 링크 → `.text` 0x0, `.data` 실행 주소 0x1000_0000·저장 주소 IMEM, `sp = 0x1000_4000` |
| 2026-11-12 | 표 오류 검출 | 8/8 검출 | 겹침, 정렬, 2의 거듭제곱 아님, APB 슬롯 중복, APB 창 밖, 이름 중복, 잘못된 종류 |
- 시험용 링크에서 `.data`의 저장 주소가 4바이트 정렬이 아니었다(0x27). 실제 `link.ld`를 만들 때 crt0가 워드 단위로 복사하도록 `ALIGN(4)`를 넣는다

## 3. 주소 디코더·APB 브리지 — `bus_mux.v`, `apb_bridge.v`
실행 방법
- 이 PC (xsim)
```bash
python sim/run_sim.py bus_tb rtl/ch14a_mcu/bus_mux.v rtl/ch14a_mcu/apb_bridge.v sim/ch14a_mcu/bus_tb.v
```
- 학교 서버 (Xcelium) — 일괄, 끝에 `--gui`를 붙이면 대화형
```bash
bash sim/run_xrun.sh bus_tb rtl/ch14a_mcu/bus_mux.v rtl/ch14a_mcu/apb_bridge.v sim/ch14a_mcu/bus_tb.v
```
- 슬레이브 대기 비율은 기본 30 % (`+WAITPCT=<n>`), 무작위 순서 `+SEED=<n>`

테스트벤치 [bus_tb.v](../../sim/ch14a_mcu/bus_tb.v)
- 모형 마스터: 코어처럼 `dmem_ready`가 1이 될 때까지 요청을 유지
- 모형 메모리: IMEM(데이터 쪽 읽기), DMEM(바이트 쓰기). 모형 APB 슬레이브: 슬롯 0·1·2·15 (레지스터 4 KB, 무작위 `PREADY` 대기, 오프셋 `0xFFC`에서 `PSLVERR`), 나머지 슬롯은 "슬레이브 없음"(`PREADY = 1`, `PSLVERR = 1`)
- 기준 모델이 읽기 값·오류·사이클 수(메모리 1사이클, APB 2사이클 이상)·APB 전송 횟수를 예측해 비교
- **APB 프로토콜 검사**(매 사이클): `PSEL` 하나만, `PENABLE`은 `PSEL`과 함께, SETUP 다음은 ACCESS, ACCESS는 SETUP이나 대기 중 ACCESS 다음에만, 전송 중 `PSEL`·`PADDR`·`PWRITE`·`PWDATA` 고정
- 정해진 시험 19개 + 가져오기 주소 검사 5개 + 무작위 접근 4,000개

| 날짜 | 슬레이브 대기 | 결과 | 비고 |
|------|-------------:|------|------|
| 2026-11-12 | 0 % | **PASS** | xsim, 4,019 접근, APB 전송 1,314 |
| 2026-11-12 | 30 % | **PASS** | xsim, 4,019 접근, APB 전송 1,377 |
| 2026-11-12 | 80 % | **PASS** | xsim, 4,019 접근, APB 전송 1,326 |
| 2026-11-12 | 30 % | **PASS** | 학교 서버 Xcelium, 사용자 확인 (수치 미기록) |

버그 모델 (모두 검출)
| 버그 | 잡은 검사 |
|------|-----------|
| SETUP 단계 없이 바로 ACCESS | 프로토콜: ACCESS without SETUP |
| `PREADY`를 보지 않고 끝냄 | APB 전송 횟수, 전송 중 신호 변경 |
| 주변장치에 sb·sh 허용 | `data_err`, 사이클 수 |
| APB 접근인데 코어를 멈추지 않음 | APB 2사이클 미만, 전송 횟수 |
| IMEM 쓰기를 오류로 안 봄 | `data_err` |
| `PSLVERR` 무시 | `data_err` (오류 오프셋, 빈 슬롯) |
| 가져오기 주소 검사 없음 | `fetch_err` |
| DMEM이 아닌 주소에서도 DMEM에 씀 | 읽기 값 |
- 시험 중 고친 것: 처음에는 프로토콜 검사를 하강 에지에서 했는데, 모형 마스터도 하강 에지에서 요청을 바꿔 실행 순서에 따라 SETUP 사이클을 놓쳤다(테스트벤치의 경쟁 조건) → 검사를 상승 에지(끝난 사이클의 값)로 옮김

## 4. GPIO — `apb_gpio.v`
실행 방법
- 이 PC (xsim)
```bash
python sim/run_sim.py gpio_tb rtl/ch14a_mcu/apb_gpio.v sim/ch14a_mcu/gpio_tb.v
```
- 학교 서버 (Xcelium) — 일괄, 끝에 `--gui`를 붙이면 대화형
```bash
bash sim/run_xrun.sh gpio_tb rtl/ch14a_mcu/apb_gpio.v sim/ch14a_mcu/gpio_tb.v
```

테스트벤치 [gpio_tb.v](../../sim/ch14a_mcu/gpio_tb.v)
- 한 APB 버스에 GPIO 두 개(`GPIO_W` 16, 32)를 달아 폭이 다른 경우를 같이 확인
- APB 마스터 태스크는 공용 파일 [apb_master.vh](../../sim/ch14a_mcu/apb_master.vh) (Timer·UART 테스트에서도 씀): SETUP → ACCESS → `PREADY` 대기, 걸린 사이클 수 기록
- 확인: 리셋 값, 쓰기·읽기(폭 밖 비트는 0), 핀 출력, 입력 동기화(바뀐 핀 값이 2번째 상승 에지 뒤에 보임), 오류(DATA_IN 쓰기·없는 오프셋 → `PSLVERR`, 값 그대로, 읽기 0), SETUP만 있고 ACCESS 없는 전송은 쓰지 않음, 모든 전송 2사이클, 무작위 3,000회

| 날짜 | 결과 | 비고 |
|------|------|------|
| 2026-11-12 | **PASS** | xsim, APB 전송 3,026회 |
| 2026-11-12 | **PASS** | 학교 서버 Xcelium, 사용자 확인 (수치 미기록) |

버그 모델
| 버그 | 결과 |
|------|------|
| 동기화 플립플롭 1단 | 검출 (1번째 에지 뒤에 새 값이 보임) |
| SETUP에서 씀 (`PENABLE` 무시) | 검출 |
| DATA_IN 쓰기를 오류로 안 봄 | 검출 |
| DIR 쓰기가 DATA_OUT에 들어감 | 검출 |
| 주소 일부만 디코드 (아래 4비트) | 검출 (무작위 시험에서 다른 오프셋이 DATA_OUT으로 보임) |
| ACCESS가 아닐 때도 `PSLVERR` | 검출 안 됨 — **규격 위반이 아님**: APB3에서 `PSLVERR`는 마지막 ACCESS 사이클에만 의미가 있고 브리지도 그때만 본다 |

## 5. TIMER — `apb_timer.v`
실행 방법
- 이 PC (xsim)
```bash
python sim/run_sim.py timer_tb rtl/ch14a_mcu/apb_timer.v sim/ch14a_mcu/timer_tb.v
```
- 학교 서버 (Xcelium) — 일괄, 끝에 `--gui`를 붙이면 대화형
```bash
bash sim/run_xrun.sh timer_tb rtl/ch14a_mcu/apb_timer.v sim/ch14a_mcu/timer_tb.v
```

테스트벤치 [timer_tb.v](../../sim/ch14a_mcu/timer_tb.v)
- **사이클 단위 기준 모델**: DUT와 같은 상승 에지에서 따로 계산한 COUNT·CTRL·CMP·MATCH를 매 사이클 비교, APB 읽기마다 PRDATA, 전송마다 PSLVERR 비교
- 정해진 시험: CMP = 10 단발 → EN 뒤 정확히 11번째 에지에 MATCH, AUTO 없이는 계속 셈 / CMP = 4 자동 재시작 → 5클럭마다 일치 / W1C / 같은 사이클의 새 일치가 지우기보다 우선 / irq = IE & MATCH / EN = 0이면 멈춤 / 셀 때도 COUNT 쓰기가 우선, 0xFFFFFFFF 넘김 / 없는 오프셋 오류
- 무작위 3,000회 (COUNT·CMP는 0~23의 작은 값이라 일치가 자주 생김), 사이사이 0~3 사이클 쉼

| 날짜 | 결과 | 비고 |
|------|------|------|
| 2026-11-12 | **PASS** | xsim, 읽기 비교 1,473회, 일치 127회 |
| 2026-11-12 | **PASS** | 학교 서버 Xcelium, 사용자 확인 (수치 미기록) |

버그 모델 (모두 검출)
| 버그 | 잡은 검사 |
|------|-----------|
| 자동 재시작 값이 1 (주기가 1 짧음) | 매 사이클 COUNT 비교 |
| EN = 0인데도 일치 판정 | MATCH 비교 |
| 지우기가 새 일치보다 우선 | "set wins over clear" 시험 |
| STATUS에 0을 써도 지워짐 (W1C 아님) | MATCH 비교 (무작위) |
| irq가 IE를 보지 않음 | irq 비교 |
| 셀 때는 COUNT 쓰기가 무시됨 | COUNT 비교 |

## 6. UART — `apb_uart.v`
실행 방법
- 이 PC (xsim)
```bash
python sim/run_sim.py uart_tb rtl/ch14a_mcu/apb_uart.v sim/ch14a_mcu/uart_tb.v
```
- 학교 서버 (Xcelium) — 일괄, 끝에 `--gui`를 붙이면 대화형
```bash
bash sim/run_xrun.sh uart_tb rtl/ch14a_mcu/apb_uart.v sim/ch14a_mcu/uart_tb.v
```

테스트벤치 [uart_tb.v](../../sim/ch14a_mcu/uart_tb.v)
- **송신 모니터**: `uart_tx`의 시작 비트 하강 에지부터 **자기 시간 기준**(비트 중앙)으로 프레임을 해독해 예상 바이트와 비교, 시작·정지 비트와 정지 비트 길이 확인
- **수신 드라이버**: 비트 시간을 바꿔(±3 %) 8N1 프레임 전송, 정지 비트 0(프레임 오류), 2클럭 글리치
- **루프백**: `uart_rx = uart_tx`로 BAUDDIV 3·5·16·100에서 무작위 40바이트씩, STATUS를 폴링하며 보내고 받기 (펌웨어와 같은 방식)
- 정해진 시험: 리셋 값, 방향 틀린 접근·없는 오프셋 오류, 1바이트 송신(아래 8비트만), 버퍼(2번째 바이트는 대기 → `TX_FULL`, 3번째는 무시), 수신·`RX_VALID` 지우기, 오버런(새 바이트로 바뀜, STATUS 읽으면 지워짐), 프레임 오류, 글리치 무시

| 날짜 | 결과 | 비고 |
|------|------|------|
| 2026-11-12 | **PASS** | xsim, 송신 프레임 163개 확인 (정해진 시험 3 + 루프백 160) |
| 2026-11-12 | **PASS** | 학교 서버 Xcelium, 사용자 확인 (수치 미기록) |

버그 모델 (모두 검출)
| 버그 | 잡은 검사 |
|------|-----------|
| 수신 비트 순서 반대 (MSB 먼저) | 수신 데이터 (0x3C는 앞뒤가 같아 통과, 다음 바이트에서 검출) |
| 비트 중앙이 아니라 경계에서 샘플 | 글리치, ±3 % 수신 |
| 송신 버퍼가 차 있어도 덮어씀 | 송신 모니터 (0x80 대신 0xFF) |
| 오버런 표시 없음 | STATUS |
| 정지 비트 검사 없음 | 프레임 오류 시험 |
| 글리치를 시작 비트로 받음 | 글리치 시험, 루프백 |
| 송신 정지 비트 빠짐 | 송신 모니터 (정지 비트) |
| RXDATA를 읽어도 RX_VALID 유지 | STATUS |

## 7. MCU 전체 — `rv32i_mcu.v`, `mcu_top.v` (riscv-tests)
구성: `mcu_top` = `rv32i_mcu`(코어 + 디코더 + APB 브리지 + GPIO·TIMER·UART, 빈 슬롯은 `PREADY = 1`·`PSLVERR = 1`) + `mcu_imem`(16 KB, 읽기 포트 2) + `mcu_dmem`(16 KB). 테스트벤치는 DMEM 쓰기 포트를 지켜보는 TOHOST 감시기([tohost_mon.v](../../sim/ch14a_mcu/tohost_mon.v))로 결과를 받는다 (2026-11-12 전에는 APB 슬롯 15의 SIMCTL — design.md 5.4절).

MCU용 riscv-tests
- 환경 [sim/riscv-tests-env/mcu/](../../sim/riscv-tests-env/mcu/riscv_test.h): 시작할 때 `.data`를 IMEM → DMEM으로 복사(데이터 쪽 IMEM 읽기 포트 사용), 결과는 DMEM 끝의 `TOHOST` `FINISH` 워드에 보통의 `sw`로 써서 판정
- 링커 스크립트 [mcu/link.ld](../../sim/riscv-tests-env/mcu/link.ld): `INCLUDE memmap.ld` (주소 표에서 생성), 코드·상수·`.data` 초기값은 IMEM, `.data` 실행 주소는 DMEM
- 빌드 (WSL, 테스트나 메모리 맵이 바뀔 때만): `bash sim/riscv-tests-env/build_rv32ui.sh ~/riscv-tests mcu` → `sim/riscv-tests-hex/rv32ui_mcu/` (커밋)

실행 방법
- 이 PC (xsim)
```bash
python sim/ch14a_mcu/run_mcu_tests.py
```
- 학교 서버 (Xcelium) — 일괄
```bash
bash sim/ch14a_mcu/run_mcu_tests.sh
```
- 학교 서버 — 대화형 (테스트 하나를 SimVision으로)
```bash
bash sim/ch14a_mcu/run_mcu_tests.sh --gui lw
```

| 날짜 | 조건 | 결과 | 사이클 (40개 합) | 비고 |
|------|------|------|----------------:|------|
| 2026-11-12 | SIMCTL 대기 0 % | **40 / 40 PASS** | 13,854 | xsim. 3단계(13,067)보다 테스트당 약 20사이클 많음 = `.data` 복사 + 마지막 APB 쓰기 1사이클 |
| 2026-11-12 | SIMCTL 대기 50 % | **40 / 40 PASS** | 13,895 | 마지막 `FINISH` 쓰기에서 대기 41사이클 |
| 2026-11-12 | SIMCTL 대기 0 % · 50 % | **40 / 40 PASS** | | 학교 서버 Xcelium, 사용자 확인 (수치 미기록) |
| 2026-11-12 | **TOHOST** (슬롯 15 제거 후) | **40 / 40 PASS** | 13,854 | xsim. 결과 주소를 만드는 명령이 1개 늘고(`lui`+`addi`) APB 쓰기 1사이클이 줄어 합계는 같음 |
| 2026-11-12 | TOHOST | **40 / 40 PASS** | 13,854 | 학교 서버 Xcelium (사용자). 테스트별 사이클이 xsim과 모두 같음 |

오류 시험 (작은 어셈블리 프로그램, 기대대로 멈춤)
| 프로그램 | 결과 |
|----------|------|
| 빈 슬롯(0x4000_5000) 읽기 | `bus_err` (data_err), 멈추지 않고 바로 오류 |
| 주변장치(TIMER)에 `sb` | `bus_err` (data_err) |
| IMEM(0x100)에 `sw` | `bus_err` (data_err) |
| IMEM 밖(0x2000_0000)으로 점프 | `bus_err` (fetch_err) |
| GPIO 쓰고 읽기 → SIMCTL `PUTC`로 "OK" 출력 → `FINISH` 1 | PASS (22사이클) |

TOHOST 감시기 시험 (2026-11-12, 슬롯 15 제거 후)
| 프로그램 | 결과 |
|----------|------|
| `FINISH`에 3 (`sw`) | FAIL test 1 (result = 3) |
| `FINISH`에 `sb` | FAIL (partial store to TOHOST FINISH) |
| 슬롯 15(0x4000_F000) 읽기 | `bus_err` (data_err) — 이제 빈 슬롯 |
| `PUTC`에 `sb` 'O', `sw` 'K', `sh` '\n' → `FINISH` 1 | "OK" 출력, PASS (10사이클) |
| `FINISH` 안 쓰고 다른 워드(+0x8)에만 씀 | timeout FAIL |

회귀: 3단계 rv32ui 40/40, 코어 대기 30 % 40/40, bus_tb PASS (MCU 파일을 추가한 뒤 다시 확인). 슬롯 15 제거 후에도 코어 대기 30 % 40/40, bus_tb PASS

## 8. C 펌웨어 — `fw/hello` + UART 해독 테스트벤치
구성: [fw_tb.v](../../sim/ch14a_mcu/fw_tb.v) = `mcu_top` + TOHOST 감시기 + **UART 해독기**. 해독기는 시작 비트마다 UART의 `BAUDDIV` 레지스터 값을 읽어 비트 길이를 정하고, 각 비트의 가운데에서 샘플링한다. 해독한 글자는 `UART| ...` 줄로 출력하고, 끝나면 기대 파일(`fw/hex/<프로그램>.exp`)과 한 글자씩 비교한다.

PASS 조건: `main`이 0을 반환(`fw_exit` → TOHOST `FINISH = 1`) **그리고** UART 출력 = 기대 파일 (CR 무시 → Windows CRLF 체크아웃도 동작). `trap`, `bus_err`, 정지 비트 오류, 시간 초과는 FAIL.

`fw/hello`가 확인하는 것
| 항목 | 방법 |
|------|------|
| `printf` → UART | `%d %u %i %x %X %p %c %s %%`, 폭·`0`·`-` 플래그 (10진 변환은 libgcc 나눗셈) |
| `.rodata`가 IMEM에 있음 | 문자열을 `lbu`로 IMEM에서 읽음 (데이터 쪽 IMEM 포트) |
| crt0 | `.data` 초기값 1234 (IMEM → DMEM 복사), `.bss` 0 |
| GPIO | 테스트벤치가 `gpio_in = {gpio_out[7:0], 8'hC3}`로 되돌림 → `0x5A` 출력 후 `0x5AC3` 읽기 |
| TIMER | `delay_cycles(1000)`이 1000~1099클럭 |

빌드 (WSL `rv32i`, 펌웨어가 바뀔 때만)
```bash
make -C fw/hello
```
→ `fw/hex/hello.hex`·`hello.exp` (커밋 — 학교 서버에는 RISC-V gcc가 없음). 보드용은 `make -C fw/hello TARGET=fpga` (커밋 안 함).

실행 방법
- 이 PC (xsim)
```bash
python sim/ch14a_mcu/run_fw_tests.py
```
- 학교 서버 (Xcelium) — 일괄
```bash
bash sim/ch14a_mcu/run_fw_tests.sh
```
- 학교 서버 — 대화형 (SimVision)
```bash
bash sim/ch14a_mcu/run_fw_tests.sh --gui hello
```

| 날짜 | 조건 | 결과 | 사이클 | 비고 |
|------|------|------|-------:|------|
| 2026-11-12 | BAUDDIV 9 (비트 10클럭), SIMCTL 대기 0 % | **PASS** | 24,365 | xsim, 191글자. 코드 3,004바이트 |
| 2026-11-12 | 같은 hex, SIMCTL 대기 50 % | **PASS** | 24,365 | |
| 2026-11-12 | BAUDDIV 3 / 40으로 다시 빌드 | **PASS** / **PASS** | 14,477 / 81,177 | 해독기가 비트 길이를 따라감 |
| 2026-11-12 | BAUDDIV 9 | **PASS** | | 학교 서버 Xcelium, 사용자 확인 (수치 미기록) |
| 2026-11-12 | BAUDDIV 9, **TOHOST** | **PASS** | 24,364 | xsim, 191글자 (슬롯 15 제거 후 다시 빌드) |
| 2026-11-12 | TOHOST | **PASS** | 24,364 | 학교 서버 Xcelium (사용자), 191글자. xsim과 같음 |

테스트벤치 자체 시험 (기대 파일을 바꿔서)
| 바꾼 기대 파일 | 결과 |
|----------------|------|
| 한 글자 다름 (`beef` → `beeF`) | FAIL, 55번째 글자 |
| 마지막 줄바꿈 빠짐 | FAIL, 출력이 1글자 많음 |
| 줄 하나 더 기대 | FAIL, 191번째에서 출력 끝 |
| 줄바꿈을 CRLF로 | PASS (CR 무시) |
