# 6장 MCU 칩 PnR (Innovus, gpdk045)

[syn/ch06_chip](../../syn/ch06_chip/README.md)의 칩 넷리스트를 배치·배선한다. 흐름은 예전 프로젝트의 `all.tcl`과 같다. 설계: [03_chapters/ch06_exception/chip.md](../../03_chapters/ch06_exception/chip.md)

| 파일 | 역할 |
|------|------|
| [run_pnr.sh](run_pnr.sh) | 실행 스크립트: 일괄 / `--gui`(창에서 전체 자동 실행, 끝나도 열림) / `-i`(단계별, `--gui`와 함께 가능) |
| [innovus.tcl](innovus.tcl) | STEP 0~8, 단계마다 `saveDesign dbs/<NN_이름>` |
| [mmmc.tcl](mmmc.tcl) | 코너: setup = slow(표준 셀 slow_vdd1v0, 패드 SS), hold = fast(fast_vdd1v0, 패드 FF), QRC 하나 |
| [rv32i_chip.io](rv32i_chip.io) | 패드 순서 (생성 파일 — 원본은 `rtl/ch06_exception/chip_pads.txt`, `python tools/gen_chip.py`) |
| [../common/flatten_sdc.tcl](../common/flatten_sdc.tcl) | 프로젝트 SDC(변수 사용)를 숫자만 있는 SDC로 펼쳐 MMMC에 넘김 |
| [clean.tcl](clean.tcl) | `./clean.tcl` — 이 폴더의 `runs/` 정리 |

## 실행 (학교 서버)
먼저 같은 목표 주기로 칩을 합성한다 (넷리스트가 `syn/ch06_chip/runs/t<목표>ns/mapped/`에 있어야 함).
```bash
bash syn/ch06_chip/run_syn.sh 12
```
**GUI로 진행 과정 보기** (패드 링 → 전원망 → 배치 → 클럭 트리 → 배선이 차례로 그려짐)
```bash
bash pnr/ch06_chip/run_pnr.sh --gui 12
```
일괄 (창 없이, 끝나면 요약 출력)
```bash
bash pnr/ch06_chip/run_pnr.sh 12
```
- 단계별: `-i --gui` 후 프롬프트에서 `step 0`, `step 1`, … `step 8`
- 중간부터 다시: 프롬프트에서 `step 0`(경로·변수) → `restoreDesign dbs/04_place.dat rv32i_chip` → `step 5` …
- 다른 넷리스트: `env NETLIST=<파일> bash pnr/ch06_chip/run_pnr.sh 12` (csh)

| STEP | 내용 | 끝나고 볼 것 (GUI·프롬프트) |
|:---:|------|------|
| 0 | 경로·변수, SDC 펼치기 (`pnr.sdc`, 주기 = 목표) | |
| 1 | `init_design` (넷리스트, LEF 3개, MMMC, IO 파일), `checkDesign` | `report/checkDesign` |
| 2 | `floorPlan` (다이 3700 µm, 코어 1400 µm 사방을 가운데에, 목표 코어 여백 1150 µm, 환경 변수 `CORE_MARGIN`으로 바꿀 수 있음), 패드 배치, 코어 전원 패드(AREAIO)를 링의 빈 자리로 옮김 → 행(row) 다시 만들기, IO 채움 셀. 수정 IO LEF(AREAIO)에서는 floorPlan이 코어를 패드 깊이(240 µm)만큼 줄여 잡으므로 여백을 1150 − 240 = 910으로 요청한다 (2026-11-18 코어 1000 µm에서 확인) | 콘솔 `floorPlan core margin`, `core box after floorPlan`, `pad moved into the ring` 8줄, `core box` = 1150 ~ 2550, 패드 링이 끊김 없이 이어졌는지 |
| 3 | 전원망 (3-1 ~ 3-8): 전역 연결 → 안쪽 링(코어 둘레) → 셀 레일 → 코어 스트라이프 → 바깥 링(IO 링 40 µm 안쪽) → 전원 패드 → 바깥 링 → 두 링을 잇는 스트라이프 → 남는 스트라이프 끝 자르기(`editTrim`), 하위 단계마다 전원 끊김·DRC 검사 | `report/03_pgcheck.txt` (하위 단계별 한 줄: 끊김 종류별 개수, DRC 수, 전원선 종류별 개수), `report/03_<하위단계>.open.rpt`, 콘솔 `core box` / `inner ring box` / `outer ring box` |
| 4 | `place_design`, `place_opt_design`, 혼잡도, `timeDesign -preCTS` | 셀이 코어 가운데 몰려 있음(면적이 작음) |
| 5 | CTS (`ccopt_design`: 강한 클럭 셀, trunk Metal7-8, 목표 스큐 0.05 ns, IO 지연 자동 보정 끔), 전파 클럭, 가상 클럭 `vclk` 지연 = 측정한 평균 삽입 지연(뷰별), `optDesign -postCTS` (+hold) | `report/05_*`, 로그의 `vclk latency`, 클럭 트리 표시 |
| 6 | 배선 `routeDesign`, OCV, `optDesign -postRoute` (drv, setup, hold) | `report/timing/postRoute*` |
| 7 | 채움 셀, DRC, 연결 검사, 배치 검사(`checkPlace`), RC 추출, 최종 타이밍·면적·전력 | `report/07_*`, Violation Browser |
| 8 | 넷리스트(게이트 시뮬·LEC용, 평탄화, 전원 패드 제외), SDF(slow·fast), SDC, DEF, GDS | `out/` |

