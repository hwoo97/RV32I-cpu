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

같은 `genus.tcl`을 두 방식으로 쓴다. 스크립트는 `STEP 0`~`STEP 8` 블록으로 나뉘어 있다.

| STEP | 내용 | 끝나고 볼 것 (대화형) |
|:---:|------|------|
| 0 | 경로·변수 (`CLK_PERIOD` 기본 10 ns) | |
| 1 | 속성, 라이브러리(slow) + LEF·QRC | |
| 2 | `read_hdl`, `elaborate` | `report_hierarchy`, `check_design` |
| 3 | SDC | `report_clocks`, `check_timing_intent` |
| 4 | `syn_generic` | `report_datapath` |
| 5 | `syn_map` | `report_timing`, `report_area` |
| 6 | `syn_opt` | `report_timing`, `report_area`, `gui_show`(회로도) |
| 7 | 리포트 파일 저장 | |
| 8 | 넷리스트·SDC·SDF·LEC do 파일 | |

**(A) 일괄 실행** — 처음부터 끝까지 돌리고 Genus를 닫은 뒤 요약 출력
```bash
bash syn/ch05_single_cycle/run_syn.sh
```
```bash
bash syn/ch05_single_cycle/run_syn.sh 5
```
- 인자 = 클럭 주기(ns), 기본 10. 결과: `runs/clk<주기>ns/`

**(B) 대화형** — Genus를 띄워 놓고 단계마다 결과를 보면서 진행
```bash
bash syn/ch05_single_cycle/run_syn.sh -i
```
- `runs/work/`에서 Genus 프롬프트가 열리고, **STEP 실행 도우미**([syn/common/steps.tcl](../common/steps.tcl))가 함께 로드된다.
  - 단계별: 프롬프트에 `step 0`, `step 1`, … `step 8`을 차례로 입력하고, 사이사이 위 표의 명령으로 확인
    - 복사·붙여 넣기가 필요 없다. 도우미가 `genus.tcl`에서 해당 STEP 블록을 읽어 그대로 실행한다
    - `steps` = STEP 목록, `show_step 5` = STEP 5 내용을 실행하지 않고 출력
  - 전체: `source $env(SYN_DIR)/genus.tcl` → 끝나도 Genus가 열려 있다
  - 직접 복사해 붙여 넣는 것도 되지만, Vim 화면에서 마우스로 복사하면 화면 글자(줄 번호, `%`, 안내 문구)가 섞일 수 있다
- 클럭 주기를 바꾸려면 `-i 5`, 또는 STEP 0 전에 프롬프트에서 `set CLK_PERIOD 5`
- 직접 띄워도 된다: `mkdir -p syn/ch05_single_cycle/runs/work`, 그 폴더로 `cd` 후 `genus` (STEP 0이 현재 폴더 기준으로 경로를 찾음)

- 결과 폴더(`runs/`)는 커밋하지 않는다
- LEF·QRC 없이 돌리려면 csh에서 `env USE_PHYS=0 bash syn/ch05_single_cycle/run_syn.sh`

### 작업물 정리 (처음부터 다시)
이 폴더에서:
```bash
./clean.tcl -n
```
```bash
./clean.tcl
```
- `-n` = 지울 목록만 보기, 인자 없음 = 목록을 보여 주고 y/N 확인 후 삭제, `-y` = 확인 없이 삭제
- 지우는 것: 이 폴더의 `runs/` 전체(일괄·대화형 결과, 로그, 리포트, 넷리스트, db)
- Genus 프롬프트 안에서도 된다: `source $env(ROOT)/tools/clean.tcl` 후 `clean syn ch05_single_cycle`. 이때 Genus가 일하고 있는 `runs/work`는 건너뛴다 (Genus를 끝낸 뒤 지우기)
- 공통 로직은 [tools/clean.tcl](../../tools/clean.tcl). git이 추적하는 파일과 저장소 밖 경로는 지우지 않는다
- 서버에 `tclsh`가 있어야 한다 (`which tclsh`로 확인)

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
