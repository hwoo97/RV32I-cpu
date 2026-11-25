# UART IP 블록 PnR (실습 방식)

실습 Innovus `all.tcl`과 같은 형식에서 경로·수치만 바꾸고, 패드가 없는 **블록**에 맞게 일부 구역을 뺐다.

| 파일 | 내용 |
|------|------|
| `all.tcl` | InitDesign → PowerPlan → Placement → CTS → Route → Power → Chip Finish → Write Out |
| `uart_top.mmmc.view` | 실습 mmmc와 같음(BEST/WORST RC, FF/SS 라이브러리), 패드 라이브러리 없음, SDC = `uart_top_func.sdc` |
| `uart_top_func.sdc` | 목표 5 ns(200 MHz), 합성 SDC와 주기·입출력 지연만 다름 |
| `tempus.tcl` | 실습 Tempus 스크립트 형식: Practice 0 사인오프 STA, Practice 1 ECO(hold 수정 → `innovus.eco`), Practice 2 ECO 뒤 STA·SDF |
| `eco.tcl` | 실습 6_ECO.tcl 형식: `innovus.eco` 반영 → single 모드 최적화 → 타이밍·DRC·연결 → Filler → 출력(`_eco` 이름) |

## 실습 all.tcl과 다른 점
| 실습(칩) | UART IP(블록) |
|------|------|
| 패드 배치(`placeInstance pad*`), IO 필러, 바깥 링, 패드 전원 연결, 링 사이 스트라이프 | 없음 |
| `init_io_file` (패드 위치) | `editPin`으로 핀 배치: 왼쪽 APB 입력 49개, 오른쪽 출력·직렬·irq 37개 (Metal3, 0.8 µm 간격) |
| floorPlan 여백 1200 µm | 10 µm (코어 링만) |
| 링·스트라이프 폭 5, 간격 5, 100 µm마다 | 폭 2, 간격 1, 20 µm마다 (작은 블록) |
| 전력 분석 주기 8 ns | 5 ns |
| SDF 하나 | slow·fast 두 개 (게이트 수준 시뮬레이션) |
| — | 블록 LEF(`write_lef_abstract`), DEF 추가 |

## 실행 (학교 서버, 합성 뒤 이 폴더에서)
```
cd pnr/ip_uart
innovus
```
Innovus 프롬프트에서 `source all.tcl` (전체) 또는 구역별로 붙여 넣으며 GUI에서 확인. 중간 저장(`InitDesign`, `PowerPlan`, `PlaceOpt`, `PostCTSopt`, `RouteDesign`, `ChipFinish`)에서 `restoreDesign <이름>.dat uart_top`으로 다시 시작

## 사인오프 STA · ECO (실습 방식, Tempus)
1. `all.tcl`이 Route 뒤에 분석 모드를 `single`로 바꾸고 `RouteDesign_for_ECO`를 저장한다. 이미 PnR을 끝냈다면 Innovus에서 `restoreDesign RouteDesign.dat uart_top` → `setAnalysisMode -analysisType single` → `saveDesign -rc -def RouteDesign_for_ECO`.
2. `tempus` 실행 → `tempus.tcl` Practice 0 붙여 넣기: `report_analysis_coverage` 위반 0이면 실제 설계는 ECO가 필요 없음.
3. **ECO 시연** (실제 설계는 위반이 없음): Practice 1에서 이 Tempus 세션에만 hold uncertainty를 0.05 → 0.07 ns로 올려 위반 몇 개를 만들고, `add_repeater`로 고친 뒤 `write_eco`로 `innovus.eco`를 쓴다.
4. Innovus에서 `source eco.tcl`: ECO 반영(`*FE_ECO*` 셀) → 최적화 → 타이밍·DRC·연결 확인 → `ChipFinish_after_ECO`. 출력은 `_eco` 이름이라 실제 결과는 그대로.
5. Tempus Practice 2: ECO 뒤 설계 STA.
- 실행 결과 (2026-11-26, Practice 0): Tempus 분석 모드 `single` 확인. 배선 RC 적용 real net 1,544/1,544 = 100 %. `report_analysis_coverage` 위반 0(Setup 743·Hold 743 모두 Met, Recovery/Removal 167 Met·18 Untested, External delay 25 Met·11 Untested, Pulse width 910 Met·185 Untested, Data check 18 Untested). 최악 slack setup +0.100 ns, hold +0.001 ns(Innovus bcwc +0.008, OCV +0.001)
- 결론: 실제 설계는 ECO 불필요. Practice 1·2와 `eco.tcl`은 위반이 생겼을 때 쓰는 절차로 둠
- 미확인: Untested 항목이 모두 상수 때문인지(`report_analysis_coverage -verbose untested -exclude_untested const`), hold 최악 경로의 시작·끝점

