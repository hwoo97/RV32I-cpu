# 2단계 · 환경 준비
주제마다 하위 폴더(`02_setup/<주제>/`)에 **절차 문서 + 점검 스크립트 + 결과표**를 둔다. 위험한 항목부터.

| 주제 폴더(예정) | 내용 |
|------|------|
| `xcelium/` | (Linux 서버) Xcelium 시뮬레이션, PASS/FAIL 판정 스크립트 |
| `vivado/` | (이 PC) Vivado 설치·버전, xsim 보조 시뮬레이션, FPGA 구현 |
| `board/` | Core-5300 사양·핀 배치, XDC 템플릿, LED 깜빡임 비트스트림 |
| `toolchain/` | (Linux 서버) RISC-V GCC·Spike·riscv-tests, hex 생성 / RARS |
| `testbench/` | 자가 검사 테스트벤치 규칙, 시뮬레이션 실행 스크립트 |
| `asic/` | (Linux 서버) Genus·Innovus·gpdk045, (교수님 서버) Conformal LEC |

## 점검 문서 양식 (`<주제>/README.md`)
```markdown
# <주제> 확인
> 목적: …

| 파일 | 역할 |

## 1. 준비·설치
## 2. 절차 (명령은 블록 하나에 하나)
## 3. 통과 기준
| # | 항목 | 통과 기준 |
## 4. 문제 해결
| 증상 | 확인·조치 |
## 5. 결과 기록
| 날짜 | 조건 | 항목 | 결과 | 비고 |
```
