# 단일 사이클 MCU 칩 설계 (IO 패드 + PnR) — 초안

> 6장 MCU(`rv32i_mcu`)를 IO 패드로 둘러싼 칩으로 만들어 Innovus PnR, PnR 후 타이밍·DRC, 게이트 수준 시뮬레이션, LEC까지 마친다 (2026-11-14 결정: 칩 PnR, 전체 검증).
> 상태: **결정 A~D 확정 (2026-11-14, 모두 추천안)**

## 1. 칩 구조
```
 +--------------------------- rv32i_chip (pads) ---------------------------+
 | corner |  PADDO/PADDI ... (north)                               | corner |
 |--------+--------------------------------------------------------+--------|
 |  pads  |                                                        |  pads  |
 | (west) |            core area: rv32i_mcu (std cells)            | (east) |
 |        |            + power ring / stripes                      |        |
 |--------+--------------------------------------------------------+--------|
 | corner |  PADDB / PADDI ... (south)                             | corner |
 +--------------------------------------------------------------------------+
   IMEM, DMEM: outside the chip, connected through the pads
```
- gpdk045에는 SRAM이 없어서 **메모리는 칩 밖**에 두고 패드로 연결한다 (4단계부터의 구조 그대로)
- 패드: giolib045 v3.5 (`giolib045_modify.lef` — 예전 프로젝트와 같음, 원본과 `CLASS PAD` → `CLASS PAD AREAIO` 두 곳만 다름)
  - 신호 패드 60 × 240 µm, 모서리 240 × 240 µm, 채움 `padIORINGFEED1/3/5/10/60`
  - 입력 `PADDI (PAD → Y)`, 출력 `PADDO (A → PAD)`, 양방향 `PADDB (A, OEN, PAD, Y)`

## 2. 패드로 낼 신호 (추천안 — 결정 A)
`rv32i_mcu`의 포트는 약 317비트다. 그대로 패드로 내면 칩 한 변이 약 5.3 mm가 된다. 실제로 쓰는 비트만 낸다.

| 신호 | `rv32i_mcu` 포트 | 칩 핀 | 패드 | 이유 |
|------|------------------|------:|------|------|
| 명령어 주소 | `imem_addr[31:0]` | 12 | PADDO | IMEM 16 KB는 워드 주소 `[13:2]`만 쓴다 (`mcu_imem`과 같음) |
| 명령어 | `imem_rdata[31:0]` | 32 | PADDI | |
| 데이터 주소 | `irom_addr`, `ram_addr` (둘 다 같은 버스) | 12 | PADDO | `[13:2]`만, 두 메모리가 같이 씀 |
| IMEM 데이터 읽기 | `irom_rdata` | 32 | PADDI | |
| DMEM 읽기 | `ram_rdata` | 32 | PADDI | |
| DMEM 쓰기 데이터 | `ram_wdata` | 32 | PADDO | |
| DMEM 바이트 쓰기 | `ram_wstrb` | 4 | PADDO | |
| GPIO | `gpio_in/out/oe` (각 16) | 16 | PADDB | 양방향 패드 하나로 (`A = out`, `OEN = ~oe`, `Y = in`) |
| UART | `uart_rx`, `uart_tx` | 2 | PADDI, PADDO | |
| 클럭·리셋·외부 인터럽트 | `clk`, `rst_n`, `ext_irq` | 3 | PADDI | |
| 상태 출력 | `trap`, `irq_taken`, `bus_err`, `timer_irq` | 4 | PADDO | 보드·측정에서 트랩을 볼 수 있게 |
| 관찰 PC | `dbg_pc` | 0 | — | 뺌. 시뮬레이션은 계층 경로로 본다 |
| **합계** | | **181** | | |

- 주소 상위 비트(`[31:14]`, `[1:0]`)는 칩 안에서 주소 디코더가 계속 쓰므로 논리는 그대로이고, 패드로만 나가지 않는다
- 바깥 메모리는 칩 핀의 12비트 워드 주소를 그대로 쓰면 된다 (시뮬레이션 모델 `mcu_imem`·`mcu_dmem`과 같은 방식)

