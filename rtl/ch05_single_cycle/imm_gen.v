`timescale 1ns/1ps
`include "rv32i_defs.vh"

// Immediate generator - gathers immediate bits from the instruction and sign-extends to 32 bits (combinational)
// The sign bit is always inst[31] regardless of format. (decode.md sec. 7)
module imm_gen (
    input      [31:0] inst,
    input      [2:0]  imm_sel,   // `IMM_I / `IMM_S / `IMM_B / `IMM_U / `IMM_J
    output reg [31:0] imm
);
    always @(*) begin
        case (imm_sel)
            // I-type: imm[11:0] = inst[31:20]                       (addi, lw, jalr ...)
            `IMM_I: imm = {{20{inst[31]}}, inst[31:20]};
            // S-type: imm[11:5] = inst[31:25], imm[4:0] = inst[11:7] (sw, sh, sb)
            `IMM_S: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            // B-type: imm[12|10:5] = inst[31:25], imm[4:1|11] = inst[11:7], imm[0] = 0 (branches)
            `IMM_B: imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
            // U-type: imm[31:12] = inst[31:12], low 12 bits are 0  (lui, auipc)
            `IMM_U: imm = {inst[31:12], 12'b0};
            // J-type: imm[20|10:1|11|19:12] = inst[31:12], imm[0] = 0 (jal)
            `IMM_J: imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
            // Undefined selector: 0 (without a default a latch would be inferred)
            default: imm = 32'd0;
        endcase
    end
endmodule
