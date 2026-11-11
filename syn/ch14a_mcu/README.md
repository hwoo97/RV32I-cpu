# 4단계 MCU 합성 (Genus, gpdk045)

| 파일 | 역할 |
|------|------|
| [run_syn.sh](run_syn.sh) | 실행 스크립트 (bash). 인자 = 목표 주기, 합성은 그 80 %. 일괄은 `runs/t<목표>ns/`, 대화형(`-i`)은 `runs/work/` |
| [genus.tcl](genus.tcl) | Genus 흐름 STEP 0~8 — 3단계 [ch05 genus.tcl](../ch05_single_cycle/genus.tcl)과 같은 구조, 최상위·파일 목록·SDC만 다름 |
| [cons/rv32i_mcu.sdc](cons/rv32i_mcu.sdc) | 타이밍 제약 (3단계와 같은 메모리 시간 모델 + 주변장치 핀) |
| [clean.tcl](clean.tcl) | `./clean.tcl` — 이 폴더의 `runs/` 정리 |

## 1. 합성 대상과 방식
- **`rv32i_mcu`를 한 번에 합성(top-down)**하고 모듈 계층은 유지한다(`auto_ungroup none`) → `report_area`에서 모듈별 면적을 본다
  - 임계 경로가 코어 → 주소 디코더 → 메모리 → 코어로 모듈 경계를 여러 번 지나므로, 모듈별로 따로 합성해 합치면(bottom-up) 경로마다 시간을 나눠 정해야 하고 경계 최적화가 끊긴다. 이 크기(수천~1만 셀)에서는 한 번에 합성하는 쪽이 정확하고 간단하다
- 읽는 파일: 코어(`rv32i_core` + control, regfile, imm_gen, alu, branch_cmp, lsu — 대기(stall) 추가판), `bus_mux`, `apb_bridge`, `apb_gpio`, `apb_timer`, `apb_uart`, `rv32i_mcu`
- 빼는 파일: `mcu_imem`, `mcu_dmem`, `mcu_top` (시뮬레이션·FPGA 전용 — gpdk045에 SRAM 매크로가 없음)
- 목표 주기 **8 ns** (3단계와 같음) → 합성 6.4 ns. 클럭·여유 규칙은 [ch05 README 2절](../ch05_single_cycle/README.md)

## 2. 타이밍 제약 (SDC)
메모리 시간 모델은 3단계와 같다 (`T_ADDR` 0.5, `T_MEM` 1.0, `T_WB` 1.0, `T_WSU` 0.3 ns) → 두 결과를 그대로 비교할 수 있다.

| 포트 | 제약 | 이유 |
|------|------|------|
| `imem_addr` / `imem_rdata` | 출력 `주기 − T_ADDR` / 입력 `T_ADDR + T_MEM` | 명령어 읽기 (3단계와 같음) |
| `ram_addr`, `irom_addr` / `ram_rdata`, `irom_rdata` | 출력 `T_MEM + T_WB` / 입력 `주기 − T_WB` | 데이터 읽기. DMEM과 IMEM 데이터 포트에 같은 예산 (주소 디코더를 지나는 시간은 코어 몫) |
| `ram_wstrb`, `ram_wdata` | 출력 `T_WSU` | 다음 에지에 쓰기 |
| `apbx_*` (외부 APB 슬롯) | 메모리와 같은 예산 | 브리지가 `PSEL`·`PADDR`를 레지스터에 담지 않고 코어 주소에서 바로 내보냄 → 반 사이클을 주면 맞출 수 없음 |
| `gpio_out`, `gpio_oe`, `uart_tx` | 출력 주기 × 0.5 | 플립플롭 출력 → 패드·보드에 반 사이클 |
| `gpio_in`, `uart_rx` | `set_false_path` | 비동기 입력, 내부에서 2단 플립플롭으로 동기화 |
| `dbg_pc`, `trap`, `bus_err`, `timer_irq` | 출력 0 | 관찰·오류 신호 |
| `rst_n` | `set_false_path` | 비동기 리셋 |

