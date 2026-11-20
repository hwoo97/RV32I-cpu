# ec/ch06_chip — ch6 MCU 칩 등가성 검사 (Conformal LEC)

합성과 PnR이 설계의 **논리 기능**을 바꾸지 않았는지 형식 검증(정적 비교)으로 확인합니다.
시뮬레이션은 넣어 본 입력에 대해서만 확인하지만, LEC는 모든 입력 조합에 대해 출력과 플립플롭의 다음 값이 같은지 증명합니다.

| 비교 | golden (기준) | revised (비교 대상) | do 파일 |
|------|------|------|------|
| RTL ↔ 합성 | `rtl/ch06_exception` 15개 파일 (Genus가 읽은 목록) | `syn/ch06_chip/runs/t13ns/mapped/rv32i_chip_syn_final.v` | [rtl2syn.do](rtl2syn.do) |
| 합성 ↔ PnR | 위 합성 넷리스트 | `pnr/ch06_chip/runs/<run>/out/rv32i_chip_pnr.v` | [syn2pnr.do](syn2pnr.do) |

- do 파일은 실습과 같은 Conformal 기본 명령 형식입니다. 순서는 `read library` → `read design` → `set system mode lec` → `add compare points -all` → `compare` → `report`입니다.
- 라이브러리 읽는 방식이 두 비교에서 다릅니다.
  - **syn2pnr**: 실습처럼 **Verilog 시뮬레이션 모델**을 `-both`로 읽습니다. 표준 셀은 slow 모델 하나만 읽습니다(셀의 논리 기능은 코너와 관계없이 같음). 패드는 `pads_SS_s1vg.v`를 읽고, 이 모델에 없는 전원 패드 4종은 `sim/ch06_exception/pad_power.v`(포트 없는 빈 모듈)로 정의합니다.
  - **rtl2syn**: Genus가 매핑에 쓴 **Liberty(`.lib`)**를 읽습니다. Genus가 만드는 LEC do 파일과 같은 방식입니다. 라이브러리에 없는 전원 패드는 `set undefined cell black_box`로 빈 블랙박스로 둡니다. (시뮬레이션 모델로 읽어도 결과는 같았습니다. 1차 실행의 Non-equivalent는 라이브러리 문제가 아니라 아래 `pc[1:0]` 때문이었습니다.)
- PDK 파일은 저장소에 넣지 않습니다. 실행 폴더의 `lib/`에 `GPDK045_DIR` 안의 파일을 링크합니다.

## 실행 순서

1. **학교 서버에서 묶기** (합성 13 ns와 PnR이 끝난 상태)
   ```
   bash ec/ch06_chip/run_lec.sh --pack
   ```
   → `ec/ch06_chip/out/lec_ch06_chip.tar.gz`가 생깁니다. 안에는 RTL, 두 넷리스트, 이 폴더의 스크립트가 저장소 상대 경로 그대로 들어 있습니다. PDK 파일은 들어 있지 않습니다.
2. **LEC 서버로 옮기고 풀기**. 이전에 풀어 둔 폴더가 있으면 먼저 지웁니다(LEC 서버에는 이전 작업 폴더를 남기지 않습니다).
   ```
   cd ~ ; rm -rf rv32i_lec
   mkdir rv32i_lec ; cd rv32i_lec ; tar xzf ~/lec_ch06_chip.tar.gz
   setenv GPDK045_DIR <GPDK045 폴더>
   ```
3. **실행**: 아래 일괄 또는 대화형 명령을 씁니다. 같은 저장소 구조이므로 명령도 같습니다.

## 일괄 실행

```
bash ec/ch06_chip/run_lec.sh                # rtl2syn, syn2pnr 차례로
bash ec/ch06_chip/run_lec.sh syn2pnr        # 하나만
```
- 실행 폴더는 `runs/<비교>/`이고 로그는 `log/<비교>.log`에 남습니다. 툴의 화면 출력은 `log/lec_stdout.log`에 남습니다.
- 끝나면 비교 요약(`Equivalent`, `Non-equivalent`, `Abort` 줄)과 PASS/FAIL을 출력합니다.
- 실행 명령이 `lec -xl`이 아니면 `env LEC_CMD="<명령>" bash ...`로 바꿉니다.

## 대화형 실행 (실습 방식)

```
bash ec/ch06_chip/run_lec.sh -i rtl2syn         # LEC 프롬프트
bash ec/ch06_chip/run_lec.sh --gui rtl2syn      # GUI에서 do 파일 전체 실행, 끝나도 열려 있음
bash ec/ch06_chip/run_lec.sh -i --gui rtl2syn   # GUI + 단계별 직접
```
- 실행 폴더는 `runs/work/`입니다. 스크립트가 `lib/`, `rtl/`, `syn.v`, `pnr.v` 링크를 만들어 두므로 do 파일의 상대 경로가 그대로 맞습니다.
- 프롬프트에 do 파일의 `// ## STEP n.` 블록을 하나씩 복사해 붙여 넣으며 중간 결과를 봅니다. 한 번에 돌리려면 `dofile <저장소>/ec/ch06_chip/rtl2syn.do`를 입력합니다.
- 한 비교를 마친 뒤 다른 비교를 하려면 `reset`으로 비우거나, 툴을 다시 띄웁니다.