## 3. 전원 패드와 칩 크기 (추천안 — 결정 B)
- 전원: 변마다 코어 `PADVDD`·`PADVSS` 1쌍, IO 링 `PADVDDIOR`·`PADVSSIOR` 1쌍 → 16개
- 신호 181 + 전원 16 = 197개 → 한 변 최대 52개 정도
- 한 변 = 모서리 240 × 2 + 52 × 60 = **약 3,600 µm** (3.6 mm × 3.6 mm). 남는 자리는 채움 셀
- 코어 영역 ≈ 3,120 µm 사방(패드 안쪽, 링 여유 제외 약 2.9 mm)인데 논리는 약 31,000 µm²(0.03 mm²) → **코어 영역의 0.4 % 정도만 셀**. 패드 수가 칩 크기를 정하는 "패드 제한" 칩이 된다

## 4. 패드 배치 (변별 묶음, 추천안 — 결정 C)
| 변 | 신호 | 개수 |
|----|------|-----:|
| 북 | 명령어 주소 12 + 명령어 32 | 44 |
| 동 | 데이터 주소 12 + DMEM 쓰기 데이터 32 + 쓰기 바이트 4 | 48 |
| 남 | DMEM 읽기 32 + GPIO 16 | 48 |
| 서 | IMEM 데이터 읽기 32 + 클럭·리셋·인터럽트 3 + UART 2 + 상태 4 | 41 |
- 각 변 가운데에 전원 패드 4개, 클럭 패드는 서쪽 가운데 (코어 중앙까지 거리가 짧게)
- 패드 순서는 `init.io`(Innovus IO 파일)로 정한다

## 5. 타이밍: 패드가 메모리 경로에 들어간다 (중요)
4단계부터 합성은 메모리가 **코어 바로 옆에 있다**고 보고 시간을 나눴다(`T_ADDR` 0.5, `T_MEM` 1.0, `T_WB` 1.2 ns). 칩 PnR에서는 메모리가 칩 밖이라, 한 사이클 안에 **패드를 네 번** 지난다 (명령어 주소 출력 → 명령어 입력 → 데이터 주소 출력 → 데이터 입력).
- 출력 패드는 칩 밖 부하(pF 단위)를 구동하므로 지연이 크다(보통 1 ns 안팎 이상, 정확한 값은 패드 `.lib`)
- 그래서 **8.5 ns를 그대로 맞추기 어렵다**. 칩 핀 기준 SDC로 합성해 보고 실제로 되는 주기를 찾는다 (결정 D)
- 실제 MCU라면 SRAM이 칩 안에 있어 이 문제가 없다. 이 결과는 "외부 메모리를 패드로 단 단일 사이클 칩"의 수치로 기록하고, 코어만의 결과(8.5 ns, 6장 합성)와 나란히 둔다

## 6. 흐름과 파일 (계획)
| 순서 | 내용 | 파일 |
|:---:|------|------|
| 1 | 칩 최상위 RTL: `rv32i_mcu` + 패드 인스턴스 | `rtl/ch06_exception/rv32i_chip.v` |
| 2 | 칩 시뮬레이션: 칩 핀에 메모리 모델을 달아 riscv-tests·hello (패드 Verilog 모델 사용, 서버) | `sim/ch06_exception/chip_tb.v` |
| 3 | 칩 합성: 표준 셀 + 패드 `.lib`, 칩 핀 기준 SDC | `syn/ch06_chip/` |
| 4 | PnR: 예전 `all.tcl` 흐름 (평면 배치, 패드, 전원망, 배치, CTS, 배선, 마무리), 단계마다 `saveDesign`, `--gui`·`-i` | `pnr/ch06_chip/` |
| 5 | PnR 후: 타이밍(setup slow, hold fast), DRC, 연결 검사, 넷리스트·SDF·GDS | |
| 6 | 게이트 수준 시뮬레이션: PnR 넷리스트 + SDF + 셀·패드 Verilog 모델 (서버) | |
| 7 | LEC: RTL ↔ 합성, 합성 ↔ PnR (교수님 서버) | `ec/ch06_chip/` |

- 셀·패드 라이브러리 경로는 `GPDK045_DIR` 환경 변수에서 (저장소에 경로를 쓰지 않음)
- hold 확인용 fast 코너: `fast_vdd1v0_basicCells.lib`, 패드는 `pads_FF_s1vg.lib`
- 게이트 시뮬레이션용 모델: 표준 셀 `gsclib045/verilog/slow_vdd1v0_basicCells.v`(SDF는 slow 코너와 맞춤, fast·multibitsDFF 판도 있음), 패드 `giolib045_v3.5/vlog/pads_SS_s1vg.v` (원본은 저장소에 올리지 않음)

