# riscv-tests 빌드 결과 (hex)

학교 서버에는 RISC-V 툴체인이 없어서, 이 PC(WSL `rv32i`)에서 빌드한 테스트 프로그램 이미지를 저장소에 함께 둔다.

| 파일 | 내용 |
|------|------|
| `rv32ui/<테스트>.hex` | RV32I 기본 명령어 테스트 40개, 워드 단위 hex (`$readmemh`용) |
| `RISCV_TESTS_COMMIT` | 빌드에 쓴 riscv-tests 커밋 |
| `LICENSE-riscv-tests` | riscv-tests 저작권·라이선스 고지 (BSD — 바이너리 배포 시 고지 필요) |

- 출처: [riscv-software-src/riscv-tests](https://github.com/riscv-software-src/riscv-tests)의 `isa/rv32ui/*.S`
- 빌드 환경은 이 프로젝트의 최소 테스트 환경(`sim/riscv-tests-env/`)이다. CSR 없이 시작하고 `tohost`(0x1000)로 판정한다.
- 제외한 테스트: `fence_i`(Zifencei 확장), `ma_data`(정렬 안 된 접근 — 트랩 구현 후)
- 다시 만들기 (WSL `rv32i`):
```bash
bash sim/riscv-tests-env/build_rv32ui.sh
```
