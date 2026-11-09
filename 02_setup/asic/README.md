# ASIC 흐름 확인 (Genus · Innovus · Conformal LEC, gpdk045)
> 목적: Linux 서버의 Genus·Innovus와 gpdk045로 샘플 모듈을 합성·배치배선하고, 교수님 서버의 Conformal LEC로 등가성 검사를 한 번 해 본다.

| 파일 | 역할 |
|------|------|
| `syn/common/` (예정) | gpdk045 라이브러리 경로(환경 변수), 공통 Genus 스크립트 |
| `syn/ch00_sample/` (예정) | 샘플 카운터 합성 스크립트·SDC |
| `pnr/ch00_sample/` (예정) | 샘플 Innovus 스크립트 |
| `ec/ch00_sample/` (예정) | LEC 실행 파일 목록·do 파일 (Genus `write_do_lec`로 생성) |

## 0. 공개 저장소 규칙 (GitHub `hwoo97/RV32I-cpu`는 공개)
gpdk045와 Cadence 툴은 라이선스 대상이라 **원본 파일과 원본 리포트는 올리지 않는다.**

| 올려도 됨 | 올리면 안 됨 |
|-----------|--------------|
| 내가 쓴 RTL·테스트벤치·Tcl 스크립트·SDC | PDK 파일: `.lib` `.lef` `.tf` `.qrc` `.captbl` `.cdl` 등 |
| 라이브러리 경로를 **환경 변수**로 뺀 스크립트 (`$GPDK045_DIR` 등) | PDK·툴 **설치 경로**가 그대로 적힌 스크립트 |
| 직접 정리한 결과 요약 표 (면적·WNS·셀 수·Fmax) | 툴 원본 리포트 `.rpt`, 로그 |
| 내 설계 레이아웃의 개략 캡처 이미지 | 넷리스트 `.vg`·`_netlist.v`, `.def` `.gds` `.spef` `.sdf`, Innovus 데이터베이스 |
| PDK·툴 **이름과 버전** (예: gpdk045, Genus 22.17) | 툴이 만든 파일의 저작권 머리말이 들어간 파일 |

- 올리기 전에 `python tools/check_public.py`로 점검 (확장자·설치 경로·라이브러리 내용·저작권 머리말·개인/서버 정보·5 MB 초과)
- `.gitignore`에 PDK·툴 원본 확장자가 등록되어 있어 실수로 `git add` 되지 않는다

## 1. 확인할 것 (사용자)
| 항목 | 값 |
|------|----|
| 작업 서버 | 학교 서버, CentOS 7, 로그인 셸 **csh**, MobaXterm(SSH)으로 접속, 로그인 시 Cadence 환경 자동 설정 |
| 합성 | Genus 22.17-s071_1 |
| PnR | Innovus 22.17-s086_1 |
| 시뮬레이터 | Xcelium 22.03-s012 |
| 등가성 검사 | Conformal LEC — **교수님 서버** (버전: , 파일 옮기는 방법: ) |
| gpdk045 설치 경로 | |
| 표준 셀 `.lib` 코너 (slow/typical/fast) | |
| LEF·QRC 등 PnR 파일 위치 | |
| SRAM 매크로 유무 | (gpdk045는 보통 없음) |
| 결과 공개 규칙 | 공개 저장소 — 아래 0절 참고 |

## 2. 절차 (확인 후)
1. 샘플 카운터를 Genus로 합성 — typical 코너, 목표 클럭 100 MHz
2. 면적(`report_area`)·타이밍(`report_timing`)·셀 수 확인
3. Genus에서 넷리스트와 LEC용 do 파일 생성 (`write_hdl`, `write_do_lec`)
4. Innovus로 샘플 배치배선 (플로어플랜 → 배치 → CTS → 배선 → 타이밍)
5. RTL·넷리스트·do 파일·라이브러리 경로 목록을 교수님 서버로 옮겨 Conformal LEC 실행 → 등가 확인
6. 스크립트는 라이브러리 경로를 환경 변수로 빼서 저장소에 저장 (PDK 파일 자체는 넣지 않음)

## 3. 통과 기준
| # | 항목 | 통과 기준 |
|---|------|-----------|
| 1 | Genus 샘플 합성 | 면적·타이밍 리포트 생성, WNS ≥ 0 |
| 2 | Innovus 샘플 PnR | 배선 완료, 타이밍 위반 0, DRC 0 |
| 3 | LEC | RTL ↔ 합성 넷리스트 비등가 점 0 |
| 4 | 파일 이동 | 교수님 서버로 옮길 파일 목록이 `ec/`에 정리됨 |

## 4. 문제 해결
| 증상 | 확인·조치 |
|------|-----------|
| `Ambiguous output redirect.` | 로그인 셸이 csh라서 `2>/dev/null` 문법이 안 됨 → csh에서는 `\|&`(표준 오류까지 파이프) 또는 `>&` 사용. 스크립트는 첫 줄을 `#!/bin/bash`로 써서 bash로 실행 |

## 5. 결과 기록
| 날짜 | 조건 | 항목 | 결과 | 비고 |
|------|------|------|------|------|
| 2026-11-09 | 학교 서버 | 툴 버전 확인 | 통과 | Xcelium 22.03, Genus 22.17, Innovus 22.17 |
| 2026-11-09 | 학교 서버·교수님 서버 | 1~3 샘플 실행 | 생략 | 사용자가 이전 학교 프로젝트에서 Genus·Innovus·Conformal LEC 정상 동작을 이미 확인함. 첫 실제 합성(단일 사이클 CPU)에서 gpdk045 경로와 스크립트를 함께 만든다 |
| | | 4 LEC 파일 목록 | 미작성 | 첫 LEC 때(대표 설계) 작성 |
