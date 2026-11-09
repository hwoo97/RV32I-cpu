# Xcelium 확인 (학교 서버)
> 목적: 주 시뮬레이터 Xcelium으로 자가 검사 테스트벤치를 실행하고 PASS/FAIL을 판정한다.

| 파일 | 역할 |
|------|------|
| [`sim/run_xrun.sh`](../../sim/run_xrun.sh) | `xrun` 실행 + 로그에서 PASS/FAIL 판정, 종료 코드 0/1 (`--gui`면 SimVision) |
| [`rtl/ch00_sample/cnt.v`](../../rtl/ch00_sample/cnt.v) | 점검용 4비트 카운터 (enable, 비동기 리셋) |
| [`sim/ch00_sample/cnt_tb.v`](../../sim/ch00_sample/cnt_tb.v) | 자가 검사 테스트벤치 — 리셋, 10회 증가, enable=0 정지, 15→0 넘김 확인 |
| [`sim/run_sim.py`](../../sim/run_sim.py) | 이 PC의 xsim으로 빠르게 확인할 때 쓰는 보조 스크립트 |

## 1. 준비
- 학교 서버: 로그인 시 환경 자동 설정, Xcelium 22.03-s012
- 작업 폴더: 저장소를 clone한 폴더 (PC에서 push한 뒤 서버에서 `git pull`)
- 로그인 셸이 **csh**라도 `bash sim/run_xrun.sh ...`로 실행하면 bash로 돈다

## 2. 절차 (학교 서버, 저장소 폴더에서)
1. 최신 내용 받기
```bash
git pull
```
2. 샘플 실행 → `PASS`와 `통과: cnt_tb`가 나와야 함
```bash
bash sim/run_xrun.sh cnt_tb rtl/ch00_sample/cnt.v sim/ch00_sample/cnt_tb.v
```
3. 종료 코드 확인 (csh에서는 `$status`) → `0`
```bash
echo $status
```
4. FAIL 판정 확인: `sim/ch00_sample/cnt_tb.v`의 `check(4'd10)` 하나를 `check(4'd11)`로 잠깐 바꿔 다시 실행 → `FAIL: q = 10 (expected 11)`과 종료 코드 `1` 확인 후 되돌리기
```bash
git checkout sim/ch00_sample/cnt_tb.v
```
5. 파형 확인 (MobaXterm은 X11 창 표시를 지원)
```bash
bash sim/run_xrun.sh cnt_tb rtl/ch00_sample/cnt.v sim/ch00_sample/cnt_tb.v --gui
```

## 3. 통과 기준
| # | 항목 | 통과 기준 |
|---|------|-----------|
| 1 | 환경 | `xrun -version` 출력 |
| 2 | 시뮬레이션 | 샘플 테스트벤치 PASS, 틀린 기댓값 FAIL |
| 3 | 판정 스크립트 | PASS면 종료 코드 0, FAIL·Xcelium 오류(`*E`)·PASS 없음이면 1 |
| 4 | 파형 | SimVision으로 `q`가 0→10, 정지, 15→0 되는 모습 확인 |

## 4. 문제 해결
| 증상 | 확인·조치 |
|------|-----------|
| `Permission denied` (`./sim/run_xrun.sh`로 실행 시) | `bash sim/run_xrun.sh ...`로 실행 |
| `$'\r': command not found` | 스크립트 줄바꿈이 CRLF로 바뀜 → 저장소에는 LF로 저장되므로 `git checkout sim/run_xrun.sh`로 다시 받기 |
| `--gui`에서 창이 안 뜸 | MobaXterm X11 서버가 켜져 있는지 확인 (오른쪽 위 X server 아이콘) |

## 5. 결과 기록
| 날짜 | 조건 | 항목 | 결과 | 비고 |
|------|------|------|------|------|
| 2026-11-09 | 학교 서버 | 1 환경 | 통과 | `xrun -version` 22.03-s012 |
| 2026-11-09 | 이 PC xsim | 샘플 테스트벤치 | 통과 | 같은 파일로 xsim PASS |
| 2026-11-09 | 이 PC Git Bash, 가짜 `xrun` | 3 판정 로직 | 통과 | PASS→0, FAIL→1, `*E` 오류→1, PASS 없음→1 |
| | 학교 서버 | 2·4, 실제 Xcelium으로 3 | 미검증 | |
