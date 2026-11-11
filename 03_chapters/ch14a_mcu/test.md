# ch14a MCU 테스트 기록

## 1. 코어 대기(stall) — `rtl/ch14a_mcu/rv32i_core.v`
3단계 코어에 `dmem_ready` 입력을 더했다 ([design.md](design.md) 3절). load/store를 냈는데 `dmem_ready = 0`이면 PC와 레지스터 파일을 그대로 두어 같은 명령어를 다음 사이클에 다시 실행한다.

실행 방법
- 이 PC (xsim)
```bash
python sim/ch14a_mcu/run_core_wait.py 30
```
- 학교 서버 (Xcelium) — 일괄
```bash
bash sim/ch14a_mcu/run_core_wait.sh 30
```
- 학교 서버 — 대화형 (테스트 하나를 SimVision으로, 콘솔에서 `run 200ns`)
```bash
bash sim/ch14a_mcu/run_core_wait.sh 30 --gui lw
```
- 첫 인자 = 대기 비율 %(매 사이클 `dmem_ready = 0`일 확률, 기본 30). 다른 무작위 순서: csh에서 `env SEED=7 bash sim/ch14a_mcu/run_core_wait.sh 30`
- 테스트벤치 [core_wait_tb.v](../../sim/ch14a_mcu/core_wait_tb.v): 3단계 메모리 모델(8 KB)과 같은 riscv-tests hex 사용, DMEM 쓰기는 대기가 끝나는 클럭 에지에서만

테스트벤치가 확인하는 것
- riscv-tests 판정 (tohost, trap, 타임아웃)
- **대기 중 요청 고정**: 기다리는 동안 `dmem_re`·`dmem_addr`·`dmem_wstrb`·`dmem_wdata`가 바뀌면 FAIL
- 요청이 없을 때도 `dmem_ready`를 무작위로 0으로 만듦 → 코어가 무시해야 함
- 끝난 명령어 수(retired = 전체 사이클 − 대기 사이클)를 출력 → 3단계 사이클 수와 같아야 함

| 날짜 | 대기 비율 | 결과 | 전체 사이클 (40개 합) | 대기 사이클 | retired = 3단계 사이클 | 비고 |
|------|---------:|------|---------------------:|-----------:|:---------------------:|------|
| 2026-11-12 | 0 % | **40 / 40 PASS** | 13,067 | 0 | 40 / 40 같음 | xsim, SEED 1. 대기가 없으면 3단계와 완전히 같은 동작 |
| 2026-11-12 | 30 % | **40 / 40 PASS** | 13,460 | 393 | 40 / 40 같음 | 예: ld_st 1,160 사이클 = 957 + 대기 203 |
| 2026-11-12 | 70 % | **40 / 40 PASS** | 15,118 | 2,051 | 40 / 40 같음 | |
| | 30 % | 미검증 | | | | 학교 서버 Xcelium (`run_core_wait.sh`) — 이 PC에서는 가짜 xrun으로 명령 구성만 확인 |

버그 모델 (일부러 고장 낸 코어로 테스트벤치가 잡는지 확인, 대기 30 %)
| 버그 | 결과 | 잡은 방법 |
|------|------|-----------|
| 대기 중에도 레지스터 파일에 씀 | 1 FAIL (ld_st) | `lw x?, 0(x?)`처럼 rd = rs1인 load에서 대기 중 주소 레지스터가 바뀌어 "요청 변경" 검출 |
| 대기 중에도 PC가 넘어감 | 17 FAIL | 요청 변경 검출 |
| store일 때 대기하지 않음 (load만 대기) | 16 FAIL | tohost 쓰기가 사라져 타임아웃 |
- 레지스터 파일 버그는 rd = rs1인 load에서만 드러난다. rv32ui 안에서는 ld_st 하나뿐이라, MCU 단계 테스트에서 이 경우를 직접 넣은 시험을 추가할 예정
