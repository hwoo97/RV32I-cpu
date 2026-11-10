# ch05 단일 사이클 CPU 코어 합성 (Genus, gpdk045)

| 파일 | 역할 |
|------|------|
| [run_syn.sh](run_syn.sh) | 실행 스크립트 (bash). 클럭 주기를 인자로 받아 `runs/clk<주기>ns/`에서 Genus 실행, 끝나면 면적·slack 요약 출력 |
| [genus.tcl](genus.tcl) | Genus 흐름: 라이브러리 → RTL 읽기 → SDC → `syn_generic` → `syn_map` → `syn_opt` → 리포트 → 넷리스트·SDC·SDF·LEC do 파일 |
| [cons/rv32i_core.sdc](cons/rv32i_core.sdc) | 타이밍 제약 (클럭, 메모리 접근 시간을 나눈 입출력 지연) |
| [../common/gpdk045.tcl](../common/gpdk045.tcl) | gpdk045 라이브러리 읽기 (경로는 환경 변수 `GPDK045_DIR`) — 장마다 같이 씀 |

## 1. 합성 대상
- **`rv32i_core`** (control, regfile, imm_gen, alu, branch_cmp, lsu). 명령어·데이터 메모리는 뺀다.
  - gpdk045에는 SRAM 매크로가 없다. 메모리(각 8 KB)를 합성하면 플립플롭 약 13만 개로 풀려 코어 결과를 읽을 수 없다.
  - 메모리는 [`rv32i_sc`](../../rtl/ch05_single_cycle/rv32i_sc.v)(시뮬레이션·FPGA용)에서 코어에 붙인다.
- 라이브러리: `slow_vdd1v0_basicCells` (최악 코너, setup 기준) + LEF·QRC (배선 지연 추정)
- 모듈 계층 유지 (`auto_ungroup none`) → 모듈별 면적 비교 가능

## 2. 메모리 접근 시간 모델 (SDC)
단일 사이클 CPU는 한 사이클 안에서 메모리를 **두 번** 읽는다(명령어, load 데이터). 메모리가 코어 바깥에 있으므로, 한 사이클을 아래처럼 나눠 입출력 지연으로 준다.

```
 0                                                                       CLK_PERIOD
 |--T_ADDR--|---T_MEM---|------- 코어 (해독·레지스터·ALU) -------|---T_MEM---|--T_WB--|
 pc→imem_addr  imem 읽기   imem_rdata ──────────────────▶ dmem_addr   dmem 읽기   dmem_rdata→레지스터
```

| 값 | 기본 | 뜻 |
|----|-----:|----|
| `T_ADDR` | 0.5 ns | pc 플롭 → `imem_addr` 포트 |
| `T_MEM` | 1.0 ns | 메모리 읽기 시간 (가정값) |
| `T_WB` | 1.0 ns | `dmem_rdata` → lsu 확장·WB MUX → 레지스터 파일 |
| `T_WSU` | 0.3 ns | store 쓰기 셋업 (`dmem_wstrb`·`dmem_wdata`) |

- 코어 로직에 남는 시간 = `CLK_PERIOD − (T_ADDR + 2·T_MEM + T_WB)` = 주기 − 3.5 ns
- 따라서 이 결과의 최대 주파수는 **가정한 메모리 시간을 포함한 값**이다. 비교할 때 같은 가정을 쓴다 (멀티사이클·파이프라인 장에서도 같은 T_MEM).

## 3. 실행 (학교 서버)
처음 한 번: GPDK045 폴더 위치를 환경 변수로 등록한다 (이 경로는 저장소에 적지 않는다).
```bash
setenv GPDK045_DIR <GPDK045 폴더의 절대 경로>
```
- `<GPDK045 폴더>` = 그 아래에 `digital/gsclib045_all_v4.4/`가 있는 폴더
- 매번 치기 번거로우면 `~/.cshrc`에 같은 줄을 넣는다

합성:
```bash
bash syn/ch05_single_cycle/run_syn.sh
```
```bash
bash syn/ch05_single_cycle/run_syn.sh 5
```
- 인자 = 클럭 주기(ns), 기본 10
- 결과: `syn/ch05_single_cycle/runs/clk<주기>ns/` 아래 `report/`(리포트), `mapped/`(넷리스트·SDC·SDF·`rtl2gate.do`), `log/` — 커밋하지 않음
- LEF·QRC 없이 돌리려면 `USE_PHYS=0 bash syn/ch05_single_cycle/run_syn.sh`

## 4. 결과
원본 리포트는 공개하지 않고 직접 정리한 값만 적는다.

| 날짜 | 클럭 주기 | 면적 (µm²) | 셀 수 | WNS (ns) | 비고 |
|------|----------:|-----------:|------:|---------:|------|
| | 10 ns | | | | 미실행 |

모듈별 면적 (`report_area`)

| 모듈 | 면적 (µm²) | 비율 |
|------|-----------:|-----:|
| `u_regfile` | | |
| `u_alu` | | |
| `u_control` | | |
| `u_lsu` | | |
| `u_imm_gen` | | |
| `u_branch_cmp` | | |
| 그 밖(PC·MUX) | | |
