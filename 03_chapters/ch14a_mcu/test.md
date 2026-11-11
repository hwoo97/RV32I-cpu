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
| 2026-11-12 | 30 % | **40 / 40 PASS** | | | | 학교 서버 Xcelium (`run_core_wait.sh 30`). SimVision 파형으로 대기 중 PC·요청 유지, 완료 사이클에만 레지스터 쓰기 확인 (사용자) |

버그 모델 (일부러 고장 낸 코어로 테스트벤치가 잡는지 확인, 대기 30 %)
| 버그 | 결과 | 잡은 방법 |
|------|------|-----------|
| 대기 중에도 레지스터 파일에 씀 | 1 FAIL (ld_st) | `lw x?, 0(x?)`처럼 rd = rs1인 load에서 대기 중 주소 레지스터가 바뀌어 "요청 변경" 검출 |
| 대기 중에도 PC가 넘어감 | 17 FAIL | 요청 변경 검출 |
| store일 때 대기하지 않음 (load만 대기) | 16 FAIL | tohost 쓰기가 사라져 타임아웃 |
- 레지스터 파일 버그는 rd = rs1인 load에서만 드러난다. rv32ui 안에서는 ld_st 하나뿐이라, MCU 단계 테스트에서 이 경우를 직접 넣은 시험을 추가할 예정

## 2. 주소 표 생성 — `tools/gen_memmap.py`
| 날짜 | 시험 | 결과 | 비고 |
|------|------|------|------|
| 2026-11-12 | 생성·`--check` | 통과 | 표 7개 영역 → `mcu_memmap.vh`·`memmap.h`·`memmap.ld`, 다시 실행하면 변화 없음 |
| 2026-11-12 | Verilog 매크로 (xsim) | PASS | 영역 첫·끝·끝+1 주소의 `_HIT`, APB 슬롯 비트, `_AW` — 14개 검사 |
| 2026-11-12 | C·어셈블리·링커 (WSL `riscv64-unknown-elf-gcc`) | 통과 | `memmap.h`를 .c와 .S에서 include, `INCLUDE memmap.ld`로 링크 → `.text` 0x0, `.data` 실행 주소 0x1000_0000·저장 주소 IMEM, `sp = 0x1000_4000` |
| 2026-11-12 | 표 오류 검출 | 8/8 검출 | 겹침, 정렬, 2의 거듭제곱 아님, APB 슬롯 중복, APB 창 밖, 이름 중복, 잘못된 종류 |
- 시험용 링크에서 `.data`의 저장 주소가 4바이트 정렬이 아니었다(0x27). 실제 `link.ld`를 만들 때 crt0가 워드 단위로 복사하도록 `ALIGN(4)`를 넣는다

## 3. 주소 디코더·APB 브리지 — `bus_mux.v`, `apb_bridge.v`
실행 방법
- 이 PC (xsim)
```bash
python sim/run_sim.py bus_tb rtl/ch14a_mcu/bus_mux.v rtl/ch14a_mcu/apb_bridge.v sim/ch14a_mcu/bus_tb.v
```
- 학교 서버 (Xcelium) — 일괄, 끝에 `--gui`를 붙이면 대화형
```bash
bash sim/run_xrun.sh bus_tb rtl/ch14a_mcu/bus_mux.v rtl/ch14a_mcu/apb_bridge.v sim/ch14a_mcu/bus_tb.v
```
- 슬레이브 대기 비율은 기본 30 % (`+WAITPCT=<n>`), 무작위 순서 `+SEED=<n>`

테스트벤치 [bus_tb.v](../../sim/ch14a_mcu/bus_tb.v)
- 모형 마스터: 코어처럼 `dmem_ready`가 1이 될 때까지 요청을 유지
- 모형 메모리: IMEM(데이터 쪽 읽기), DMEM(바이트 쓰기). 모형 APB 슬레이브: 슬롯 0·1·2·15 (레지스터 4 KB, 무작위 `PREADY` 대기, 오프셋 `0xFFC`에서 `PSLVERR`), 나머지 슬롯은 "슬레이브 없음"(`PREADY = 1`, `PSLVERR = 1`)
- 기준 모델이 읽기 값·오류·사이클 수(메모리 1사이클, APB 2사이클 이상)·APB 전송 횟수를 예측해 비교
- **APB 프로토콜 검사**(매 사이클): `PSEL` 하나만, `PENABLE`은 `PSEL`과 함께, SETUP 다음은 ACCESS, ACCESS는 SETUP이나 대기 중 ACCESS 다음에만, 전송 중 `PSEL`·`PADDR`·`PWRITE`·`PWDATA` 고정
- 정해진 시험 19개 + 가져오기 주소 검사 5개 + 무작위 접근 4,000개

| 날짜 | 슬레이브 대기 | 결과 | 비고 |
|------|-------------:|------|------|
| 2026-11-12 | 0 % | **PASS** | xsim, 4,019 접근, APB 전송 1,314 |
| 2026-11-12 | 30 % | **PASS** | xsim, 4,019 접근, APB 전송 1,377 |
| 2026-11-12 | 80 % | **PASS** | xsim, 4,019 접근, APB 전송 1,326 |
| | 30 % | 미검증 | 학교 서버 Xcelium |

버그 모델 (모두 검출)
| 버그 | 잡은 검사 |
|------|-----------|
| SETUP 단계 없이 바로 ACCESS | 프로토콜: ACCESS without SETUP |
| `PREADY`를 보지 않고 끝냄 | APB 전송 횟수, 전송 중 신호 변경 |
| 주변장치에 sb·sh 허용 | `data_err`, 사이클 수 |
| APB 접근인데 코어를 멈추지 않음 | APB 2사이클 미만, 전송 횟수 |
| IMEM 쓰기를 오류로 안 봄 | `data_err` |
| `PSLVERR` 무시 | `data_err` (오류 오프셋, 빈 슬롯) |
| 가져오기 주소 검사 없음 | `fetch_err` |
| DMEM이 아닌 주소에서도 DMEM에 씀 | 읽기 값 |
- 시험 중 고친 것: 처음에는 프로토콜 검사를 하강 에지에서 했는데, 모형 마스터도 하강 에지에서 요청을 바꿔 실행 순서에 따라 SETUP 사이클을 놓쳤다(테스트벤치의 경쟁 조건) → 검사를 상승 에지(끝난 사이클의 값)로 옮김
