# fw — MCU 펌웨어 (4단계부터)

C 펌웨어와 그 빌드 환경. 시뮬레이션·FPGA·이후 장(6~13장)에서 같이 쓴다. 설계는 [03_chapters/ch14a_mcu/design.md](../03_chapters/ch14a_mcu/design.md) 6절.

| 위치 | 내용 |
|------|------|
| `common/memmap.txt` | **주소 표 (모든 주소의 원본)** — 고친 뒤 `python tools/gen_memmap.py` |
| `common/memmap.h`, `common/memmap.ld` | 주소 표에서 만든 파일 (직접 고치지 않음) |
| `common/crt0.S` | 시작 코드: `gp`·`sp`(DMEM 끝) 설정, `.data` 복사(IMEM → DMEM), `.bss` 0, `main` 호출 → `fw_exit` |
| `common/link.ld` | 코드·`.rodata`·`.data` 초기값 → IMEM, `.data`·`.bss`·스택 → DMEM (`INCLUDE memmap.ld`, 스택 1 KB 이상 남는지 링크 때 검사) |
| `common/mcu.h` | 주변장치 레지스터 (`GPIO_DATA_OUT`, `TIMER_COUNT`, `UART_STATUS` …) — 모두 워드 접근 |
| `common/fwlib.h` | 라이브러리 함수 선언: `uart_*`, `printf`, `timer_now`·`delay_cycles`, `fw_exit`, `memset` 등 |
| `common/uart.c`, `printf.c`, `timer.c`, `sys.c`, `libc_min.c` | 표준 라이브러리 없이(`-nostdlib`) 쓰는 최소 구현 |
| `common/common.mk` | 공통 빌드 규칙 (프로그램 `Makefile`이 `include`) |
| `hello/` | 첫 C 프로그램: `printf`, `.data`/`.bss`, GPIO, TIMER 확인. `expected.txt` = 기대 UART 출력 |
| `hex/` | 시뮬레이션용 결과 `<프로그램>.hex`·`.exp` (**커밋** — 학교 서버에는 RISC-V gcc가 없음) |

## 빌드 (WSL `rv32i`)
```bash
make -C fw/hello                 # 시뮬레이션용 -> fw/hex/hello.hex, hello.exp
make -C fw/hello TARGET=fpga     # 보드용 -> fw/hello/build/fpga/hello.hex (커밋 안 함)
make -C fw/hello clean
```
| | 시뮬레이션 (`TARGET=sim`, 기본) | 보드 (`TARGET=fpga`) |
|---|---|---|
| UART 비트 길이 | `BAUDDIV` 9 (10클럭, 빠른 시뮬레이션). `SIM_BAUDDIV=n`으로 변경 | 433 (50 MHz에서 115200) |
| `main`이 끝나면 | UART 송신을 마친 뒤 SIMCTL `FINISH`에 결과 (0 → PASS) | 무한 루프 |
- 옵션: `-march=rv32i -mabi=ilp32 -O2 -ffreestanding -fno-builtin`, 링크 `-nostdlib ... -lgcc` (곱셈·나눗셈은 libgcc 소프트웨어 함수)
- `-fno-tree-loop-distribute-patterns`: gcc가 `memset` 안의 루프를 다시 `memset` 호출로 바꿔 무한 재귀가 되는 것을 막음
- 주변장치 레지스터는 반드시 `uint32_t`로 읽고 쓴다 (APB 창에 바이트·하프워드 쓰기는 `bus_err`)

## 시뮬레이션
```bash
python sim/ch14a_mcu/run_fw_tests.py       # 이 PC (xsim)
bash sim/ch14a_mcu/run_fw_tests.sh         # 학교 서버 (Xcelium)
```
`fw/hex/`의 모든 프로그램을 돌려 UART 출력을 `.exp`와 비교한다 → [test.md 8절](../03_chapters/ch14a_mcu/test.md)

## 새 프로그램 추가
1. `fw/<이름>/Makefile`: `PROG := <이름>`, `SRCS := main.c`, `include ../common/common.mk`
2. `main.c` (`#include "fwlib.h"`, `main`의 반환값 0 = PASS), `expected.txt` (기대 UART 출력)
3. `make -C fw/<이름>` → `fw/hex/<이름>.hex`·`.exp`를 커밋

## 주소를 바꿀 때
1. `common/memmap.txt` 수정
2. 이 PC에서 `python tools/gen_memmap.py` → 아래 세 파일이 함께 바뀐다
   - `rtl/ch14a_mcu/mcu_memmap.vh` (주소 디코더용 Verilog `` `define``)
   - `fw/common/memmap.h` (C·어셈블리 `#define`)
   - `fw/common/memmap.ld` (링커 `MEMORY`)
3. 세 파일을 같이 커밋 (학교 서버에는 Python 실행이 필요 없음)
- 커밋 전에 `python tools/gen_memmap.py --check`로 생성 파일이 표와 맞는지 확인할 수 있다
- 스크립트가 표를 점검한다: 이름 중복, 크기(2의 거듭제곱), 정렬(시작 주소 = 크기의 배수), 영역 겹침, APB 창 밖 주변장치, APB 슬롯 중복
