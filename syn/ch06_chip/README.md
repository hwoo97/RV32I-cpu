# 6장 MCU 칩 합성 (IO 패드 포함, Genus, gpdk045)

칩 최상위 `rv32i_chip`(= `rv32i_mcu` + giolib045 IO 패드 197개)을 합성해 PnR([pnr/ch06_chip](../../pnr/ch06_chip/README.md))에 넘길 넷리스트를 만든다. 설계: [03_chapters/ch06_exception/chip.md](../../03_chapters/ch06_exception/chip.md)

| 파일 | 역할 |
|------|------|
| [run_syn.sh](run_syn.sh) | 실행 스크립트 (일괄, `-i`, `--gui`). 인자 = 목표 주기(기본 **12 ns**), 합성은 그 80 % |
| [genus.tcl](genus.tcl) | STEP 0~8 (코어 합성과 같은 흐름). `USE_PADS 1`로 패드 라이브러리·LEF도 읽고, 패드 인스턴스는 `set_dont_touch` |
| [cons/rv32i_chip.sdc](cons/rv32i_chip.sdc) | **칩 핀 기준** 제약. 메모리 시간 모델은 코어와 같고(`T_MEM` 1.0), 패드 몫을 더한 `T_ADDR_PIN` 2.5·`T_WB_PIN` 2.2 ns (패드 지연은 툴이 라이브러리로 계산) |
| [path_classes.tcl](path_classes.tcl) | 경로 종류별 최악 slack (칩 핀 이름) |

## 실행 (학교 서버)
```bash
bash syn/ch06_chip/run_syn.sh
```
- 목표 주기 바꾸기: `bash syn/ch06_chip/run_syn.sh 14`. GUI로 보기: `--gui`
- 결과 넷리스트 `runs/t<목표>ns/mapped/rv32i_chip_syn_final.v` → PnR 입력
- 패드 몫(`T_ADDR_PIN`, `T_WB_PIN`)은 처음 추정값이다. 결과의 경로 종류별 slack과 타이밍 리포트의 패드 지연을 보고 고친다 (csh: `env T_WB_PIN=2.5 bash ...`)

## 왜 12 ns부터인가
코어만 합성할 때(8.5 ns)는 메모리가 코어 바로 옆에 있다고 봤다. 칩에서는 메모리가 칩 밖이라 한 사이클에 패드를 네 번 지난다(주소 출력 → 명령어 입력 → 데이터 주소 출력 → 데이터 입력). 출력 패드 하나가 약 1.4 ns(모델 값, 부하 없이)라 코어의 고정 몫 3.7 ns가 칩 핀 기준 약 6.7 ns로 늘어난다 → 코어 가운데 구간(합성 기준 약 3.1 ns)과 더하면 합성 주기 약 9.8 ns, 80 % 규칙으로 목표 약 12 ns

## 결과
원본 리포트는 공개하지 않고 직접 정리한 값만 적는다.

| 날짜 | 목표 주기 | 합성 주기 | 셀 면적 (µm², 패드 포함) | 코어 `u_mcu` 면적 | WNS (ns) | 위반 | 비고 |
|------|----------:|----------:|------:|------:|------:|:---:|------|
| | 12 ns | 9.6 ns | (미실행) | | | | |
