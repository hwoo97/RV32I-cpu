# ch05 단일 사이클 CPU 테스트 기록

## 시뮬레이션 — 모듈 단위 (이 PC xsim)
| 날짜 | 모듈 | 테스트벤치 | 결과 | 비고 |
|------|------|------------|------|------|
| 2026-11-10 | `imm_gen` | `imm_gen_tb` (74벡터) | PASS | 버그 모델(B형 imm[11] 누락) FAIL 9 |
| 2026-11-10 | `alu` | `alu_tb` (1022벡터) | PASS | 버그 모델(SRA·SLT 부호) FAIL 79 |
| 2026-11-10 | `regfile` | `regfile_tb` (전체·x0·we·타이밍·무작위 2000) | PASS | 버그 모델(x0 쓰기 가능) FAIL 138 |
| 2026-11-10 | `control` | `control_tb` (RV32I 41 + 불법 19) | PASS | 버그 모델(addi→SUB) FAIL 1 |
| 2026-11-10 | `branch_cmp` | `branch_cmp_tb` (632벡터) | PASS | 버그 모델(bge 부호 없음) FAIL 37 |
| 2026-11-10 | `dmem` | `dmem_tb` (바이트 shadow, 무작위 4000) | PASS | 버그 모델(lb 0확장 FAIL 396, sh 위치 FAIL 1152) |

## 시뮬레이션 — CPU 전체 (riscv-tests rv32ui, 최소 테스트 환경)
실행 방법
- 테스트 hex 만들기 (WSL `rv32i`, 테스트를 바꿀 때만) → 결과는 `sim/riscv-tests-hex/rv32ui/`에 커밋
```bash
bash sim/riscv-tests-env/build_rv32ui.sh
```
- 이 PC (xsim)
```bash
python sim/run_riscv_tests.py
```
- 학교 서버 (Xcelium, `git pull` 후)
```bash
bash sim/run_riscv_tests.sh
```
- 제외: `fence_i`(Zifencei), `ma_data`(정렬 안 된 접근 — 6장)

| 날짜 | 설계 | 결과 | 비고 |
|------|------|------|------|
| 2026-11-10 | `rv32i_sc` | **40 / 40 PASS** | 사이클 수 35(simple) ~ 957(ld_st). 버그 모델(jal 복귀 주소 = pc) → jal·jalr FAIL |

| 테스트 | 사이클 | 테스트 | 사이클 | 테스트 | 사이클 | 테스트 | 사이클 |
|--------|------:|--------|------:|--------|------:|--------|------:|
| add | 459 | bltu | 310 | lw | 277 | sra | 506 |
| addi | 236 | bne | 285 | or | 482 | srai | 250 |
| and | 479 | jal | 49 | ori | 199 | srl | 500 |
| andi | 192 | jalr | 109 | sb | 448 | srli | 244 |
| auipc | 52 | lb | 247 | sh | 501 | st_ld | 477 |
| beq | 285 | lbu | 247 | simple | 35 | sub | 451 |
| bge | 303 | ld_st | 957 | sll | 487 | sw | 508 |
| bgeu | 328 | lh | 263 | slli | 235 | xor | 481 |
| blt | 285 | lhu | 272 | slt | 453 | xori | 201 |
| | | lui | 59 | slti | 231 | | |
| | | | | sltiu | 231 | | |
| | | | | sltu | 453 | | |

단일 사이클 CPU는 CPI = 1이므로 사이클 수 = 실행한 명령어 수 (시작 코드 32개 포함).

## 학교 서버 (Xcelium)
| 날짜 | 설계 | 결과 | 비고 |
|------|------|------|------|
| | `rv32i_sc` | 미검증 | `bash sim/run_riscv_tests.sh` 실행 결과를 여기에 기록 (판정 로직은 이 PC에서 가짜 xrun으로 확인) |

## 합성 결과
- 미실행 (gpdk045 경로 확인 후 Genus)

## 문제와 해결
- `run_riscv_tests.py`에서 xsim에 `-testplusarg HEX=…`를 넘기면 결과가 안 나옴 → Windows `.bat`가 인자 안의 `=`에서 인자를 나눔 → 인자를 따옴표로 감싸 문자열로 전달
