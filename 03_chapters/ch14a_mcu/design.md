# 4단계 MCU 설계 (교재 14장 일부)

> 3단계 단일 사이클 코어(`rv32i_core`)에 메모리와 APB3 주변장치(GPIO·Timer·UART)를 붙여, C 펌웨어가 도는 MCU를 만든다.
> 결정 사항(2026-11-12): 주변장치 버스 **APB3**, 명령어·데이터 메모리 **각 16 KB**(단일 사이클 유지), **메모리는 MCU 모듈 바깥**(같은 칩, 계층만 분리 — 1절).
> 9절의 결정 A~E는 2026-11-12에 모두 추천안으로 확정했다. 같은 날 검토에서 나온 개선 3가지(UART 상태 비트 뜻, 가져오기 주소 검사, 주소 한 곳 관리)도 반영했다.

## 1. 블록도와 MCU 경계
**메모리는 MCU 모듈 바깥에 둔다** (2026-11-12 결정). MCU(`rv32i_mcu`)는 코어·버스·주변장치만 갖고 메모리 포트를 밖으로 낸다. 시뮬레이션·FPGA용 최상위(`mcu_top`)가 메모리를 붙인다.
- ASIC 합성은 `rv32i_mcu`만 한다 → gpdk045에 SRAM 매크로가 없어도 메모리를 플립플롭으로 만들 필요가 없다. 실제 칩이라면 그 자리에 SRAM 매크로가 들어간다
- 메모리 접근 시간은 3단계 코어처럼 SDC의 입출력 지연으로 가정한다
- 칩 밖(별도 메모리 칩)에 두는 방식은 대기 사이클·핀이 많이 필요해 11~12장(캐시)에서 다룬다

```
mcu_top  (simulation / FPGA top)
|
+-- rv32i_mcu  (ASIC synthesis target, no memory inside)
|   |
|   +-- rv32i_core (+ stall) --- imem_addr / imem_rdata (fetch) ------------------------> IMEM read port 1
|   |        |
|   |        +-- dmem_* (data port) --> bus_mux (address decoder)
|   |        ^                             |-- irom_addr / irom_rdata (read only) ------> IMEM read port 2
|   |        |                             |-- ram_addr / ram_wstrb / ram_wdata / ram_rdata -> DMEM
|   |        +------ dmem_ready -----------|-- apb_bridge --APB3--+-- apb_gpio  --> gpio_in / gpio_out
|   |                                                             +-- apb_timer --> (irq, used in ch6)
|   |                                                             +-- apb_uart  --> uart_tx / uart_rx
|   |
|   +-- memory ports: imem_* , irom_* , ram_*   (cross the rv32i_mcu boundary)
|
+-- imem  16 KB, 2 asynchronous read ports   (sim: Verilog model, FPGA: distributed RAM)
+-- dmem  16 KB, async read / sync byte write
```
- 명령어 가져오기는 `imem_*` 포트로 한 사이클 안에 끝난다 (IMEM 읽기 포트 1)
- 데이터 포트(`dmem_*`)는 주소 디코더가 **IMEM 읽기(`irom_*`, IMEM 읽기 포트 2) / DMEM(`ram_*`) / APB** 중 하나로 보낸다
- IMEM·DMEM 접근은 대기 없이 한 사이클, **APB 접근만 코어를 멈춘다(stall)**
- `rv32i_mcu`의 메모리 포트 3개: `imem_*`(가져오기), `irom_*`(데이터 쪽 IMEM 읽기, 읽기 전용), `ram_*`(DMEM 읽기·쓰기)
- **구현 (2026-11-12)**: [rv32i_mcu.v](../../rtl/ch14a_mcu/rv32i_mcu.v) (슬롯 0 GPIO, 1 TIMER, 2 UART, 15 외부 `apbx_*`, 나머지 빈 슬롯은 `PREADY = 1`·`PSLVERR = 1`, 출력 `trap`·`bus_err`·`timer_irq`), [mcu_top.v](../../rtl/ch14a_mcu/mcu_top.v) (+ `mcu_imem` 2포트, `mcu_dmem`). 3단계 메모리 모델과 이름이 겹치지 않게 `mcu_` 앞머리 → [test.md](test.md) 7절

