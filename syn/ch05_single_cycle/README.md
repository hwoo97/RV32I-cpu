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

## 2. 클럭: 목표 주기와 합성 주기 (2026-11-11 결정)
합성은 배선 지연(추정)·클럭 스큐(없음, ideal clock)를 실제보다 낙관적으로 보므로, **목표 주기의 80 %로 합성**(over-constrain)하고 PnR에서 목표 주기를 맞춘다.

| 이름 | 뜻 | 기본 |
|------|----|-----:|
| `TARGET_PERIOD` | 칩이 맞춰야 하는 주기 (PnR 제약) | **8 ns (125 MHz, ch05 목표)** |
| `SYN_MARGIN` | 합성 주기 / 목표 주기 | 0.8 |
| `CLK_PERIOD` | 합성 SDC에 쓰는 주기 = `TARGET_PERIOD × SYN_MARGIN` | 6.4 ns |

- **ch05 목표 주기 = 8 ns (125 MHz)** — 2026-11-12 결정. 목표 8 ns(합성 6.4 ns) 만족, 목표 6 ns(합성 4.8 ns) 위반 결과를 보고 여유 있는 쪽으로 정함 (4절)

- SDC는 `CLK_PERIOD` 하나만 보므로, PnR에서는 같은 SDC를 `CLK_PERIOD = TARGET_PERIOD`로 읽는다
- 아래 메모리 시간 모델의 입출력 지연도 `CLK_PERIOD` 기준이라, 여유 20 %는 코어 로직 시간에서 빠진다 (8 ns 목표: 4.4 → 2.8 ns, uncertainty 0.1 ns 포함)

## 2-1. 메모리 접근 시간 모델 (SDC)
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
| `T_WB` | **1.2 ns** (2026-11-12까지 1.0) | `dmem_rdata` → lsu 확장·WB MUX → 레지스터 파일. 메모리 시간이 아니라 **코어 로직 시간을 메모리 앞뒤로 나눈 몫** |
| `T_WSU` | 0.3 ns | store 쓰기 셋업 (`dmem_wstrb`·`dmem_wdata`) |

- 메모리 앞 코어 구간(해독·레지스터·ALU) = `CLK_PERIOD − (T_ADDR + 2·T_MEM + T_WB)` = 주기 − 3.7 ns, 메모리 뒤 구간 = `T_WB`
- **`T_WB` 재배분 (2026-11-12)**: 메모리를 합성에서 빼서 생기는 임의의 경계다. 4단계 MCU에서 메모리 뒤 구간에 주소 디코더의 읽기 MUX가 더해져 1.0 ns로는 주기와 관계없이 맞출 수 없었다([../ch14a_mcu/README.md](../ch14a_mcu/README.md) 5절). 메모리 시간(`T_ADDR`, `T_MEM`)은 그대로 두고 3단계·MCU 모두 1.2 ns로 바꿨다. 다른 값을 시험하려면 csh에서 `env T_WB=1.0 bash syn/ch05_single_cycle/run_syn.sh`
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
| 0 | 경로·변수, 클럭 (목표 `TARGET_PERIOD` 기본 8 ns → 합성 `CLK_PERIOD` = 목표 × 0.8) | |
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
- 인자 = **목표** 클럭 주기(ns), 기본 8 (ch05 목표). 합성은 그 80 %(6.4 ns)로 한다. 결과: `runs/t<목표>ns/`
- 여유 비율을 바꾸려면 (csh): `env SYN_MARGIN=0.7 bash syn/ch05_single_cycle/run_syn.sh 8`

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
- 목표 주기를 바꾸려면 `-i 5`, 또는 STEP 0 전에 프롬프트에서 `set TARGET_PERIOD 5` (여유 비율은 `set SYN_MARGIN 0.7`)
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
원본 리포트는 공개하지 않고 직접 정리한 값만 적는다. 조건: Genus 22.17, gpdk045 `slow_vdd1v0` (PVT 0.9 V / 125 °C), LEF·QRC 사용(physical 모드), effort high.

| 날짜 | 목표 주기 | 합성 주기 | 셀 면적 (µm²) | 셀+배선 면적 (µm²) | 셀 수 (순차 / 조합) | WNS (ns) | 위반 | 비고 |
|------|----------:|----------:|--------------:|-------------------:|--------------------:|---------:|:----:|------|
| 2026-11-11 | (미정) | 10 ns | 16,182.8 | 22,594.5 | 4,369 (1,024 / 3,345) | 0.000 | 0 | `T_WB` 1.0. 대화형(STEP 0~8). 탐색용 첫 합성 — 80 % 여유 규칙 전, PnR 여유 없음 |
| 2026-11-11 | 8 ns | 6.4 ns | 21,459.8 | 29,067.6 | 5,614 | 0.000 | 0 | `T_WB` 1.0. 일괄. 만족 → **ch05 목표로 확정** (PnR 입력) |
| 2026-11-11 | 6 ns | 4.8 ns | 31,224.9 | 41,176.8 | 7,818 | **−1.000** | 870줄 | `T_WB` 1.0. 일괄. **불만족** |
| 2026-11-12 | 8 ns | 6.4 ns | 22,917.4 | 31,150.9 | 6,029 | 0.000 | 0 | **`T_WB` 1.2** 일괄. 만족 (메모리 앞 구간이 0.2 ns 줄어 ALU를 더 빠르게 → 면적 +6.8 %). **이후 비교 기준** |

