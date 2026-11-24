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

## 결과
미검증 (서버 실행 전)