## 2. 메모리 맵
| 주소 | 크기 | 대상 | 접근 | 비고 |
|------|-----:|------|------|------|
| `0x0000_0000` – `0x0000_3FFF` | 16 KB | IMEM | 가져오기 / 데이터 포트는 **읽기 전용** | 리셋 PC = `0x0000_0000`. 코드·상수(`.rodata`)·`.data` 초기값 |
| `0x1000_0000` – `0x1000_3FFF` | 16 KB | DMEM | 읽기·쓰기 (byte·half·word) | `.data`·`.bss`·힙·스택 (스택은 끝 주소부터 아래로) |
| `0x4000_0000` – `0x4000_0FFF` | 4 KB | GPIO | APB, **word 접근만** | |
| `0x4000_1000` – `0x4000_1FFF` | 4 KB | TIMER | APB, word | |
| `0x4000_2000` – `0x4000_2FFF` | 4 KB | UART | APB, word | |
| `0x4000_F000` – `0x4000_FFFF` | 4 KB | SIMCTL | APB, word | **시뮬레이션 전용** 종료 레지스터 (7절). FPGA·ASIC에서는 빈 자리 |
| 그 밖 | | (없음) | | 데이터: 읽으면 0, 쓰기는 무시 + `bus_err` / 가져오기: IMEM 밖이면 `bus_err` (2.2절) |

- 주소 디코드는 위쪽 비트만 본다: `addr[31:28]` = 0(IMEM) / 1(DMEM) / 4(APB), APB 안에서는 `addr[15:12]`로 주변장치 선택
- 영역마다 크기가 2의 거듭제곱이라 아래쪽 주소 비트를 그대로 메모리 주소로 쓴다
- (참고) RISC-V 표준 메모리 맵은 없다. SiFive 계열처럼 코드·RAM·주변장치를 큰 단위로 떼어 두는 관례를 따랐다

### 2.1 IMEM을 데이터 포트에서도 읽는 이유 (결정 A)
C 프로그램은 문자열 같은 상수(`.rodata`)와 초기값 있는 전역 변수(`.data`)를 갖는다.
- 하버드 구조에서 코드 메모리를 데이터로 읽을 수 없으면 `printf("hello")`의 문자열을 읽을 방법이 없다
- 그래서 `rv32i_mcu`가 IMEM 읽기 전용 포트(`irom_*`)를 하나 더 내고, `mcu_top`의 IMEM은 읽기 포트 2개를 갖는다. 데이터 포트에서 `lw`·`lb`로 읽는다
- 부팅 코드(crt0)는 IMEM에 있는 `.data` 초기값을 DMEM으로 복사하고 `.bss`를 0으로 채운 뒤 `main`을 부른다 (일반 MCU와 같은 방식)
- 비용: IMEM 읽기 포트 하나 추가 (FPGA 분산 RAM은 읽기 포트마다 LUT가 늘어남 — 16 KB에 LUT 약 2,000개 추가)

### 2.2 없는 주소 접근과 `bus_err` (결정 E)
- 데이터 포트: 디코더가 어느 영역에도 맞지 않으면 읽기 값 0, 쓰기 무시, `bus_err = 1` (그 사이클). APB의 `PSLVERR`도 `bus_err`로 모은다
- 명령어 가져오기: `imem_addr`가 IMEM 영역(`0x0000_0000`~`0x0000_3FFF`) 밖이면 `bus_err = 1` (아래 비트만 보고 다른 명령어를 읽어 오는 일을 표시)
- 4단계에서는 `bus_err`를 MCU 출력으로 내고 테스트벤치가 FAIL로 처리한다. 6장에서 RISC-V 예외로 연결한다: 가져오기 → instruction access fault(`mcause` 1), load → load access fault(5), store → store access fault(7)