## 확인할 점 (서버에서 처음 실행할 때)
- 처음 쓰는 스크립트라 Innovus 명령 옵션이 버전에 따라 다를 수 있다. 오류가 나면 그 STEP만 `-i --gui`로 다시 실행하며 고친다
- IO 파일의 변별 순서 방향(위·아래 변은 왼쪽→오른쪽, 좌·우 변은 아래→위로 예상)을 STEP 2 뒤 GUI로 확인
- 전원 패드의 핀 이름이 `VDD`/`VSS`인지(`globalNetConnect`), IO 링 전원(`VDDIOR` 등) 연결이 필요한지 STEP 3 연결 검사로 확인

## 클럭 트리와 가상 클럭 (1차 실행 뒤 수정, 2026-11-16)
- 1차: CCOpt 기본값으로 서쪽 클럭 패드에서 코어 가운데까지 약 1.8 mm를 작은 버퍼 약 35단으로 이어 삽입 지연 4.1 ns(slow)·1.1 ns(fast). 자동 IO 지연 보정(`update_io_latency`)이 hold 검사 한쪽에만 들어가 **hold −1.134 ns, 2216 경로 위반**
- 수정 1: 클럭 셀 CLKBUFX8~20·CLKINVX8~20, trunk Metal7-8, `target_max_trans 0.2`, `update_io_latency false` → 삽입 지연 0.62~0.76 ns(slow)·0.22~0.29 ns(fast), postCTS hold 위반 1개(−0.000), reg2reg setup +4.312
- 그 결과 IMEM_ADDR 12비트가 setup −0.699: 주소는 클럭 지연만큼 늦게 나가는데 핀 제약의 기준(보드 클럭)은 그대로라서. 메모리 읽기는 주소가 나가고 데이터가 돌아오는 **한 사이클 왕복**이라, 받는 플립플롭도 같은 만큼 늦게 클럭을 받아 실제로는 상쇄된다
- 수정 2: 메모리 읽기 왕복 핀(IMEM_ADDR·IMEM_DATA·DADDR·RAM_RDATA·IROM_DATA)을 가상 클럭 `vclk` 기준으로 두고, CTS 뒤 `vclk` 지연을 측정한 평균 삽입 지연으로 맞춘다. 합성·CTS 전에는 0(이상적 클럭과 같음). slow·fast 값이 달라 MMMC 모드를 뷰마다 하나씩(`FUNC_S`, `FUNC_F`) 둔다. DMEM 쓰기·GPIO·UART·상태 출력은 보드 클럭 기준 `clk` 그대로
- 측정이 안 되면 `VCLK_LAT_SLOW`·`VCLK_LAT_FAST`(환경 변수 또는 프롬프트 `set`)로 `report/05_skew_groups.rpt`의 Avg ID를 직접 준다