## 확인할 것
| 단계 | 볼 것 |
|------|------|
| floorPlan·핀 | 블록 크기, 핀이 왼쪽·오른쪽에 겹치지 않고 놓였는지 |
| PowerPlan | verify_drc·verifyConnectivity 오류 0 |
| preCTS·postCTS·postRoute | `timeDesign` setup·hold WNS ≥ 0 |
| Chip Finish | verify_drc 0, verifyConnectivity 0, checkPlace 위반 0 |
| Write Out | `uart_top_pnr.v`, `uart_top_slow.sdf`, `uart_top_fast.sdf`, `uart_top.lef` |

## 결과 (2026-11-24 서버 실행)
| 항목 | 결과 |
|------|------|
| 블록 크기 | 110.2 × 107.35 µm (이용률 71.5 %) |
| postRoute setup (FUNC_SS_WORST, 5 ns) | WNS +0.100 ns (reg2reg +2.474, default +0.100), 위반 0 / 935 경로 |
| postRoute hold (FUNC_FF_BEST) | WNS +0.008 ns (reg2reg +0.008, default +0.040), 위반 0 |
| DRV (max_cap·max_tran·max_fanout) | 0 |
| verify_drc | 0 |
| verifyConnectivity | 0 오류, 0 경고 |
| checkPlace | 배치 3,356(고정 30), 미배치 0, 위반 없음, 필러 포함 밀도 100 % |

- setup 최악은 입력 → 출력 조합 경로(APB 읽기, default 그룹)로 합성 때와 같은 경로로 보이며, 플립플롭 사이 경로는 2.5 ns 여유가 있음. 최악 경로 상세는 미확인
- 핀: 왼쪽 49개·오른쪽 37개가 겹치지 않고 놓임 (레이아웃 화면으로 확인)
- 미확인: 출력 파일(`uart_top_pnr.v`, SDF 2개, `uart_top.lef`) 생성 여부

### 재실행 (2026-11-25, 리포트 추가된 all.tcl)
최종 결과는 첫 실행과 같습니다(setup +0.100, hold +0.008, 밀도 71.466 %). 추가한 리포트 결과는 아래와 같습니다.

| 시점 | setup WNS | hold WNS | 비고 |
|------|------:|------:|------|
| postCTS, hold 수정 전 → 후 | — | +0.009 → +0.009 | 위반 없음, 삽입 0 |
| NanoRoute 직후 (OCV, CPPR) | +0.107 | +0.001 | 위반 0, DRV 0 |
| postRoute, hold 수정 전 → 후 (bcwc) | +0.100 | +0.008 → +0.008 | 위반 없음, 삽입 0 |

| 단계 (`reports/cell_count.txt`) | 인스턴스 | BUF | CLKBUF | DLY |
|------|------:|------:|------:|------:|
| place_opt 뒤 | 1,422 | 56 | 3 | 0 |
| CTS 뒤 | 1,449 | 60 | 31 | 0 |
| postCTS hold 수정 전·후, Route 뒤, postRoute hold 수정 전·후 | 1,448 | 56 | 31 | 0 |

- 버퍼가 늘어난 곳은 CTS(클럭 버퍼 +28)뿐이고, 두 번의 hold 수정은 위반이 없어 아무것도 넣지 않았습니다.
- NanoRoute 직후 `timeDesign -postRoute`는 분석 모드가 OCV가 아니면 `IMPOPT-7027`로 멈춥니다. 그래서 바로 앞에 `setAnalysisMode -analysisType onChipVariation -cppr both`를 넣었습니다. 첫 재실행에서는 이 줄 없이 오류가 났고, `PostCTSopt`를 복원해 배선과 측정만 다시 했습니다.
