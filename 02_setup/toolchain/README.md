# RISC-V 툴체인·riscv-tests 확인 (이 PC, WSL 전용 배포판)
> 목적: 이 PC의 WSL에 RISC-V 전용 Ubuntu를 따로 만들어 테스트 프로그램을 빌드하고 hex 파일을 만든다. 만든 hex는 Git으로 학교 서버(Xcelium)에 보낸다.

| 도구 | 역할 |
|------|------|
| WSL 배포판 `rv32i` (Ubuntu 24.04) | RISC-V 전용 Linux 환경 — 기존 ROS 2용 배포판(`Ubuntu`, `Ubuntu-22.04`)과 완전히 분리 |
| `gcc-riscv64-unknown-elf` | 어셈블리·C 컴파일, `objcopy`·`objdump` (`-march=rv32i -mabi=ilp32`로 32비트 코드 생성) |
| riscv-tests | 명령어별 공식 테스트 (rv32ui, rv32mi, rv32uf, rv32si, rv32ua, rv32um) |
| Spike | 공식 ISA 시뮬레이터 — 명령어별 실행 기록을 기준으로 내 CPU와 비교 |
| RARS (`rars.jar`, Windows) | 그래픽 어셈블러·단계 실행 — 4장 학습용 |

## 1. 전용 배포판 만들기 (사용자, PowerShell)
기존 배포판과 이름이 겹치지 않게 `rv32i`라는 이름으로 설치한다. 설치 중에 Linux 사용자 이름과 비밀번호를 직접 정한다.
```bash
wsl --install -d Ubuntu-24.04 --name rv32i
```
- `--name`이 안 되는 버전이면 `--name rv32i`를 빼고 설치한다 (`Ubuntu-24.04`라는 이름으로 생김, 기존 `Ubuntu`와 별개)
- 확인: `wsl -l -v`에 `rv32i`가 보이면 성공
- 들어가기:
```bash
wsl -d rv32i
```

## 2. 패키지 설치 (사용자, `rv32i` 안에서 — sudo 비밀번호 필요)
```bash
sudo apt update
```
```bash
sudo apt install -y gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf build-essential git autoconf device-tree-compiler
```

## 3. 확인 절차 (Claude가 진행 가능)
1. 컴파일러 확인
```bash
riscv64-unknown-elf-gcc --version
```
2. riscv-tests 내려받기·빌드 (32비트)
```bash
git clone --recursive https://github.com/riscv-software-src/riscv-tests.git ~/riscv-tests
```
```bash
cd ~/riscv-tests/isa && make XLEN=32 rv32ui
```
3. ELF → 워드 단위 hex 변환 (리셋 주소 0x80000000을 0번지로 옮김, `@` 주소는 워드 단위) → `$readmemh`로 읽히는지 확인 (이 PC의 xsim, 학교 서버의 Xcelium)
```bash
riscv64-unknown-elf-objcopy -O verilog --verilog-data-width=4 --change-addresses=-0x80000000 rv32ui-p-add add.hex
```
4. `riscv64-unknown-elf-objdump -d`로 디스어셈블해 명령어 인코딩 확인 (4장 학습 자료)
5. Spike 빌드 (`~/riscv-isa-sim`, 선택) → `rv32ui-p-add` 실행
6. 링크 주소·`tohost` 위치는 우리 CPU 메모리 맵에 맞춘 링커 스크립트로 바꿔 빌드 (4·5장에서 확정)

## 4. 통과 기준
| # | 항목 | 통과 기준 |
|---|------|-----------|
| 1 | 배포판 | `wsl -l -v`에 `rv32i`, 기존 배포판 그대로 |
| 2 | GCC | `--version` 출력, `-march=rv32i -mabi=ilp32`로 어셈블 성공 |
| 3 | riscv-tests | `rv32ui-p-add` ELF 생성 |
| 4 | hex | 변환한 hex를 시뮬레이터 메모리 모델이 읽음 |
| 5 | RARS | 실행·단계 실행 가능 |

## 5. 문제 해결
| 증상 | 확인·조치 |
|------|-----------|
| `rv32ui-v-*`(가상 메모리 테스트) 빌드 시 `string.h: No such file or directory` | C 라이브러리 헤더가 없음 → `sudo apt install picolibc-riscv64-unknown-elf` 등 설치 (12장 Sv32 전까지만 하면 됨). `-p` 테스트는 영향 없음 |
| 최신 riscv-tests가 `-march` 이름 오류(`_zicsr` 등) | 설치된 GCC 버전에 맞게 `RISCV_GCC_OPTS` 수정 또는 맞는 커밋으로 되돌림 |
| C 펌웨어 링크 시 32비트 `libgcc`를 못 찾음 | 배포판 패키지의 rv32 멀티립 유무 확인, 없으면 32비트용 툴체인 추가 (14장 전까지 확인) |
| 접두사가 문서마다 다름 (`riscv64-unknown-elf-`, `riscv-none-elf-`) | 설치한 접두사로 바꿔 사용, Makefile은 `RISCV_PREFIX` 변수로 지정 |

## 6. 결과 기록
| 날짜 | 조건 | 항목 | 결과 | 비고 |
|------|------|------|------|------|
| 2026-11-04 | 이 PC, OpenJDK 11 | Java (RARS용) | 통과 | |
| 2026-11-09 | 이 PC, WSL 3.0.3 | 기존 배포판 확인 | — | `Ubuntu`(24.04)·`Ubuntu-22.04` 모두 ROS 2 작업용 → 건드리지 않음 |
| 2026-11-09 | WSL `rv32i` (Ubuntu 24.04.5) | 1 배포판 | 통과 | `--name rv32i` 동작, 기존 배포판 그대로 |
| 2026-11-09 | 〃 | 2 GCC | 통과 | 13.2.0, 멀티립 rv32i·rv32im·rv32if·rv32ia 등 포함 |
| 2026-11-09 | 〃 | 3 riscv-tests | 통과 | 커밋 3df703c, `rv32ui-p-*` 42개 빌드. `-v` 테스트는 `string.h` 없음으로 실패(12장 전 해결) |
| 2026-11-09 | 〃 + 이 PC xsim | 4 hex | 통과 | `rv32ui-p-add` → 워드 hex, 첫 워드 `0500006f`(j reset_vector)·`tohost`(@400) 읽기 확인 |
| | | 5 RARS, Spike | 미검증 | 필요할 때 설치 (4장 RARS) |