| STEP | rtl2syn | syn2pnr | 확인할 것 |
|------|------|------|------|
| 0 | 로그 파일 | 로그 파일 | `log/` 생성 |
| 1 | 라이브러리 읽기 | 라이브러리 읽기 | 오류 없이 셀·패드 모듈 수 표시 |
| 2 | golden = RTL | golden = 합성 넷리스트 | `Error` 없음, top = `rv32i_chip` |
| 3 | revised = 합성 넷리스트 | revised = PnR 넷리스트 | 같음 |
| 4 | `set flatten model -seq_constant` | 매핑 + `report unmapped points` | — |
| 5 | 매핑 + `report unmapped points` | 비교 | unmapped 항목이 설명 가능한지 (아래 참고) |
| 6 | 비교 | 보고서 | `Non-equivalent` 0, `Abort` 0 |
| 7 | 보고서 | — | `report verification`의 항목 확인 |

## 판정 기준과 예상되는 보고

- **PASS**: 비교 요약에 `Equivalent`만 있고 `Non-equivalent`, `Abort`가 없습니다.
- 예상되는 unmapped 항목은 다음과 같습니다.
  - rtl2syn: 합성이 상수로 바꾸거나 지운 레지스터는 golden에만 남습니다. 예를 들어 출력에 쓰이지 않는 비트가 그렇습니다. `-seq_constant`와 함께 "unreachable" 또는 "extra"로 분류되면 정상입니다.
  - rtl2syn의 **`pc[1:0]` 제약**: RTL에서 `pc[1:0]`은 항상 0입니다. 리셋 값이 0이고, trap·mret 목적지의 하위 2비트가 0이고, `pc + 4`는 하위 비트를 유지하고, 하위 2비트가 0이 아닌 점프·분기 목표는 `jmp_misalign` 예외로 trap 목적지로 바뀌기 때문입니다. Genus는 이를 증명해 두 플립플롭을 지웠지만, LEC는 자기 출력이 되먹임돼야만 성립하는 상수라서 찾지 못합니다(`-seq_constant_feedback`도 효과 없음). 그러면 RTL 쪽 두 비트가 자유 입력이 되어 PC에 의존하는 모든 점(pc, 레지스터 파일, CSR, TRAP)이 다르게 나옵니다. 그래서 `add instance constraints 0 .../pc_reg[0]`, `[1]`을 golden에 넣습니다. **가정**이므로 근거(위 불변식)를 do 파일에 적어 두었습니다. 게이트 수준 시뮬레이션(정렬 안 된 점프를 시험하는 rv32mi `ma_fetch` 포함 PASS)이 같은 동작을 동적으로 뒷받침합니다.
  - syn2pnr: 전원 패드 4개(`P_N_VDD` 등)는 PnR 넷리스트에 없습니다. 핀이 없는 블랙박스라서 비교 점이 생기지 않습니다. CTS·hold 버퍼와 크기가 바뀐 셀은 조합 논리 안에 있으므로 비교 점에 영향이 없습니다.
- `read design`에서 정의되지 않은 모듈 오류가 나면 해당 모듈 이름을 확인합니다. 라이브러리 모델 경로나 `pad_power.v`가 빠진 경우입니다.

## 결과

| 날짜 | 비교 | Equivalent | Non-equivalent | Abort | 비고 |
|------|------|------|------|------|------|
| 2026-11-20 | rtl2syn (1차) | PO 80, DFF 360 | PO 1, DFF 1159 | 0 | `pc[1:0]` 제약 없음 → 원인 분석 |
| 2026-11-20 | rtl2syn | **PO 81, DFF 1519 (전부)** | 0 | 0 | **PASS** (`pc[1:0]` = 0 제약, 대화형 실행) |
| 2026-11-20 | rtl2syn (일괄 재실행) | **PO 81, DFF 1519 (전부)** | 0 | 0 | **PASS** — 최종 |
| 2026-11-20 | syn2pnr (일괄 재실행) | **PO 81, DFF 1519 (전부)** | 0 | 0 | **PASS** — 최종 |
| 2026-11-20 | syn2pnr | **PO 81, DFF 1519 (전부)** | 0 | 0 | **PASS** |

- 두 비교 모두 LEC 서버의 Conformal에서 `bash ec/ch06_chip/run_lec.sh` 일괄 실행으로 PASS를 확인했습니다(커밋 fdb5426의 스크립트).
- 이 결과로 단일 사이클 MCU 칩의 최종 검증(PnR·STA·DRC·게이트 수준 시뮬레이션·LEC)을 모두 마쳤습니다.

## 정리

```
./clean.tcl -n      # 지울 목록 (runs/, out/)
./clean.tcl
```
