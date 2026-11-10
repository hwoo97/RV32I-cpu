// RV32I 단일 사이클 CPU 공통 정의 (decode.md 기준)
// 여러 모듈이 같은 값을 쓰도록 이 파일 한 곳에서만 정의한다.
`ifndef RV32I_DEFS_VH
`define RV32I_DEFS_VH

// ── 즉치값 형식 (imm_sel) ── decode.md 7절
`define IMM_I  3'd0
`define IMM_S  3'd1
`define IMM_B  3'd2
`define IMM_U  3'd3
`define IMM_J  3'd4

// ── ALU 연산 (alu_op) ── decode.md 4절
`define ALU_ADD   4'd0
`define ALU_SUB   4'd1
`define ALU_SLL   4'd2
`define ALU_SLT   4'd3    // 부호 있는 비교, 결과 0/1
`define ALU_SLTU  4'd4    // 부호 없는 비교, 결과 0/1
`define ALU_XOR   4'd5
`define ALU_SRL   4'd6    // 논리 오른쪽 시프트 (0 채움)
`define ALU_SRA   4'd7    // 산술 오른쪽 시프트 (부호 비트 채움)
`define ALU_OR    4'd8
`define ALU_AND   4'd9

// ── ALU 입력 선택 (a_sel, b_sel) ── decode.md 2절
`define A_RS1  1'b0
`define A_PC   1'b1
`define B_RS2  1'b0
`define B_IMM  1'b1

// ── rd에 쓸 값 선택 (wb_sel) ── decode.md 2절
`define WB_ALU  2'd0
`define WB_MEM  2'd1
`define WB_PC4  2'd2
`define WB_IMM  2'd3

// ── opcode (inst[6:0]) ── decode.md 3절
`define OP_LUI     7'b0110111
`define OP_AUIPC   7'b0010111
`define OP_JAL     7'b1101111
`define OP_JALR    7'b1100111
`define OP_BRANCH  7'b1100011
`define OP_LOAD    7'b0000011
`define OP_STORE   7'b0100011
`define OP_IMM     7'b0010011
`define OP_REG     7'b0110011
`define OP_FENCE   7'b0001111
`define OP_SYSTEM  7'b1110011

`endif
