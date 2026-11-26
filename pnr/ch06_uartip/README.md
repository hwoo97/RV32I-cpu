# pnr/ch06_uartip — UART IP를 붙인 RV32I MCU 칩 PnR (실습 방식)

[03_chapters/ch06_uartip](../../03_chapters/ch06_uartip/design.md) 칩(`rv32i_chip`, IO 패드 197개)을 실습 Innovus `all.tcl` 형식으로 배치·배선합니다. 프로젝트 방식 흐름 [pnr/ch06_chip](../ch06_chip/README.md)(STEP 스크립트, UART IP 없는 칩)에서 찾은 해결책을 실습 형식 안에 옮겼고, UART IP 블록 흐름 [pnr/ip_uart](../ip_uart/README.md)처럼 포트폴리오용 리포트를 더했습니다.

| 파일 | 내용 |
|------|------|
| `all.tcl` | InitDesign → PowerPlan → Placement → CTS → Route → Power → Chip Finish → Write Out |
| `rv32i_chip.mmmc.view` | 실습 mmmc와 같은 BEST/WORST RC, FF/SS 라이브러리 + 패드 라이브러리. 제약 모드 2개(`FUNC_S`, `FUNC_F`, 같은 SDC) |
| `rv32i_chip_func.sdc` | 13 ns 목표. 합성 SDC와 주기만 다름(가상 클럭 `vclk`, 메모리 핀 예산 같음) |
| `rv32i_chip.io` | 패드 순서. `pnr/ch06_chip/rv32i_chip.io`와 같음(칩 핀이 바뀌지 않음) |

## 실습 all.tcl과 다른 점
| 구역 | 실습 (cmsdk_mcu) | 이 칩 | 이유 |
|------|------|------|------|
| Init | — | 이중 높이 셀(`CoreSiteDouble`) dont_use | 행이 `CoreSite`뿐이라 checkPlace TechSite 위반 95개가 났던 것 |
| Floorplan | 코어 이용률 0.7, 여백 1200 | 다이 3705 µm(19 µm 배수: 배치 격자 0.2·0.19와 정수 µm), 코어 약 1400 µm(가운데) | 패드 197개로 다이가 정해짐. 코어가 패드에서 멀면 입력 패드 넷 max_tran 위반 |
| 패드 배치 | `placeInstance padNN x y`(전원 패드)를 손으로 | 변마다 모든 패드를 IO 파일 순서로 코너 사이에 고르게, 코너에서 **정수 µm** 위치에 다시 놓음(전원 패드 포함). `addIoFiller` 뒤 `ring_gaps`로 링 틈 수 출력 | AREAIO 전원 패드가 코어 안에 놓이는 문제. IO 파일 기본 배치는 좌표 끝수(예 .505)로 패드 사이 틈이 0.3 µm 정도 남아 가장 좁은 필러(1 µm)로 못 메움 |
| PowerPlan | 안쪽 링, 스트라이프, 바깥 링, 패드 연결, 링 사이 스트라이프 | 같은 순서 + 단계마다 전원 검사(`reports/03_pgcheck.txt`), 마지막 `editTrim` | 스트라이프 끝 76개 dangling을 정리 |
| Placement | — | `addTieHiLo` | 합성에서 TIE 셀을 쓰지 않음 |
| CTS | 목표 스큐 0.01 | 강한 클럭 셀, trunk Metal7-8, `update_io_latency false`, 목표 스큐 0.05, 가상 클럭 지연 = 측정한 삽입 지연 | 기본값 실행에서 hold −1.134 ns(2,216 경로) |
| Route 뒤 최적화 | bcwc로 setup·hold | OCV 유지 + setup 목표 여유 0.05 | hold 수정·Filler가 0 여유 setup을 먹었던 것(−0.012) |
| 출력 | `saveNetlist -flat` | 계층 넷리스트 | SDF 이름과 계층이 맞아야 함(UART IP에서 확인) |
| 포트폴리오 | — | 셀 개수 `reports/cell_count.txt`, 배선 직후 OCV 타이밍, hold 수정 전·후, Filler 뒤 최종, `RouteDesign_for_ECO`(single) | FE·BE 포트폴리오 항목 |

## 실행 (학교 서버, 합성 뒤 이 폴더에서)
```
cd pnr/ch06_uartip
innovus
```
Innovus 프롬프트에서 `source all.tcl`(전체) 또는 구역별로 붙여 넣습니다. 중간 저장(`InitDesign`, `PowerPlan`, `PlaceOpt`, `PostCTSopt`, `RouteDesign`, `RouteDesign_for_ECO`, `ChipFinish`)에서 `restoreDesign <이름>.dat rv32i_chip`으로 다시 시작합니다. 다시 시작할 때는 파일 위쪽의 `proc`들과 `set GPDK045 /GPDK045`를 먼저 붙여 넣고, CTS부터라면 `set DOUBLE_CELLS [dont_use_double_height]`도 실행합니다.

## 확인할 것
| 단계 | 볼 것 |
|------|------|
| Floorplan | 로그 `side <변>: N pads ... gap about ...`(4줄), `pads placed again: 197`, `core box = 1150 1150 2550 2550`, `IO ring gaps: 0` |
| PowerPlan | `reports/03_pgcheck.txt` 단계마다 opens 없음·DRC 0 |
| CTS | 로그 `vclk latency (FUNC_S / FUNC_F)`, `reports/clock/skew_groups.rpt` |
| 각 timeDesign | `reports/timing/<단계>/` setup·hold WNS ≥ 0 |
| Chip Finish | verify_drc 0, verifyConnectivity(신호 넷 0, IO 링 항목은 예전 칩과 같은 종류만), checkPlace 위반 0 |
| Write Out | `rv32i_chip_pnr.v`, `rv32i_chip_slow.sdf`, `rv32i_chip_fast.sdf` |

- 미검증: 서버에서 아직 실행하지 않음