### 2.3 주소는 한 곳에서 관리
주소는 RTL·펌웨어·링커 스크립트·테스트벤치가 모두 쓴다. 한 곳만 고치고 나머지가 어긋나는 일을 막기 위해 **주소 표 하나**(`fw/common/memmap.txt` 같은 단순 표)에서 아래 파일의 주소 부분을 스크립트(`tools/gen_memmap.py`)로 만들어 낸다.
| 만들어지는 파일 | 내용 |
|----------------|------|
| `rtl/ch14a_mcu/mcu_memmap.vh` | 영역 시작 주소·크기, APB 슬롯 번호 (`` `define``) |
| `fw/common/memmap.h` | 같은 주소의 C `#define` |
| `fw/common/memmap.ld` | 링커 스크립트의 `MEMORY { IMEM ..., DMEM ... }` |
- 레지스터 오프셋(주변장치 안)은 주변장치 RTL과 `mcu.h`에 두고, 주소 표에는 영역 주소만 둔다
- 만들어진 파일도 커밋한다 (툴체인 없는 학교 서버에서 그대로 쓰도록). 스크립트를 다시 돌려 차이가 없는지로 어긋남을 점검한다
- **구현 (2026-11-12)**: [fw/common/memmap.txt](../../fw/common/memmap.txt) (`이름 시작주소 크기 종류 [옵션]`), [tools/gen_memmap.py](../../tools/gen_memmap.py) (`--check` = 생성 파일이 표와 맞는지만 확인). Verilog는 `` `MM_<이름>_BASE/_SIZE/_AW/_HIT(a)/_SLOT``, C는 `<이름>_BASE/_SIZE`(어셈블리에서도 쓰도록 `u` 접미사 없음) → [test.md](test.md) 2절

## 3. 코어 변경: 대기(stall)
APB는 한 번 접근에 최소 2사이클이 걸린다. 단일 사이클 코어는 매 사이클 명령어를 하나씩 끝내므로, **응답이 올 때까지 같은 명령어를 붙잡아 두는 입력**을 추가한다.

| 포트 (코어 기준) | 방향 | 뜻 |
|------------------|:----:|----|
| `dmem_ready` | 입력 | 1 = 이번 사이클에 데이터 접근이 끝남. IMEM·DMEM은 항상 1, APB는 ACCESS 단계에서 `PREADY`일 때 1 |

`dmem_ready = 0`인 사이클에 코어가 하는 일:
- **PC를 바꾸지 않는다** (`pc <= pc_next` 대신 `pc <= pc`) → 다음 사이클에도 같은 명령어
- **레지스터 파일에 쓰지 않는다** (`reg_we`를 막음) → load 값은 `dmem_ready = 1`인 마지막 사이클에 한 번만 쓴다
- 데이터 메모리 쓰기는 APB 쪽에서만 일어나므로 DMEM 쓰기와 겹치지 않는다
- 메모리 접근이 없는 명령어는 `dmem_ready`를 보지 않는다 (디코더가 `dmem_re`·`dmem_we`가 없으면 1을 낸다)

APB 읽기 타이밍 예 (`lw x5, 0(x10)`, x10 = UART 주소):
```
사이클        1 (SETUP)        2 (ACCESS, PREADY=1)    3
PC            lw               lw (그대로)             다음 명령어
PSEL/PENABLE  1 / 0            1 / 1                   0 / 0
dmem_ready    0                1                       -
x5 쓰기       안 함            클럭 에지에서 PRDATA     -
```
- 결과: APB `lw`·`sw`는 최소 **2사이클**, 주변장치가 `PREADY = 0`으로 늦추면 그만큼 더 길어진다 (CPI가 1보다 커지는 첫 경우)
- 3단계 코어는 `rtl/ch05_single_cycle`에 그대로 두고, `rtl/ch14a_mcu/`에 복사해 stall을 넣는다 (폴더 규칙)
- **구현 (2026-11-12)**: `mem_wait = (dmem_re | (|dmem_wstrb)) & ~dmem_ready`, `mem_wait`이면 PC 유지·`reg_we` 막음. 요청이 없으면 `dmem_ready`를 보지 않는다. 대기가 끝나는 에지에서만 쓰기가 일어나야 하므로 슬레이브는 `dmem_ready = 1`인 에지에서 쓴다 → 결과는 [test.md](test.md) 1절
- stall이 없는 기존 동작(= `dmem_ready`를 1로 묶음)이 그대로인지 rv32ui로 다시 확인한다

## 4. APB3 브리지 (`apb_bridge`)
- 코어 데이터 포트 → APB3 마스터 신호: `PADDR`, `PSEL`(주변장치별), `PENABLE`, `PWRITE`, `PWDATA`, `PRDATA`, `PREADY`, `PSLVERR`
- 상태: `IDLE` → (APB 주소 접근) `SETUP` → `ACCESS` → (`PREADY`) `IDLE`
  - SETUP 사이클: `PSEL = 1`, `PENABLE = 0`
  - ACCESS 사이클: `PENABLE = 1`, `PREADY`가 1이면 끝 → `dmem_ready = 1`
- `PADDR`·`PWRITE`·`PWDATA`는 코어가 같은 명령어를 붙잡고 있는 동안 그대로이므로 별도 레지스터 없이 코어 출력을 그대로 쓴다 (단일 사이클 코어라 가능. 파이프라인 장에서는 래치 필요)
- APB3에는 바이트 쓰기 신호(`PSTRB`, APB4)가 없다 → **주변장치는 word(`lw`·`sw`) 접근만** 지원한다. `sb`·`sh`로 주변장치에 쓰면 정의하지 않은 동작 (펌웨어는 `volatile uint32_t *`로 접근)
- `PSLVERR`는 `bus_err`(data_err)로 모아 MCU 출력으로 내고, 6장 예외에서 버스 오류 트랩으로 연결한다
- **구현 (2026-11-12)**: `bus_mux.v`(디코더, 응답 MUX, `dmem_ready`, `data_err`·`fetch_err`), `apb_bridge.v`(상태 IDLE·ACCESS 두 개, SETUP = IDLE에서 요청이 보인 사이클, 슬롯별 `PSEL`과 응답 선택). 주변장치에 sb·sh 쓰기는 APB 전송 없이 바로 `data_err`. 빈 슬롯은 MCU 최상위가 `PREADY = 1`·`PSLVERR = 1`로 묶는다 → [test.md](test.md) 3절

## 5. 주변장치 레지스터 맵 (초안)
모든 레지스터는 32비트, 오프셋은 각 주변장치 기준 주소에서의 거리. R = 읽기, W = 쓰기, W1C = 1을 쓰면 0이 됨.

### 5.1 GPIO (`0x4000_0000`)
| 오프셋 | 이름 | 접근 | 내용 |
|-------:|------|:----:|------|
| `0x00` | `DATA_OUT` | R/W | 출력 값 (비트마다 핀 하나) |
| `0x04` | `DATA_IN` | R | 입력 핀 값 (2단 플립플롭으로 동기화한 값) |
| `0x08` | `DIR` | R/W | 1 = 출력, 0 = 입력 (리셋 0 = 모두 입력) |
- 핀 수는 파라미터 `GPIO_W` (기본 16, 보드 자료를 받으면 LED·스위치 수에 맞춤 — 결정 C). 기능을 늘릴 때는 빈 오프셋(`0x0C`~)에 레지스터를 추가하고 기존 위치는 바꾸지 않는다
- **구현 (2026-11-12)**: [apb_gpio.v](../../rtl/ch14a_mcu/apb_gpio.v) — 대기 없음(`PREADY = 1`), 없는 오프셋·DATA_IN 쓰기는 `PSLVERR`, 핀 쪽은 `gpio_out`·`gpio_oe`·`gpio_in` (3상태 버퍼는 칩·FPGA 최상위에서) → [test.md](test.md) 4절

### 5.2 TIMER (`0x4000_1000`)
| 오프셋 | 이름 | 접근 | 내용 |
|-------:|------|:----:|------|
| `0x00` | `CTRL` | R/W | bit0 `EN`(카운터 동작), bit1 `AUTO`(비교 일치 시 0으로 되돌림), bit2 `IE`(인터럽트 출력 허용) |
| `0x04` | `COUNT` | R/W | 32비트 카운터, 매 클럭 +1 (`EN = 1`일 때) |
| `0x08` | `CMP` | R/W | 비교 값 |
| `0x0C` | `STATUS` | R/W1C | bit0 `MATCH`: `COUNT == CMP`가 된 적 있음 |
- `irq = IE & MATCH` 출력은 만들어 두고, 실제 인터럽트 연결은 6장(트랩)에서 한다
- 지금은 펌웨어가 `STATUS`를 읽어 시간을 잰다 (지연 함수, 주기 동작)
- 동작 규칙 (매 상승 에지, `EN = 1`일 때): 일치 = `COUNT == CMP` → `MATCH` 1, `COUNT`는 일치 & `AUTO`면 0, 아니면 +1. 같은 사이클에 APB가 `COUNT`에 쓰면 쓰기가 우선, 새 일치가 `MATCH` 지우기보다 우선. `CMP = N`, `AUTO`면 주기 N+1 클럭
- **구현 (2026-11-12)**: [apb_timer.v](../../rtl/ch14a_mcu/apb_timer.v) → [test.md](test.md) 5절

### 5.3 UART (`0x4000_2000`) — 교재 14.3 참고, 8N1
| 오프셋 | 이름 | 접근 | 내용 |
|-------:|------|:----:|------|
| `0x00` | `TXDATA` | W | 아래 8비트를 보낸다 (`TX_FULL = 1`이면 무시) |
| `0x04` | `RXDATA` | R | 마지막으로 받은 8비트. 읽으면 `RX_VALID`가 0이 됨 |
| `0x08` | `STATUS` | R | bit0 `TX_FULL`(새 글자를 받을 수 없음), bit1 `RX_VALID`(읽을 데이터 있음), bit2 `RX_OVERRUN`(읽지 않은 데이터 위에 새로 받음, `STATUS` 읽으면 0), bit3 `TX_IDLE`(보낼 것이 없고 선로가 쉬는 중), bit4 `RX_FRAME`(정지 비트 오류로 버린 바이트 있음, `STATUS` 읽으면 0) |
| `0x0C` | `BAUDDIV` | R/W | 비트 하나의 클럭 수 − 1. 예: 50 MHz / 115200 → 433 |
- FIFO 없이 송신·수신 버퍼 각 1바이트로 시작 (결정 D). FIFO는 6장 인터럽트 수신 때 추가
- **상태 비트는 FIFO를 넣어도 뜻이 같도록 정의**했다: 1바이트일 때 `TX_FULL` = 보내는 중, FIFO일 때 = FIFO 가득 참. 펌웨어 `putc`는 어느 쪽이든 `TX_FULL`이 0일 때까지 기다렸다 쓴다 → FIFO를 넣어도 펌웨어가 바뀌지 않는다
- 수신은 비트 중앙에서 샘플링 (시작 비트 감지 후 `BAUDDIV/2` 기다림)
- **구현 (2026-11-12)**: [apb_uart.v](../../rtl/ch14a_mcu/apb_uart.v)
  - 송신: 1바이트 보관 레지스터 + 시프트 레지스터 → 한 바이트를 보내는 동안 다음 바이트를 넣어 둘 수 있다. `TX_FULL` = 보관 레지스터가 차 있음
  - 수신: 2단 동기화 → 시작 비트를 반 비트 뒤에 다시 확인(아니면 글리치로 무시) → 데이터 비트를 각 중앙에서 샘플 → 정지 비트가 0이면 바이트를 버리고 `RX_FRAME`
  - 추가한 상태 비트: bit4 `RX_FRAME`(STATUS 읽으면 지워짐). 오버런이면 새 바이트가 이전 바이트를 대신한다
  - 오류(`PSLVERR`): 없는 오프셋, RXDATA·STATUS 쓰기, TXDATA 읽기. `BAUDDIV` 최솟값 3, 리셋 값 433 (50 MHz, 115200)
  - → [test.md](test.md) 6절

### 5.4 SIMCTL (`0x4000_F000`, 시뮬레이션 전용)
| 오프셋 | 이름 | 접근 | 내용 |
|-------:|------|:----:|------|
| `0x00` | `FINISH` | W | 1 = PASS로 종료, `(n << 1) \| 1` = 테스트 n 실패로 종료 (riscv-tests `tohost`와 같은 규칙) |
| `0x04` | `PUTC` | W | 아래 8비트를 시뮬레이터 화면에 바로 출력 (UART보다 빠른 디버그용) |
- MCU RTL에는 넣지 않고 **테스트벤치가 APB 슬레이브로 붙인다** → FPGA·ASIC에는 없음

## 6. 펌웨어 환경 (WSL `rv32i`)
| 파일 | 내용 |
|------|------|
| `crt0.S` | 스택 포인터 = DMEM 끝, `.data` 복사(IMEM → DMEM), `.bss` 0 채우기, `main` 호출, 끝나면 무한 루프 |
| `link.ld` | `.text`·`.rodata`·`.data` 초기값 → IMEM, `.data`·`.bss`·스택 → DMEM (메모리 영역은 생성 파일 `memmap.ld`를 `INCLUDE`) |
| `mcu.h` | 주변장치 레지스터 정의 (`memmap.h`의 주소 + 오프셋, 예: `#define UART_TXDATA (*(volatile uint32_t *)(UART_BASE + 0x00))`) |
| `uart.c`, `printf.c` | 문자 출력, 최소 `printf` (`%d %u %x %s %c`) — 표준 라이브러리 없이 (`-nostdlib`) |
| `Makefile` | `-march=rv32i -mabi=ilp32 -O2`, 결과 `imem.hex`(+ 필요하면 `dmem.hex`) |
- 곱셈·나눗셈 명령어가 없으므로(RV32I) `printf`의 10진 변환은 `libgcc`의 소프트웨어 나눗셈을 쓴다 (`-lgcc`)
- 펌웨어 위치: 루트 `fw/` (결정 B) — `fw/common/`(crt0·link.ld·mcu.h·uart·printf), `fw/<프로그램>/`(hello, gpio_blink …)
- **구현 (2026-11-12)**: [fw/README.md](../../fw/README.md)
  - 계획과 달라진 점: 결과는 `imem.hex` 하나 (`.data` 초기값은 IMEM 이미지 안, crt0가 복사 → `dmem.hex` 불필요). MCU용 riscv-tests 환경은 `sim/riscv-tests-env/mcu/`에 둠
  - 추가: `fwlib.h`(함수 선언), `timer.c`(`timer_now`·`delay_cycles`), `sys.c`(`fw_exit`), `libc_min.c`(gcc가 부를 수 있는 `memset`·`memcpy` 등), `common.mk`(공통 빌드 규칙)
  - 빌드 대상 두 가지: 시뮬레이션(`-DSIM`, UART 비트 10클럭, 끝나면 SIMCTL에 결과) / 보드(`TARGET=fpga`, 115200, 무한 루프)
  - 검증: UART 해독 테스트벤치 `sim/ch14a_mcu/fw_tb.v` → [test.md](test.md) 8절

## 7. 검증 계획
| 순서 | 대상 | 테스트벤치 | 확인 |
|-----:|------|-----------|------|
| 1 | 코어 + stall | `rv32i_core` + 메모리 + 무작위 지연 슬레이브 | rv32ui 40개를 **무작위 대기 사이클**을 넣고도 PASS, 사이클 수 증가 확인 |
| 2 | `apb_bridge` | 모형 APB 슬레이브(대기 0~3) | SETUP/ACCESS 순서, PREADY 대기, 읽기·쓰기 데이터 |
| 3 | GPIO | APB 모형 마스터 | 레지스터 읽기·쓰기, DIR, 입력 동기화 |
| 4 | TIMER | APB 모형 마스터 | 카운트, 비교 일치, AUTO, W1C |
| 5 | UART | 송신 → 수신 루프백 | 여러 BAUDDIV에서 송·수신 일치, BUSY·VALID·OVERRUN |
| 6 | MCU 전체 (riscv-tests) | `mcu_top` + SIMCTL | rv32ui 40/40 (새 메모리 맵에 맞춘 링커 스크립트로 다시 빌드) |
| 7 | MCU 전체 (C 펌웨어) | `mcu_top` + UART 디코더 | `printf("Hello")`가 UART 파형에서 문자열로 디코딩됨, GPIO 출력 변화 |
- 모든 테스트벤치는 자가 검사(PASS/FAIL·타임아웃), xsim(PC)·Xcelium(서버) 둘 다, 일괄·대화형(`--gui`) 실행
- 합성: `rv32i_mcu`(코어 + 디코더 + 브리지 + 주변장치, 메모리 없음)를 Genus로, 목표 8 ns 유지. 메모리 포트 3개에 입출력 지연을 준다

## 8. 파일 계획
| 위치 | 파일 |
|------|------|
| `rtl/ch14a_mcu/` | 합성 대상: `rv32i_core.v`(stall 추가 복사본)와 코어 하위 모듈, `bus_mux.v`(주소 디코더), `apb_bridge.v`, `apb_gpio.v`, `apb_timer.v`, `apb_uart.v`, `rv32i_mcu.v`(메모리 없는 MCU), `mcu_memmap.vh`(생성 파일, 2.3절) / 합성 제외: `imem.v`(읽기 포트 2), `dmem.v`, `mcu_top.v`(MCU + 메모리, 시뮬레이션·FPGA 최상위) |
| `sim/ch14a_mcu/` | 모듈별 테스트벤치, `apb_simctl.v`(테스트벤치 전용), `rv32i_mcu_tb.v`, `.f` 파일, probe Tcl |
| `syn/ch14a_mcu/` | Genus 스크립트(ch05 구조 그대로), `clean.tcl` |
| `fw/` | 펌웨어 (6절) |
| `tools/` | `gen_memmap.py` — 주소 표 하나에서 `mcu_memmap.vh`·`memmap.h`·`memmap.ld` 생성 (2.3절) |

## 9. 결정 (2026-11-12, 모두 추천안으로 확정)
| # | 내용 | 결정 | 고려한 다른 선택 |
|:-:|------|------|-----------|
| A | 상수·초기값을 어떻게 읽나 | **MCU의 IMEM 읽기 전용 포트(`irom_*`)** + IMEM 읽기 포트 2개 (2.1절) — 일반 MCU 방식, crt0 복사 | DMEM 초기 이미지에 `.rodata`·`.data`를 미리 넣음(하드웨어 단순, 하지만 실제 칩에서는 불가능한 방식) |
| B | 펌웨어 폴더 | **루트에 `fw/` 새로 만들기** (`fw/common/`, `fw/hello/` …) — 시뮬레이션과 FPGA가 같이 씀 | `sim/ch14a_mcu/fw/` 아래 (루트 폴더 규칙 유지, 대신 FPGA에서 sim 폴더를 참조) |
| C | GPIO 핀 수 | **16** (파라미터, 보드 자료를 받으면 맞춤) | 보드 자료를 먼저 받고 결정 |
| D | UART 버퍼 | **FIFO 없이 1바이트**로 시작, 필요하면 나중에 FIFO | 처음부터 송·수신 FIFO(예: 16바이트) |
| E | 없는 주소 접근 | **읽으면 0, 쓰기 무시 + `bus_err` 신호**(테스트벤치가 FAIL로 처리), 6장에서 트랩으로 (2.2절) | 지금부터 trap 출력에 포함해 바로 멈춤 |

검토에서 추가한 개선 (나중 변경을 줄이기 위해)
| # | 내용 | 효과 |
|:-:|------|------|
| 1 | UART 상태 비트를 `TX_FULL`·`RX_VALID` 뜻으로 정의 (5.3절) | FIFO를 넣어도 펌웨어 그대로 |
| 2 | 명령어 가져오기 주소도 범위 검사 → `bus_err` (2.2절) | 6장 instruction access fault를 다시 고칠 필요 없음 |
| 3 | 주소 표 하나에서 RTL·C·링커 주소 파일 생성 (2.3절) | 메모리 맵 변경 시 파일끼리 어긋나지 않음 |

나중 장에서 MCU에 생길 변화: 6장 `bus_err`·`irq`를 트랩에 연결, 7장 코어 교체(`dmem_ready` 유지), 8장 APB 브리지가 주소·데이터 래치, 11~12장 메모리 포트가 캐시 + 메모리 버스로 바뀜(메모리 맵·펌웨어는 유지), 13장 버스 중재, 14장 나머지 I/O는 APB 빈 슬롯에 추가