## 7. 확인한 것 (2026-11-14, 서버 패드 모델)
- **`OEN`은 0일 때 출력** (모델: `bufif0 (PAD, A, OEN)`, `buf (Y, PAD)`). 그래서 GPIO는 `OEN = ~gpio_oe`. `Y`는 항상 패드 값을 돌려주므로 출력으로 쓸 때도 `gpio_in`에 자기 값이 보인다 (4단계 GPIO와 같은 동작)
- **출력 패드 지연이 크다**: `PADDB`의 `A → PAD` 지연이 SS 모델에서 1.4 ns(Verilog 모델의 specify 값, 실제 합성·PnR은 `.lib` 값과 부하로 계산). 한 사이클에 출력 패드 2번 + 입력 패드 2번을 지나므로 패드만으로 수 ns가 더해진다 → 5절 예상대로 8.5 ns는 어려움
- **전원·채움·모서리 패드는 `vlog/stub.v`에 포트 없는 모듈로 있다** (`PADVDD ( )`, `PADVSS ( )`, `PADVDDIOR ( )`, `PADVSSIOR ( )`, `IORINGCORNER ( )`, `IORINGFEED* ( )` 등). 그래서 전원 패드는 칩 최상위 Verilog에 인스턴스로 넣고(예전 프로젝트처럼 Innovus에서 `placeInstance`로 위치 지정), 시뮬레이션은 `stub.v`로 컴파일한다. 모서리·채움 셀은 Innovus에서 추가(`addIoFiller`)

## 8. 구현 (2026-11-14)
| 무엇 | 파일 | 확인 |
|------|------|------|
| 패드 표 (패드 순서·종류·연결의 원본) | [chip_pads.txt](../../rtl/ch06_exception/chip_pads.txt) → `python tools/gen_chip.py` | 표 검사: 이름 중복, 버스 폭, 코어 입력이 모두 연결됐는지 |
| 칩 최상위 (생성) | [rv32i_chip.v](../../rtl/ch06_exception/rv32i_chip.v) | 패드 197개 (북 48, 동 52, 남 52, 서 45) |
| Innovus IO 파일 (생성) | [pnr/ch06_chip/rv32i_chip.io](../../pnr/ch06_chip/rv32i_chip.io) | 같은 표에서 생성 → 이름이 넷리스트와 항상 일치 |
| 칩 시뮬레이션 | [chip_tb.v](../../sim/ch06_exception/chip_tb.v), `run_chip_tests.py`·`.sh` | 이 PC: 직접 쓴 단순 패드 모델 `pad_models.v`·`pad_power.v`. 서버: PDK 패드 모델 `pads_SS_s1vg.v` + `pad_power.v` |
| 칩 합성 | [syn/ch06_chip](../../syn/ch06_chip/README.md) | 기본 목표 12 ns, 칩 핀 기준 SDC |
| PnR | [pnr/ch06_chip](../../pnr/ch06_chip/README.md) | 예전 `all.tcl` 흐름, STEP 0~8, `--gui` |

칩 시뮬레이션 결과 → [test.md](test.md) 5절

## 9. 결정 (2026-11-14, 모두 추천안(**굵게**)으로 확정)
| # | 내용 | 선택지 | 추천과 이유 |
|:-:|------|--------|------|
| A | 패드로 낼 신호 | **2절 표 (181개)** / 전부(약 317) / 더 줄임(상태 출력 4개도 뺌 → 177) | 메모리가 실제로 쓰는 비트만, GPIO는 양방향 하나로. 상태 출력 4개는 측정·보드용으로 둠 |
| B | 전원 패드 | **변마다 코어 1쌍 + IO 1쌍 (16)** / 예전 프로젝트처럼 더 많이 (22) | 논리가 작아 전류가 적다. 예전 칩은 같은 크기에 22개 |
| C | 패드 배치 | **기능별로 변을 나눔 (4절)** / Innovus 자동 | 같은 버스가 한 변에 모여 칩 밖 배선과 코어 안 배선이 짧다 |
| D | 칩 목표 주기 | **칩 핀 기준 SDC로 합성해 보고 정함 (8.5 ns부터 늘려 감)** / 8.5 ns 고정(코어 기준 SDC를 그대로) | 패드 지연이 메모리 경로에 네 번 들어가 8.5 ns는 어려울 것. 실제 칩의 수치를 남긴다 |
