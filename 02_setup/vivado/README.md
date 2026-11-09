# Vivado 확인
> 목적: 이 PC에서 Zynq-7000 FPGA 구현(합성·구현·비트스트림·ILA)을 할 수 있는지 확인한다. xsim은 빠른 확인용 보조 시뮬레이터 (주 시뮬레이터는 Linux 서버의 Xcelium).

| 파일 | 역할 |
|------|------|
| [`sim/run_sim.py`](../../sim/run_sim.py) | xvlog → xelab → xsim을 실행하고 PASS/FAIL 판정 |

## 1. 준비·설치
- 설치 위치: `C:\Xilinx\Vivado\2023.1` (Vitis·Vitis HLS 함께 설치됨)
- 다른 위치에 설치했다면 환경 변수 `VIVADO_BIN`에 `...\Vivado\<버전>\bin` 경로를 넣는다.

## 2. 절차
1. 테스트벤치 하나를 실행해 본다 (예: 카운터).
```bash
python sim/run_sim.py cnt_tb rtl/ch00_sample/cnt.v sim/ch00_sample/cnt_tb.v
```
2. 파형을 보고 싶으면 `--gui`를 붙인다.
```bash
python sim/run_sim.py cnt_tb rtl/ch00_sample/cnt.v sim/ch00_sample/cnt_tb.v --gui
```

## 3. 통과 기준
| # | 항목 | 통과 기준 |
|---|------|-----------|
| 1 | Vivado 설치 | `vivado`, `xvlog`, `xelab`, `xsim` 실행 파일 존재 |
| 2 | Zynq 디바이스 지원 | `data/parts/xilinx/zynq` 존재 |
| 3 | xsim 실행 | 샘플 테스트벤치 PASS, 일부러 틀린 기댓값으로 FAIL 판정 |
| 4 | 합성·구현 | Core-5300 칩 품번으로 LED 깜빡임 비트스트림 생성 (→ [board](../board/README.md)) |

## 4. 문제 해결
| 증상 | 확인·조치 |
|------|-----------|
| `ERROR: [XSIM 43-4099] Module ... doesn't have a timescale but at least one module in design has a timescale` | 설계 파일과 테스트벤치 **모두**에 `` `timescale 1ns/1ps ``를 넣는다 (교재 코드에 없으면 추가) |
| Git Bash에서 `xvlog` 직접 실행이 안 됨 | `.bat` 파일이라 `cmd //c` 또는 `run_sim.py`로 실행 |

## 5. 결과 기록
| 날짜 | 조건 | 항목 | 결과 | 비고 |
|------|------|------|------|------|
| 2026-11-04 | Windows 11, Vivado 2023.1 | 1 설치 | 통과 | `C:\Xilinx\Vivado\2023.1` |
| 2026-11-04 | 〃 | 2 Zynq 지원 | 통과 | zynq, zynquplus 설치됨 |
| 2026-11-04 | 〃 | 3 xsim (4비트 카운터) | 통과 | PASS / 틀린 기댓값 FAIL 확인, timescale 오류 1회 해결 |
| | | 4 합성·구현 | 미검증 | 보드 자료 필요 |
