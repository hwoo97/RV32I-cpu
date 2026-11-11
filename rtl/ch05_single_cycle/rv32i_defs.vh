// Common definitions for the RV32I single-cycle CPU (per decode.md)
// Defined only here so every module uses the same values.
`ifndef RV32I_DEFS_VH
`define RV32I_DEFS_VH

// -- Immediate format (imm_sel) -- decode.md sec. 7
`define IMM_I  3'd0
`define IMM_S  3'd1
`define IMM_B  3'd2
`define IMM_U  3'd3
`define IMM_J  3'd4

// -- ALU operation (alu_op) -- decode.md sec. 4
`define ALU_ADD   4'd0
`define ALU_SUB   4'd1
`define ALU_SLL   4'd2
`define ALU_SLT   4'd3    // signed compare, result 0/1
`define ALU_SLTU  4'd4    // unsigned compare, result 0/1
`define ALU_XOR   4'd5
`define ALU_SRL   4'd6    // logical right shift (fill with 0)
`define ALU_SRA   4'd7    // arithmetic right shift (fill with sign bit)
`define ALU_OR    4'd8
`define ALU_AND   4'd9

// -- ALU input select (a_sel, b_sel) -- decode.md sec. 2
`define A_RS1  1'b0
`define A_PC   1'b1
`define B_RS2  1'b0
`define B_IMM  1'b1

// -- Value written to rd (wb_sel) -- decode.md sec. 2
`define WB_ALU  2'd0
`define WB_MEM  2'd1
`define WB_PC4  2'd2
`define WB_IMM  2'd3

// -- opcode (inst[6:0]) -- decode.md sec. 3
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