## 결과
| 날짜 | 목표 주기 | setup WNS | hold WNS | DRC | 연결 | 셀 면적 | 비고 |
|------|----------:|----------:|---------:|:---:|:---:|------:|------|
| 2026-11-16 | 13 ns | −0.005 | **−1.134** | 확인 중 | 확인 중 | | 1차, 클럭 트리 문제 (위 절) |
| 2026-11-16 | 13 ns | −0.699 (postCTS, IMEM_ADDR) | −0.000 (postCTS) | | | | 클럭 수정 1 뒤, 가상 클럭 전 |
| 2026-11-17 | 13 ns | **0.000 (위반 0)**, reg2reg +5.016 | −0.000 (1경로) | 2 (Metal5 VDD 간격) | 568 (모두 VDD/VSS) | | 가상 클럭 적용. 전원망 수정 전, STEP 8 saveNetlist 오류 |
| 2026-11-18 | 13 ns | +0.021, reg2reg +5.614 | +0.020 | **0** | IO 링 항목만 (12/2/398) + 스트라이프 끝 76 → `editTrim`으로 0 | 28,063 µm² | 코어 1000 µm, 전원 패드를 링으로 옮김(B안), 두 링 전원망. max_tran 4 넷(입력 패드, 최대 −0.044) |
| 2026-11-18 | 13 ns | +0.014 | +0.020 | 499 | 신호 넷 끊김 19 | | 시험: 패드↔코어 넷 전체 Metal7-8 hard → 패드 차단 영역과 단락. 되돌림 |
| 2026-11-18 | 13 ns | **+0.047**, reg2reg +5.384 | **+0.020** | **0** | **IO 링 항목만** (12/2/398) | 밀도 1.44 % | 코어 1400 µm. DRV Real 0 (max_tran 0). 단, checkPlace TechSite 95 (이중 높이 셀, 아래 절) → 수정 후 재실행 |

### 입력 패드 넷의 max_tran과 코어 크기 (2026-11-18)
- 코어 1000 µm에서는 패드에서 코어까지 약 1.1 mm라 입력 패드 넷 몇 개(`irom_rdata`, `gpio_in` 일부)가 전이 시간 상한 0.28 ns를 최대 0.044 ns 넘었다. 구동 셀이 패드(크기 고정)이고 그 사이에 행이 없어 버퍼로 고칠 수 없다
- 위층(Metal7-8) 배선 시험: 4 넷만 다시 배선하면 0이 됐지만, 전체 패드 넷에 강제(hard)하면 패드 셀 차단 영역(Metal4-8)과 단락 499개 → 적용하지 않음
- 해결: 코어를 1400 µm로 키워 거리를 약 0.9 mm로 줄였다 → max_tran Real 0 (서버 확인)

### 이중 높이 셀과 배치 검사 (2026-11-18)
- 최종 실행의 GUI에서 코어 가운데에 흰 X 표시가 남았다. DRC·연결 리포트에는 없고 Violation Browser의 **CheckPlace / TechSite 95**였다
- `checkPlace`: IMPSP-365 "SITE `CoreSiteDouble` 셀이 있는데 그 사이트의 행이 없음". 최적화가 IO 넷에 넣은 버퍼(`FE_OFC*`) 95개가 이중 높이 셀이었다. 행은 `CoreSite`만 있어 위치가 규칙에 맞지 않는다
- 수정: STEP 1에서 사이트가 `CoreSiteDouble`인 셀을 모두 `setDontUse`(셀 이름을 적지 않고 라이브러리에서 찾음), CTS 셀 목록에서도 뺀다. STEP 7에 `checkPlace` → `report/07_checkplace.rpt`
- 1차 수정(2026-11-18)은 효과가 없었다: `dbGet -p head.libCells.site.name` 이 셀이 아니라 사이트 객체를 돌려줘 아무 셀도 막지 못함 (재실행 결과가 인스턴스 이름까지 같았음). 2026-11-19 셀마다 사이트를 읽는 반복문으로 고침
- 확인할 것: 콘솔 `double-height cells (dont_use)` 줄(BUFX2 포함, 개수 1 이상), `07_checkplace.rpt`의 TechSite 0 (미검증)

