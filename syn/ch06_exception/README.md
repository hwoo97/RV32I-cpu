# 6장 MCU 합성 (Genus, gpdk045)

4단계 [syn/ch14a_mcu](../ch14a_mcu/README.md)와 같은 구조·같은 시간 모델로 6장 MCU(트랩·인터럽트 추가)를 합성해 비교한다.

| 파일 | 역할 |
|------|------|
| [run_syn.sh](run_syn.sh) | 실행 스크립트. 인자 = 목표 주기(기본 **8.5 ns** = 4단계 MCU 목표), 합성은 그 80 % |
| [genus.tcl](genus.tcl) | STEP 0~8 (4단계와 같음). RTL에 `csr.v` 추가, 폴더 `rtl/ch06_exception` |
| [cons/rv32i_mcu.sdc](cons/rv32i_mcu.sdc) | 4단계 SDC 복사 + `ext_irq`(비동기 입력, false path), `irq_taken`(관찰 출력) |
| [path_classes.tcl](path_classes.tcl) | 경로 종류별 최악 slack (4단계와 같은 7종류) |
| [clean.tcl](clean.tcl) | `./clean.tcl` — 이 폴더의 `runs/` 정리 |

## 1. 합성 대상
- `rv32i_mcu` 한 번에(top-down), 계층 유지 → 모듈별 면적
- 4단계와 달라진 것: `u_core` 안에 **`u_csr`**(CSR 파일·트랩 판단, 64비트 카운터 2개), 코어의 트랩 PC 선택, MCU의 리셋 동기화기·`ext_irq` 동기화기
- 시간 모델은 4단계와 같다: `T_ADDR` 0.5, `T_MEM` 1.0, `T_WB` 1.2, `T_WSU` 0.3 ns ([ch05 README 2-1절](../ch05_single_cycle/README.md))

## 2. 실행 (학교 서버)
```bash
bash syn/ch06_exception/run_syn.sh
```
- 대화형: `bash syn/ch06_exception/run_syn.sh -i` 후 `step 0` … `step 8`
- 끝나면 모듈별 면적, 최악 slack, 경로 종류별 slack, 위반 줄 수를 출력

## 3. 예상
- 순차 셀: 4단계 + CSR(카운터 128, `mtvec`·`mepc`·`mscratch`·`mtval` 등 약 130, 상태 비트) + 동기화기 4 → 약 +260개
- 임계 경로 후보: 트랩 판단(`mcause` 우선순위·접근 오류 → PC 선택)이 다음 PC 경로에 더해짐. 접근 오류(`data_err`)는 메모리 응답 쪽에서 오므로 **메모리 뒤 구간**(`T_WB`)에서 PC 선택까지 가는 경로가 새로 생긴다

## 4. 결과
원본 리포트는 공개하지 않고 직접 정리한 값만 적는다. 조건: gpdk045 `slow_vdd1v0` (0.9 V / 125 °C), LEF·QRC, effort high.

| 날짜 | 목표 주기 | 합성 주기 | 셀 면적 (µm²) | 셀+배선 면적 (µm²) | 셀 수 | WNS (ns) | 위반 | 비고 |
|------|----------:|----------:|--------------:|-------------------:|------:|---------:|:----:|------|
| | 8.5 ns | 6.8 ns | (미실행) | | | | | |

4단계 MCU와 비교 (목표 8.5 ns, 셀 면적 µm²)

| 모듈 | 4단계 | 6장 | 변화 |
|------|------:|------:|------|
| 코어 `u_core` (6장은 `u_csr` 포함) | 20,491.3 | | |
| └ `u_csr` | — | | |
| 버스·주변장치 | 3,479.4 | | |
| **합계** | **23,973.5** | | |