- 3단계와 달라지는 경로: load의 주소가 **주소 디코더**를 거쳐 메모리로 가고, 읽은 값이 **디코더 MUX**(DMEM / IMEM / APB)를 거쳐 돌아온다. 또 `dmem_ready`(대기)가 PC·레지스터 쓰기 조건에 들어간다 → 같은 8 ns 안에서 코어 로직이 쓸 수 있는 시간이 조금 줄어든다
- APB 주변장치 내부 경로(브리지 상태 → `PSEL` → 주변장치 레지스터)는 칩 안이라 따로 제약할 것이 없다

## 3. 실행 (학교 서버)
`GPDK045_DIR` 설정은 [ch05 README 3절](../ch05_single_cycle/README.md)과 같다.

**(A) 일괄**
```bash
bash syn/ch14a_mcu/run_syn.sh
```
- 인자 = 목표 주기(ns), 기본 8 → 합성 6.4 ns. 결과 `syn/ch14a_mcu/runs/t8ns/`
- 끝나면 모듈별 면적, 최악 경로 slack, 위반 줄 수를 출력

**(B) 대화형**
```bash
bash syn/ch14a_mcu/run_syn.sh -i
```
- Genus 프롬프트에서 `step 0` … `step 8` (도우미 [steps.tcl](../common/steps.tcl)), 또는 `source $env(SYN_DIR)/genus.tcl`

| STEP | 내용 | 끝나고 볼 것 |
|:---:|------|------|
| 0 | 경로·변수, 클럭 (목표 8 ns → 합성 6.4 ns) | |
| 1 | 속성, 라이브러리 | |
| 2 | `read_hdl`, `elaborate` | `report_hierarchy` (u_core, u_bus_mux, u_apb_bridge, u_gpio, u_timer, u_uart) |
| 3 | SDC | `check_timing_intent` |
| 4 | `syn_generic` | `report_datapath` |
| 5 | `syn_map` | `report_timing`, `report_area` |
| 6 | `syn_opt` | `report_timing`, `report_area` |
| 7 | 리포트 저장 | |
| 8 | 넷리스트·SDC·SDF·LEC do 파일 | |

**작업물 정리**: 이 폴더에서 `./clean.tcl -n` (목록), `./clean.tcl` (확인 후 삭제)

## 4. 예상과 미리 확인한 것
- 이 PC에서 확인 (Genus 없이)
  - 스크립트를 Tcl 흉내 명령으로 끝까지 실행: 경로·주기(8 → 6.4 ns)·파일 목록 정상, SDC가 `rv32i_mcu` 포트 27개를 모두 제약
  - 합성 파일 목록만으로 `rv32i_mcu` 정교화(xelab) 성공
  - Vivado로 한 번 합성(Zynq-7000, 참고용): 래치·다중 구동 없음. 경고는 "쓰지 않는 입력 비트"(주변장치 `pwdata` 상위 비트, `paddr` 상위 비트, lsu 주소 상위 비트 등)뿐 → Genus에서도 같은 종류의 미사용 포트 메시지가 나올 수 있다
- 예상: 순차 셀 = 3단계 1,024개 + 주변장치·브리지 약 250개 (GPIO 16×2 + 동기화 32, TIMER 32×2 + 제어, UART 분주기·시프트 레지스터 등). 면적 증가는 주로 이 플립플롭과 APB 읽기 MUX

## 5. 결과
원본 리포트는 공개하지 않고 직접 정리한 값만 적는다. 조건: gpdk045 `slow_vdd1v0` (0.9 V / 125 °C), LEF·QRC, effort high.

| 날짜 | 목표 주기 | 합성 주기 | 셀 면적 (µm²) | 셀 수 (순차 / 조합) | WNS (ns) | 위반 | 비고 |
|------|----------:|----------:|--------------:|--------------------:|---------:|:----:|------|
| | 8 ns | 6.4 ns | (미실행) | | | | |

3단계 코어와 비교 (같은 목표 8 ns, 합성 6.4 ns)

| 모듈 | 3단계 `rv32i_core` (µm²) | 4단계 `rv32i_mcu` (µm²) |
|------|------:|------:|
| 코어 (`u_core`) | 21,459.8 | |
| 주소 디코더 (`u_bus_mux`) | — | |
| APB 브리지 (`u_apb_bridge`) | — | |
| GPIO / TIMER / UART | — | |
| **합계** | 21,459.8 | |
