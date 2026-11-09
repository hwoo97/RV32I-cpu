# ch05 단일 사이클 CPU — 디코드 표

> 제어 유닛이 명령어의 `opcode`·`funct3`·`funct7`을 보고 만들어야 하는 신호를 정리한 설계 기준표. RTL은 이 표대로 직접 입력한다.
> 기준: RISC-V Unprivileged ISA 명세 "RV32I Base Integer Instruction Set"과 "Instruction Set Listings" 표.

## 1. 데이터패스 가정 (단일 사이클)
```
PC ─► 명령어 메모리 ─► inst ─┬─► 레지스터 파일(rs1, rs2 읽기)
                              ├─► 즉치값 생성기 (imm_sel)
                              └─► 제어 유닛 ─► 아래 신호들
ALU 입력 A = rs1 또는 PC   (a_sel)
ALU 입력 B = rs2 또는 imm  (b_sel)
분기 비교기 = rs1 vs rs2   (funct3로 비교 종류 결정, ALU와 별도)
쓰기 값    = ALU 결과 / 메모리 읽기 값 / PC+4 / imm  (wb_sel)
다음 PC    = PC+4 / PC+imm(분기 성립·jal) / (rs1+imm) & ~1 (jalr)
```
- 분기 비교기를 ALU와 따로 두는 이유: 같은 사이클에 ALU는 다른 일을 해도 되고(분기 대상 주소는 별도 덧셈기), 제어가 단순해진다.
- `lui`는 ALU를 거치지 않고 `wb_sel = IMM`으로 바로 쓴다 (다른 방법: A=0, B=imm, ADD).

## 2. 제어 신호
| 신호 | 폭 | 값 | 뜻 |
|------|:--:|----|----|
| `reg_we` | 1 | 0/1 | `rd`에 결과를 쓸지 (`rd = x0`이면 레지스터 파일이 무시) |
| `imm_sel` | 3 | I, S, B, U, J | 즉치값 생성 형식 |
| `a_sel` | 1 | RS1 / PC | ALU 입력 A |
| `b_sel` | 1 | RS2 / IMM | ALU 입력 B |
| `alu_op` | 4 | ADD SUB SLL SLT SLTU XOR SRL SRA OR AND | ALU 연산 (3절) |
| `mem_re` | 1 | 0/1 | 데이터 메모리 읽기 (load) |
| `mem_we` | 1 | 0/1 | 데이터 메모리 쓰기 (store) |
| `mem_size` | 3 | = `funct3` | 바이트/하프워드/워드, 부호 없는 load 여부 (4절) |
| `wb_sel` | 2 | ALU / MEM / PC4 / IMM | `rd`에 쓸 값 |
| `branch` | 1 | 0/1 | 조건 분기 명령어 (`funct3`로 비교 종류) |
| `jal` | 1 | 0/1 | 다음 PC = PC + immJ |
| `jalr` | 1 | 0/1 | 다음 PC = (rs1 + immI) & ~1 |
| `illegal` | 1 | 0/1 | 정의되지 않은 명령어 (3단계에서는 시뮬레이션 정지·FAIL, 6장에서 예외로) |

## 3. opcode별 신호
| 명령어 군 | opcode | 형식 | reg_we | imm_sel | a_sel | b_sel | alu_op | mem_re | mem_we | wb_sel | branch | jal | jalr |
|-----------|--------|:---:|:---:|:---:|:---:|:---:|------|:---:|:---:|:---:|:---:|:---:|:---:|
| OP (`add` 등 10개) | `0110011` | R | 1 | — | RS1 | RS2 | funct3·funct7 | 0 | 0 | ALU | 0 | 0 | 0 |
| OP-IMM (`addi` 등 9개) | `0010011` | I | 1 | I | RS1 | IMM | funct3 (+inst[30]은 `srai`만) | 0 | 0 | ALU | 0 | 0 | 0 |
| LOAD (`lw` 등 5개) | `0000011` | I | 1 | I | RS1 | IMM | ADD (주소) | 1 | 0 | MEM | 0 | 0 | 0 |
| STORE (`sw` 등 3개) | `0100011` | S | 0 | S | RS1 | IMM | ADD (주소) | 0 | 1 | — | 0 | 0 | 0 |
| BRANCH (6개) | `1100011` | B | 0 | B | — | — | — (비교기 사용) | 0 | 0 | — | 1 | 0 | 0 |
| LUI | `0110111` | U | 1 | U | — | — | — | 0 | 0 | IMM | 0 | 0 | 0 |
| AUIPC | `0010111` | U | 1 | U | PC | IMM | ADD | 0 | 0 | ALU | 0 | 0 | 0 |
| JAL | `1101111` | J | 1 | J | — | — | — | 0 | 0 | PC4 | 0 | 1 | 0 |
| JALR | `1100111` | I | 1 | I | RS1 | IMM | ADD (대상 주소) | 0 | 0 | PC4 | 0 | 0 | 1 |
| FENCE | `0001111` | I | 0 | — | — | — | — | 0 | 0 | — | 0 | 0 | 0 |
| SYSTEM (`ecall` `ebreak`) | `1110011` | I | 0 | — | — | — | — | 0 | 0 | — | 0 | 0 | 0 |
| 그 밖의 opcode | | | 0 | — | — | — | — | 0 | 0 | — | 0 | 0 | 0 |

