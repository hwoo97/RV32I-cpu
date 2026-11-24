# UART IP 블록 PnR (실습 방식)

실습 Innovus `all.tcl`과 같은 형식에서 경로·수치만 바꾸고, 패드가 없는 **블록**에 맞게 일부 구역을 뺐다.

| 파일 | 내용 |
|------|------|
| `all.tcl` | InitDesign → PowerPlan → Placement → CTS → Route → Power → Chip Finish → Write Out |
| `uart_top.mmmc.view` | 실습 mmmc와 같음(BEST/WORST RC, FF/SS 라이브러리), 패드 라이브러리 없음, SDC = `uart_top_func.sdc` |
| `uart_top_func.sdc` | 목표 5 ns(200 MHz), 합성 SDC와 주기·입출력 지연만 다름 |

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
