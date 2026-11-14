# ch06 예외·인터럽트 테스트 기록

설계: [design.md](design.md) · RTL: [rtl/ch06_exception/](../../rtl/ch06_exception/) · 테스트: [sim/ch06_exception/](../../sim/ch06_exception/)

## 1. CSR 파일 단독 — `csr.v`
[csr_tb.v](../../sim/ch06_exception/csr_tb.v): 테스트벤치가 코어 역할을 하며 한 사이클에 명령어 하나씩 넣는다. 대기(idle) 사이클도 명령어 하나로 실행되므로(카운터가 늘고 인터럽트가 받아들여짐) 그것까지 계산해 기대값을 정했다.

| 시험 | 내용 |
|------|------|
| 읽기·쓰기 | `csrrw/s/c`와 즉치값 형태, `rs1 = x0`·즉치값 0이면 쓰지 않음 |
| 고정 필드 | `misa`, `mstatus.MPP = 11`, `mtvec` MODE 0, `mepc[1:0] = 0`, ID, `mip` 쓰기 무시 |
| 잘못된 CSR 접근 | 없는 CSR, 읽기 전용 CSR 쓰기 → 예외, `mtval` = 명령어. 읽기 전용 CSR을 읽기만 하면 정상 |
| 예외 9종 | `mcause`·`mtval`·`mepc`, 우선순위(잘못된 명령어 > 접근 오류, 가져오기 오류 > `ecall`), 대기 중에는 트랩 없음 |
| `mret` | `MIE ← MPIE`, `MPIE ← 1` (`MPIE = 0`에서도 확인) |
| 인터럽트 | `mie`·`MIE` 조건, 메모리 명령어·대기 중에는 받지 않음, 잘못된 명령어보다 먼저, 외부 > 타이머 |
| 카운터 | `mcycle` 매 클럭, `minstret` 완료 명령어만, CSR 쓰기가 증가보다 우선(반쪽 쓰기 포함) |

실행
```bash
python sim/run_sim.py csr_tb rtl/ch06_exception/csr.v sim/ch06_exception/csr_tb.v
```
```bash
bash sim/run_xrun.sh csr_tb rtl/ch06_exception/csr.v sim/ch06_exception/csr_tb.v
```

| 날짜 | 결과 | 비고 |
|------|------|------|
| 2026-11-14 | **PASS** (79 검사) | xsim. 처음 실행에서 11개 오류 → 모두 테스트벤치 기대값 문제(대기 사이클도 명령어로 실행됨)로 수정 |
| | 미검증 | 학교 서버 Xcelium |

버그 모델 (csr.v를 일부러 틀리게 고쳐 실행)
| 버그 | 검출 |
|------|------|
| 메모리 명령어에서도 인터럽트를 받음 | ✓ |
| `mret`이 `MPIE`를 1로 만들지 않음 | ✓ (`MPIE = 0` 시험을 추가한 뒤) |
| 읽기 전용 CSR 쓰기를 허용 | ✓ |
| `csrrs/c x0`도 씀 | ✓ |
| 접근 오류를 잘못된 명령어보다 우선 | ✓ |
| 카운터 쓰기보다 증가가 우선 | ✓ |
| `MPP`가 `11`이 아님 | ✓ |

## 2. MCU 전체 — riscv-tests 원래 환경 (`env/mcu_p`)
- 환경 [sim/riscv-tests-env/mcu_p/](../../sim/riscv-tests-env/mcu_p/riscv_test.h): riscv-tests `env/p/riscv_test.h`를 복사해 3곳만 바꿨다 (`encoding.h` 경로, 시작 시 `.data` 복사, `tohost`를 DMEM 끝 TOHOST 16바이트에 맞춰 8바이트 정렬). PASS/FAIL은 원래대로 `ecall` → 트랩 처리기 → `tohost` 쓰기라 **모든 테스트가 트랩을 거친다**. 시작할 때 없는 CSR(`satp`, `pmpcfg0`, `medeleg` 등)에 접근하는 부분은 `mtvec`을 다음 줄로 두고 시도하므로, M 모드만 있는 이 MCU에서는 잘못된 명령어 예외로 건너뛴다
- 링커 스크립트 [mcu_p/link.ld](../../sim/riscv-tests-env/mcu_p/link.ld): `.tohost`를 `TOHOST_BASE`에 (적재하지 않음)
- 빌드: `bash sim/riscv-tests-env/build_rv32ui.sh ~/riscv-tests mcu_p` → `sim/riscv-tests-hex/rv32ui_mcu_p/`(40), `rv32mi_mcu_p/`(15). `-march=rv32i_zicsr`
- 테스트벤치 [mcu_exc_tb.v](../../sim/ch06_exception/mcu_exc_tb.v): 판정은 TOHOST 감시기(4단계와 같음). 트랩은 이제 정상 동작이라 FAIL 조건이 아니다(시간 초과·`FINISH` 부분 쓰기만 FAIL). `+TRACE`로 모든 트랩 출력. `ext_irq = gpio_out[15]`
- 제외: `fence_i`(명령어를 메모리에 써서 실행 — IMEM이 데이터 쪽에서 읽기 전용), `ma_data`(정렬 안 된 접근을 하드웨어가 처리해야 함 — 이 설계는 예외, 결정 E), `pmpaddr`(PMP 필요 — 12장)
- `breakpoint`: 처음에는 `tselect`가 없어 잘못된 명령어로 FAIL → 디버그 트리거가 없음을 알리는 방식으로 `tselect`·`tdata1`·`tdata2`를 0으로 읽히게(쓰기 무시) 추가 → 테스트가 "트리거 없음"을 보고 건너뛰어 PASS

