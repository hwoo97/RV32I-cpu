# 3~6단계 · 장별 기록 (진행 순서: 개요서 3절)
교재 장마다 폴더(`03_chapters/chNN_<주제>/`)를 만들고 **notes.md**(내 말로 정리한 요약)와 **test.md**(시뮬·FPGA·합성 결과)를 둔다. 코드는 `rtl/chNN_<주제>/`, 테스트벤치는 `sim/chNN_<주제>/`에 둔다.

| 순서 | 폴더 | 교재 장 |
|:---:|------|---------|
| ① | `ch05_single_cycle` | 4·5 RV32I ISA·ALU, 단일 사이클 CPU |
| ② | `ch14a_mcu` | 14 일부 — MCU (버스·메모리·GPIO·Timer·UART·C 펌웨어) |
| ③ | `ch06_exception` | 6 예외·인터럽트 |
| ④ | `ch07_multi_cycle` | 7 멀티사이클 CPU |
| ⑤ | `ch08_pipeline` | 8 파이프라인 CPU |
| ⑥ | `ch09_fpu`, `ch10_pipeline_fpu` | 9·10 FPU, CPU + FPU |
| ⑦ | `ch11_memory`, `ch12_cache_tlb` | 11·12 캐시·Sv32 MMU |
| ⑧ | `ch13_multicore` | 13 멀티스레드·멀티코어 |
| ⑨ | `ch14b_io` | 14 나머지 — PS/2·VGA·I2C 등 |

> 교재 1~3장·15장은 건너뛴다 (`ch00_sample`은 환경 점검용).

## notes.md 양식
```markdown
# chNN <주제> 정리
## 핵심 개념 (내 말로, 교재 문장 복사 금지)
## 블록 다이어그램 (직접 그린 것)
## 교재(MIPS)와 RISC-V의 차이, 바꾼 설계와 이유
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
