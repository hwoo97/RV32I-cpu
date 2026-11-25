# syn/ch06_uartip — RV32I MCU 칩 합성 (실습 방식)

UART IP를 붙인 6장 MCU 칩([03_chapters/ch06_uartip](../../03_chapters/ch06_uartip/design.md), `rv32i_chip` = `rv32i_mcu` + IO 패드 197개)을 **실습 형식**(실습 `run_synthesis` + Genus `cortexm0_45nm.tcl`)으로 다시 합성하는 폴더입니다. 프로젝트 방식 흐름([syn/ch06_chip](../ch06_chip/README.md), STEP·래퍼·`runs/`)은 그대로 두고, 같은 설정을 실습 형식 파일로 옮겼습니다. UART IP의 [syn/ip_uart](../ip_uart/README.md)와 같은 구성입니다.

| 파일 | 내용 |
|------|------|
| `run_synthesis` | 실습과 같은 csh 실행 파일: `genus -f ./script/rv32i_chip_45nm.tcl -log ./log/all.log` |
| `script/rv32i_chip_45nm.tcl` | 실습 Genus 스크립트 형식. RTL = `rtl/ch06_uartip` + `rtl/ip_uart`. slow 표준 셀 + 패드 SS 라이브러리, 패드 LEF `giolib045_modify.lef`, 패드 셀 `dont_touch`, `write_do_lec` |
| `cons/rv32i_chip.sdc` | 프로젝트 SDC와 같은 제약을 숫자로 채운 것: 합성 클럭 10.4 ns(목표 13 ns × 0.8), 가상 클럭 `vclk`(메모리 읽기 왕복), 핀 예산(주소 2.0, 메모리 1.0, 핀→레지스터 2.3 ns) |
| `cons/dont_use_45nm.tcl` | 실습 dont_use 목록 (UART와 같음) |

RTL 시뮬레이션은 [sim/ch06_uartip/run_function.tcl](../../sim/ch06_uartip/run_function.tcl)입니다. `chip_tb` + 칩 RTL + PDK 패드 모델로 돌리고, 프로그램은 `set HEX`(기본 `uart_irq.hex`: UART IP 핀 루프백 + RX 인터럽트)로 고릅니다.

## 실행 (학교 서버, 저장소 안에서 바로)
1. RTL 시뮬레이션: `cd sim/ch06_uartip ; source run_function.tcl` → SimVision에서 `run` → `PASS` 줄
2. 합성: `cd syn/ch06_uartip ; ./run_synthesis` (또는 `genus` 뒤 `source ./script/rv32i_chip_45nm.tcl`)

## 확인할 것
| 보고서 | 볼 것 |
|------|------|
| `report/00_check_design.rpt` | unresolved 없음 |
| `report/06_report_constraint.rpt` | 위반 없음 |
| `report/09_rv32i_chip_SYN_area.rpt` | 셀 면적 (UART IP 없는 칩의 프로젝트 흐름 결과 30,531.7 µm² + UART IP 약 5,500 µm²와 비교) |
| `report/20_rv32i_chip_SYN_timing.rpt` | WNS ≥ 0 (10.4 ns) |
| `mapped/rv32i_chip_syn_final.v`, `rv32i_chip_delays.sdf` | PnR 입력 넷리스트, Pre-layout 시뮬레이션용 SDF |

- 미검증: 서버에서 아직 실행하지 않음