## 3. MCU 전체 — 6장 트랩 시험 (`sim/ch06_exception/tests/`)
riscv-tests에는 타이머·외부 인터럽트와 MCU 버스 오류 시험이 없어서 같은 환경(`mcu_p`)으로 직접 만들었다.

| 시험 | 내용 |
|------|------|
| [irq_timer.S](../../sim/ch06_exception/tests/irq_timer.S) | TIMER(CMP 40, AUTO) 인터럽트 8번을 받으면서 DMEM 쓰기·읽기와 APB 읽기를 반복. 두 카운터(`+1`, `+2`)의 관계로 명령어가 빠지거나 두 번 실행되지 않았는지 확인, APB 읽기 값 확인, 처리기에서 `mcause`·`mepc` 확인 |
| [irq_ext.S](../../sim/ch06_exception/tests/irq_ext.S) | GPIO 15번 핀으로 자기 자신에게 외부 인터럽트: 한 번만 받음, `MIE = 0`이면 `mip`에만 보이고 받지 않음, 외부·타이머가 함께 대기하면 외부 먼저 |
| [bus_fault.S](../../sim/ch06_exception/tests/bus_fault.S) | 없는 주소 load(5), IMEM store(7, IMEM 그대로), GPIO `sb`(7, 값 그대로), 빈 APB 슬롯 load(5, APB 대기 뒤), IMEM 밖으로 점프(1, `mepc = mtval =` 그 주소), 2바이트 정렬 `jalr`(0, `mepc` = 점프 명령어). 오류 난 load가 `rd`를 바꾸지 않는지도 확인 |

빌드: `bash sim/ch06_exception/tests/build.sh` → `sim/ch06_exception/tests/hex/` (커밋)

## 실행
- 이 PC (xsim)
```bash
python sim/ch06_exception/run_mcu_tests.py
```
- 학교 서버 (Xcelium) — 일괄
```bash
bash sim/ch06_exception/run_mcu_tests.sh
```
- 학교 서버 — 대화형 (테스트 하나를 SimVision으로)
```bash
bash sim/ch06_exception/run_mcu_tests.sh trap --gui irq_timer
```
- 첫 인자로 묶음 하나만: `rv32ui`, `rv32mi`, `trap`. 그 뒤에 테스트 이름

| 날짜 | 묶음 | 결과 | 비고 |
|------|------|------|------|
| 2026-11-14 | rv32ui (원래 환경) | **40 / 40 PASS** | xsim, 합 15,774사이클 (4단계 최소 환경 13,854 — 시작 시 CSR 설정·트랩, `ecall`로 끝내기) |
| 2026-11-14 | rv32mi | **15 / 15 PASS** | 처음 14/16: `breakpoint`(트리거 CSR 0 고정 추가로 해결), `pmpaddr`(PMP 없음 → 제외) |
| 2026-11-14 | trap (6장 시험) | **3 / 3 PASS** | irq_timer 501사이클·인터럽트 8, irq_ext 609·3, bus_fault 282·예외 11(환경 설정 5 포함) |
| | 전체 | 미검증 | 학교 서버 Xcelium |

버그 모델 (코어·CSR을 틀리게 고쳐 trap 시험 실행)
| 버그 | 검출 |
|------|------|
| 인터럽트의 `mepc` = PC + 4 (명령어 하나 건너뜀) | ✓ irq_timer (카운터 관계) |
| 트랩 난 명령어도 `rd`에 씀 | ✓ bus_fault, irq_timer |
| 타이머를 외부보다 먼저 | ✓ irq_ext |
| `mret`이 `MPIE`를 무시하고 `MIE = 1` | ✗ (처리기에 들어올 때 늘 `MIE = 1`이라 드러나지 않음) → csr_tb가 검출 |

회귀: 4단계 MCU riscv-tests 40/40, hello PASS. 빌드 스크립트를 고친 뒤 `min`·`mcu` 환경 hex를 다시 만들어도 바뀐 파일 없음
