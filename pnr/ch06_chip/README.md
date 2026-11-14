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
| 2 | `floorPlan` (다이 3700 µm, 코어 여백 380 µm), 패드 배치, IO 채움 셀 | 패드 링이 끊김 없이 이어졌는지 |
| 3 | 전원망: 전역 연결, 코어 링, 전원 패드 연결, 셀 레일, 세로·가로 스트라이프, DRC·연결 검사 | `report/03_power.*` |
| 4 | `place_design`, `place_opt_design`, 혼잡도, `timeDesign -preCTS` | 셀이 코어 가운데 몰려 있음(면적이 작음) |
| 5 | CTS (`ccopt_design`, 목표 스큐 0.05 ns), 전파 클럭, `optDesign -postCTS` (+hold) | `report/05_*`, 클럭 트리 표시 |
| 6 | 배선 `routeDesign`, OCV, `optDesign -postRoute` (drv, setup, hold) | `report/timing/postRoute*` |
| 7 | 채움 셀, DRC, 연결 검사, RC 추출, 최종 타이밍·면적·전력 | `report/07_*`, Violation Browser |
| 8 | 넷리스트(게이트 시뮬·LEC용, 전원 패드 제외), SDF(slow·fast), SDC, DEF, GDS | `out/` |

## 확인할 점 (서버에서 처음 실행할 때)
- 처음 쓰는 스크립트라 Innovus 명령 옵션이 버전에 따라 다를 수 있다. 오류가 나면 그 STEP만 `-i --gui`로 다시 실행하며 고친다
- IO 파일의 변별 순서 방향(위·아래 변은 왼쪽→오른쪽, 좌·우 변은 아래→위로 예상)을 STEP 2 뒤 GUI로 확인
- 전원 패드의 핀 이름이 `VDD`/`VSS`인지(`globalNetConnect`), IO 링 전원(`VDDIOR` 등) 연결이 필요한지 STEP 3 연결 검사로 확인

## 결과
| 날짜 | 목표 주기 | setup WNS | hold WNS | DRC | 연결 | 셀 면적 | 비고 |
|------|----------:|----------:|---------:|:---:|:---:|------:|------|
| | 12 ns | (미실행) | | | | | |
