# RV32I CPU 설계 및 FPGA 구현

교재 *Computer Principles and Design in Verilog HDL* (Yamin Li, Wiley 2015)의 CPU 설계 흐름(단일 사이클 → 예외 → 멀티사이클 → 파이프라인 → FPU → 캐시·TLB → 멀티코어 → I/O)을 따라, 교재의 MIPS 대신 **RISC-V(RV32I + 표준 확장)** CPU와 MCU를 직접 설계하고 공식 테스트로 검증한 뒤 Zynq-7000 FPGA와 45 nm ASIC 합성으로 장별 비용·성능을 비교하는 프로젝트.

> 교재는 원리와 회로 구조를 참고했고, 설계 코드는 RISC-V 명세를 기준으로 직접 작성했다. 교재 본문·그림은 포함하지 않는다.

## 구성
| 구분 | 내용 |
|------|------|
| ISA | RV32I → Zicsr·M 모드 트랩, F, S 모드·Sv32 (장마다 확장) |
| HDL | Verilog-2005 |
| 검증 | riscv-tests, Spike, 자가 검사 테스트벤치, Cadence Xcelium |
| 툴체인 | RISC-V GCC, RARS |
| FPGA | Vivado, Core-5300 (Zynq-7000 SoC, PL에 CPU 구현) |
| ASIC | Cadence Genus(합성)·Innovus(PnR)·Conformal LEC(등가성 검사), gpdk045 (45 nm) |

## 문서
- [개요서](01_planning/overview.md) — 목적, 환경, 장별 진행 내용, 절차, 완료 기준, 리스크
- [진행 프로세스](PROCESS.md) — 7단계(기획 → 환경 준비 → 단일 사이클 CPU → MCU → CPU 고도화 → 고급 → 마무리)
- [장별 결과 비교](04_results/README.md)

## 폴더 구조
```
├─ 01_planning/   개요서
├─ 02_setup/      환경 준비 점검 기록 (Vivado, 보드, RISC-V 툴체인)
├─ 03_chapters/   장별 정리(notes.md)·테스트 기록(test.md)
├─ 04_results/    장별 합성·성능 비교표
├─ 05_final/      포트폴리오·발표 자료
├─ tools/         점검 스크립트
├─ rtl/           설계 Verilog (장별 chNN_<주제>/)
├─ sim/           테스트벤치·테스트 프로그램 (장별)
├─ fw/            C 펌웨어 (crt0·링커 스크립트·printf, MCU 4단계부터)
├─ fpga/          Vivado 프로젝트 Tcl·XDC (장별)
├─ syn/           합성 스크립트·결과 요약
├─ pnr/           대표 설계 ASIC 배치·배선 (마무리 단계)
└─ ec/            대표 설계 등가성 검사 (마무리 단계)
```

## 현재 상태
| 1 기획 | 2 환경 준비 | 3 단일 사이클 CPU | 4 MCU | 5 CPU 고도화(6~8장) | 6 고급(9~13장·I/O) | 7 마무리 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 완료 | 완료 (보드 자료는 MCU 데모 전 확보) | 완료 | **진행 중** | 대기 | 대기 | 대기 |

- 시작: 2026-10-28 · 교재 흐름 도입: 2026-11-04 · 교재 흐름 + RV32I로 확정: 2026-11-09
- **3단계 단일 사이클 CPU 완료 (2026-11-12)**: riscv-tests rv32ui 40/40 PASS (xsim·Xcelium), gpdk045 합성 목표 8 ns(125 MHz, 합성 6.4 ns) 만족 — 셀 면적 21,460 µm² ([테스트 기록](03_chapters/ch05_single_cycle/test.md), [합성 결과](syn/ch05_single_cycle/README.md))
