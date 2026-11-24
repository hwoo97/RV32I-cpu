# UART IP 합성 (실습 방식)

실습 Genus 흐름(`run_synthesis` + `script/<설계>.tcl`)과 같은 형식에서 경로·수치만 바꿨다. 설계: [design.md](../../03_chapters/ip_uart/design.md)

| 파일 | 내용 |
|------|------|
| `run_synthesis` | `genus -f ./script/uart_top_45nm.tcl -log ./log/all.log` (csh), 시작·끝 시각을 `cds_syn_runtime`에 |
| `script/uart_top_45nm.tcl` | 실습 Genus tcl 형식: 라이브러리 → RTL → SDC → syn_generic → syn_map → syn_opt → 보고서 → 넷리스트·SDC·SDF·LEC do 파일 |
| `cons/uart_top.sdc` | 클럭 4.0 ns(목표 5 ns × 0.8), APB 입출력 지연 30 %, `uart_rx`는 false path |
| `cons/dont_use_45nm.tcl` | 쓰지 않을 셀(ANTENNA, DLY, HOLD, TIE, TLA, DFFS, SDFF) |

실습 tcl에서 바꾼 것: 설계 이름·RTL 목록, GPDK045 경로를 변수 한 줄(`set GPDK045 /GPDK045`)로, slow 라이브러리만(패드 없음, fast를 같이 읽으면 같은 이름 셀이 fast 타이밍을 쓸 수 있어서), 하위 블록 preserve 없음, `write_do_lec` 켬

## 실행 (학교 서버, 이 폴더에서)
```
cd syn/ip_uart
./run_synthesis
```
- Genus가 끝나도 열려 있다(실습처럼 `quit` 없음). 프롬프트에서 `report_timing`, `report_area`, `gui_show`로 확인
- 대화형: `genus` 실행 → `source ./script/uart_top_45nm.tcl` 또는 구역(`## ...` 머리말)별로 붙여 넣기

## 확인할 것
| 보고서 | 볼 것 |
|------|------|
| `report/00_check_design.rpt` | unresolved·multiple driver 없음 |
| `report/06_report_constraint.rpt` | 위반 없음 |
| `report/09_uart_top_SYN_area.rpt` | 셀 면적, 모듈별(FIFO 두 개가 큰 몫일 것으로 예상) |
| `report/20_uart_top_SYN_timing.rpt` | WNS ≥ 0 (4.0 ns) |
| `mapped/uart_top_syn_final.v` | PnR 입력 넷리스트 |

## 결과 (2026-11-24, 학교 서버, slow 코너, 합성 클럭 4.0 ns)

| 항목 | 값 |
|------|------|
| 최악 경로 | **MET, slack +2 ps** — `paddr[8]` → 읽기 디코드·mux → `prdata[0]` (입력에서 출력으로 바로 가는 조합 경로) |
| 위반 | setup 위반 없음, max_capacitance·max_transition 항목 없음 |
| 셀 수·면적 | 1,341셀, **5,496.966 µm²** (net 포함 7,238.0 µm²) |

모듈별 셀 면적

| 모듈 | 셀 수 | 셀 면적 (µm²) | 비율 |
|------|------:|------:|------:|
| RX FIFO (16 × 10비트) | 335 | 1,953.162 | 35.5 % |
| TX FIFO (16 × 8비트) | 323 | 1,551.312 | 28.2 % |
| 레지스터·APB·인터럽트 (uart_regs) | 291 | 874.152 | 15.9 % |
| 수신기 (uart_rx) | 176 | 516.762 | 9.4 % |
| 송신기 (uart_tx) | 114 | 330.372 | 6.0 % |
| 보율 틱 (uart_baud) | 92 | 253.764 | 4.6 % |

- **FIFO 두 개가 면적의 64 %**: 플립플롭 배열(RX 160비트, TX 128비트)과 읽기 mux. SRAM이 없는 공정이라 깊이를 늘리면 면적이 거의 비례해 늘어남
- **최악 경로가 입력 → 출력 조합 경로인 이유**: APB 읽기 데이터(`prdata`)를 같은 사이클에 주소로 고르는 구조(대기 없음)라 `paddr` → `prdata`가 플립플롭을 거치지 않음. SDC가 입력 지연 1.2 ns + 출력 지연 1.2 ns + 불확실성 0.1 ns를 주므로 블록 안에 남는 시간은 1.5 ns. 데이터 경로 1.477 ns로 2 ps 남음. 플립플롭 사이 경로는 이보다 여유가 큼(리포트 1위가 아님)
- PnR(5 ns, 입출력 지연 1.5 ns)에서는 같은 경로에 1.9 ns가 남아 약 0.4 ns 여유(배선 지연 전 추정). 부족하면 SDC 입출력 비율을 다시 보거나 `prdata`를 레지스터로 내보내는(1사이클 대기) 구조를 검토
- 회로도(Genus GUI)에서 루프백 mux(MX2, RX 입력)와 `uart_tx` 핀의 OR(루프백이면 1) 확인. `pready`는 상수 1