주기에 따른 면적 변화 (셀 면적, µm²)

| 합성 주기 | 전체 | regfile | alu | branch_cmp | lsu | control | imm_gen | 결과 |
|----------:|-----:|--------:|----:|-----------:|----:|--------:|--------:|:----:|
| 10 ns | 16,182.8 | 11,869.8 | 1,989.8 | 362.9 | 357.0 | 206.2 | 100.9 | 만족 |
| 6.4 ns | 21,459.8 (+33 %) | 14,326.4 | 4,118.7 | 392.6 | 416.2 | 249.3 | 216.5 | 만족 |
| 6.4 ns, `T_WB` 1.2 | 22,917.4 | 14,726.2 | 5,124.2 | 398.4 | 335.5 | 317.4 | 250.3 | 만족 |
| 4.8 ns | 31,224.9 (+93 %) | 18,926.3 | 7,718.9 | 537.3 | 582.8 | 523.9 | 340.6 | 위반 |

- 주기를 줄이면 Genus가 더 크고 빠른 셀·병렬 구조(빠른 덧셈기 등)를 써서 면적이 커진다: ALU 면적이 10 → 6.4 → 4.8 ns에서 약 2배, 4배
- 합성 주기 4.8 ns에서는 코어 로직에 남는 시간이 4.8 − 3.5(메모리 가정) − 0.1(uncertainty) = 1.2 ns뿐이라 맞추지 못함
- 합성 기준 최소 주기는 4.8 ~ 6.4 ns 사이 → 80 % 규칙으로 환산한 목표 주기는 6 ~ 8 ns 사이
- 4.8 ns의 slack이 정확히 −1.000 ns로 나온 이유와 위반 경로는 리포트 확인 필요 (미확인)


- **WNS 0.000의 뜻**: 타이밍은 만족했지만 여유가 정확히 0이다. Genus는 시간이 남으면 작고 느린 셀로 바꿔 면적을 줄이므로(area recovery), 10 ns에서는 여유를 다 써 버린다. 따라서 **이 CPU가 낼 수 있는 최소 주기는 10 ns보다 짧다** → 주기를 줄여 가며 다시 합성해 찾는다.
- 순차 셀 1,024개 = 레지스터 파일 992개(31 × 32) + PC 32개 → 설계 의도와 같다 (래치 0개)
- 설계 규칙(max transition·capacitance) 위반 없음, 미해결 참조·다중 구동 없음
- 전력(참고, 기본 입력 활동률): 약 0.44 mW (내부 0.31, 스위칭 0.13, 누설 0.0003 mW)

모듈별 셀 면적

| 모듈 | 셀 수 | 셀 면적 (µm²) | 비율 |
|------|------:|-------------:|-----:|
| `u_regfile` | 2,524 | 11,869.8 | 73.3 % |
| `u_alu` | 972 | 1,989.8 | 12.3 % |
| `u_branch_cmp` | 211 | 362.9 | 2.2 % |
| `u_lsu` | 156 | 357.0 | 2.2 % |
| `u_control` | 84 | 206.2 | 1.3 % |
| `u_imm_gen` | 56 | 100.9 | 0.6 % |
| 그 밖 (PC, PC+4·PC+imm 덧셈기, MUX) | 366 | 1,296.2 | 8.0 % |
| **합계** | **4,369** | **16,182.8** | |

- 레지스터 파일이 면적의 3/4: 플립플롭 992개 + 32:1 읽기 MUX 2개. ASIC에서는 보통 레지스터 파일 전용 매크로를 쓰지만 gpdk045에는 없어 플립플롭으로 만들어졌다

임계 경로 (10 ns, slack 0)

```
imem_rdata[20] (rs1 번호, 입력 지연 1.5 ns)
 -> regfile 읽기 MUX (rs1 선택)            1.5 -> 3.2 ns
 -> ALU A 입력 MUX -> ALU 덧셈기(캐리 체인) 3.2 -> 7.2 ns
 -> lsu 정렬 검사 (주소 하위 비트)          7.2 -> 7.8 ns
 -> dmem_re 출력 (출력 지연 2.0 ns)         도착 7.9 ns = 요구 시간 7.9 ns
```
- 예상한 단일 사이클 경로(명령어 → 레지스터 읽기 → ALU 주소 계산 → 데이터 메모리)와 같다
- 그다음 경로들도 같은 흐름으로 레지스터 파일 쓰기(`regs_reg_31_*` D 입력)에서 끝난다

리포트에서 본 경고 (영향 없음으로 판단)
- `LBR-9`, `PHYS-279`: 라이브러리의 출력 핀 없는 셀(필러 등)과 LEF에만 있는 물리 셀 → 합성에 쓰이지 않는 셀이라 무시
- `rst_n` 입력 지연 없음 / `set_false_path -from rst_n` 효과 없음: 비동기 리셋이 데이터 경로가 아니라서 생기는 정상 메시지
- `TUI-78` 6건(찾는 객체 없음): 로그를 보고 어느 명령인지 확인 필요 (미확인)