- `—`는 아무 값이어도 결과에 영향이 없는 자리 (RTL에서는 기본값 하나로 정해 둔다).
- **FENCE**: 단일 사이클·캐시 없는 CPU에서는 메모리 순서가 이미 지켜지므로 아무 일도 하지 않음(NOP).
- **SYSTEM**: 3단계에서는 `illegal = 1`과 같은 취급(시뮬레이션 정지). 6장에서 트랩으로 구현.
- **그 밖의 opcode**: `illegal = 1`.

## 4. ALU 연산 결정 (`alu_op`)
| funct3 | OP (R형) | OP-IMM (I형) | 주의 |
|:---:|------|------|------|
| `000` | inst[30]=0 → ADD, 1 → SUB | ADDI → **항상 ADD** | `addi`의 inst[30]은 즉치값 비트라 SUB로 보면 안 됨 (흔한 버그) |
| `001` | SLL | SLLI | `slli`는 inst[31:25]=0000000이어야 함 |
| `010` | SLT | SLTI | 부호 있는 비교, 결과 0/1 |
| `011` | SLTU | SLTIU | 부호 없는 비교. `sltiu`의 즉치값도 **부호 확장한 뒤** 부호 없이 비교 |
| `100` | XOR | XORI | |
| `101` | inst[30]=0 → SRL, 1 → SRA | inst[30]=0 → SRLI, 1 → SRAI | 시프트 양은 rs2[4:0] 또는 imm[4:0] |
| `110` | OR | ORI | |
| `111` | AND | ANDI | |

## 5. 분기 비교 (`branch = 1`)
| funct3 | 명령어 | 성립 조건 |
|:---:|------|------|
| `000` | beq | rs1 == rs2 |
| `001` | bne | rs1 != rs2 |
| `100` | blt | rs1 < rs2 (부호 있음) |
| `101` | bge | rs1 >= rs2 (부호 있음) |
| `110` | bltu | rs1 < rs2 (부호 없음) |
| `111` | bgeu | rs1 >= rs2 (부호 없음) |
| `010`, `011` | — | 정의 안 됨 → illegal |

## 6. load/store 크기 (`mem_size = funct3`)
| funct3 | load | store | 처리 |
|:---:|------|------|------|
| `000` | lb | sb | 바이트. load는 부호 확장 |
| `001` | lh | sh | 하프워드. load는 부호 확장 |
| `010` | lw | sw | 워드 |
| `100` | lbu | — | 바이트, 0 확장 |
| `101` | lhu | — | 하프워드, 0 확장 |
- 메모리는 워드(32비트) 단위로 두고, 주소 하위 2비트로 바이트 위치를 고른다. store는 **바이트 쓰기 신호(`wstrb[3:0]`)**로 해당 바이트만 쓴다.
- 정렬 안 된 접근(예: 주소가 4의 배수가 아닌 `lw`)은 3단계에서는 시뮬레이션 정지·FAIL, 6장에서 예외로.

## 7. 즉치값 생성기 (`imm_sel`)
| 형식 | 만드는 값 (32비트, 부호 비트 = inst[31]) |
|:---:|------|
| I | { 20 × inst[31], inst[31:20] } |
| S | { 20 × inst[31], inst[31:25], inst[11:7] } |
| B | { 19 × inst[31], inst[31], inst[7], inst[30:25], inst[11:8], 1'b0 } |
| U | { inst[31:12], 12'b0 } |
| J | { 11 × inst[31], inst[31], inst[19:12], inst[20], inst[30:21], 1'b0 } |

손 디코드 확인값 (riscv-tests 실제 명령어): `sw` `fc3f2223` → S = −60, `beq` `03ff0863` → B = +48, `jal` `0500006f` → J = +0x50, `lui` `800002b7` → U = 0x80000000.

## 8. 검증 방법 (riscv-tests 실행 환경)
riscv-tests의 기본 시작 코드(`env/p`)는 `csrr`·`csrw`(CSR 명령어), `mret`, `ecall`을 쓴다. CSR이 없는 3단계 CPU로는 시작 코드부터 실행할 수 없다.
- **3단계**: CSR을 쓰지 않는 **최소 테스트 환경**(`riscv_test.h`)을 직접 만든다.
  - 시작 코드는 바로 테스트로 들어간다.
  - PASS·FAIL은 `tohost` 주소에 결과를 쓰고 멈춘다 (PASS = 1, FAIL = (실패한 테스트 번호 << 1) | 1).
  - 테스트벤치가 `tohost` 쓰기를 감시해 판정한다.
- **제외**: `rv32ui-p-fence_i`(Zifencei 확장), `rv32ui-p-ma_data`(정렬 안 된 접근 — 6장에서 트랩과 함께)
- **6장 이후**: CSR과 트랩을 구현하면 원래 시작 코드(`env/p`)로 다시 돌려 확인한다.
