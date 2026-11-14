`timescale 1ns/1ps
`include "rv32i_defs.vh"

// ALU - 10 RV32I integer operations (combinational)
// Inputs A/B come from the datapath A/B muxes. Shift amount uses only the low 5 bits of B. (decode.md sec. 4)
module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  alu_op,    // `ALU_ADD ... `ALU_AND
    output reg [31:0] result
);
    wire [4:0] shamt = b[4:0];   // 32-bit data, so shift amount is 0..31

    always @(*) begin
        case (alu_op)
            `ALU_ADD:  result = a + b;
            `ALU_SUB:  result = a - b;
            `ALU_SLL:  result = a << shamt;
            `ALU_SLT:  result = {31'd0, $signed(a) < $signed(b)};   // compare as two's complement
            `ALU_SLTU: result = {31'd0, a < b};                     // compare as unsigned
            `ALU_XOR:  result = a ^ b;
            `ALU_SRL:  result = a >> shamt;
            `ALU_SRA:  result = $signed(a) >>> shamt;               // operand must be signed to fill with the sign bit
            `ALU_OR:   result = a | b;
            `ALU_AND:  result = a & b;
            default:   result = 32'd0;                               // avoid latch
        endcase
    end
endmodule
