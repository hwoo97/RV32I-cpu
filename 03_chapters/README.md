# 3~6단계 · 장별 기록
교재 장마다 폴더(`03_chapters/chNN_<주제>/`)를 만들고 **notes.md**(내 말로 정리한 요약)와 **test.md**(시뮬·FPGA·합성 결과)를 둔다. 코드는 `rtl/chNN_<주제>/`, 테스트벤치는 `sim/chNN_<주제>/`에 둔다.

| 폴더 | 교재 장 |
|------|---------|
| `ch01_fundamentals` | 1 컴퓨터 기초·성능 평가 |
| `ch02_logic` | 2 논리 회로·Verilog |
| `ch03_arithmetic` | 3 컴퓨터 산술 |
| `ch04_isa_alu` | 4 ISA·ALU |
| `ch05_single_cycle` | 5 단일 사이클 CPU |
| `ch06_exception` | 6 예외·인터럽트 |
| `ch07_multi_cycle` | 7 멀티사이클 CPU |
| `ch08_pipeline` | 8 파이프라인 CPU |
| `ch09_fpu` | 9 FPU |
| `ch10_pipeline_fpu` | 10 파이프라인 CPU + FPU |
| `ch11_memory` | 11 메모리 계층·가상 메모리 |
| `ch12_cache_tlb` | 12 캐시·TLB CPU |
| `ch13_multicore` | 13 멀티스레드·멀티코어 |
| `ch14_io` | 14 I/O 컨트롤러 |
| `ch15_network` | 15 고성능 컴퓨터·연결망 |

## notes.md 양식
```markdown
# chNN <주제> 정리
## 핵심 개념 (내 말로, 교재 문장 복사 금지)
## 블록 다이어그램 (직접 그린 것)
## 교재(MIPS)와 RISC-V의 차이, 바꾼 설계와 이유
## 연습문제 풀이·확장
```

## test.md 양식
```markdown
# chNN <주제> 테스트 기록
## 시뮬레이션
| 날짜 | 모듈 | 테스트 | 결과(PASS/FAIL) | 비고 |
## FPGA
| 날짜 | 비트스트림 | 클럭 | 확인 방법(LED·ILA) | 결과 |
## 합성 결과
| 모듈 | LUT | FF | BRAM | DSP | Fmax | 비고 |
## 문제와 해결
- 증상 → 원인 → 조치
```
