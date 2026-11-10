`timescale 1ns/1ps
`include "rv32i_defs.vh"

// 즉치값 생성기 — 명령어에서 즉치값 비트를 모아 32비트로 부호 확장한다 (조합 회로)
// 부호 비트는 형식과 관계없이 항상 inst[31]이다. (decode.md 7절)
module imm_gen (
    input      [31:0] inst,
    input      [2:0]  imm_sel,   // `IMM_I / `IMM_S / `IMM_B / `IMM_U / `IMM_J
    output reg [31:0] imm
);
    always @(*) begin
        case (imm_sel)
            // I형: imm[11:0] = inst[31:20]                       (addi, lw, jalr …)
            `IMM_I: imm = {{20{inst[31]}}, inst[31:20]};
            // S형: imm[11:5] = inst[31:25], imm[4:0] = inst[11:7] (sw, sh, sb)
            `IMM_S: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            // B형: imm[12|10:5] = inst[31:25], imm[4:1|11] = inst[11:7], imm[0] = 0 (분기)
            `IMM_B: imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
            // U형: imm[31:12] = inst[31:12], 아래 12비트는 0  (lui, auipc)
            `IMM_U: imm = {inst[31:12], 12'b0};
            // J형: imm[20|10:1|11|19:12] = inst[31:12], imm[0] = 0 (jal)
            `IMM_J: imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
            // 정의되지 않은 값: 0 (기본값이 없으면 래치가 생긴다)
            default: imm = 32'd0;
        endcase
    end
endmodule
