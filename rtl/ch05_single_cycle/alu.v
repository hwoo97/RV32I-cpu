`timescale 1ns/1ps
`include "rv32i_defs.vh"

// ALU — RV32I 정수 연산 10가지 (조합 회로)
// 입력 A·B는 데이터패스의 A/B MUX 출력. 시프트 양은 B의 아래 5비트만 쓴다. (decode.md 4절)
module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  alu_op,    // `ALU_ADD … `ALU_AND
    output reg [31:0] result
);
    wire [4:0] shamt = b[4:0];   // 32비트이므로 시프트 양은 0~31

    always @(*) begin
        case (alu_op)
            `ALU_ADD:  result = a + b;
            `ALU_SUB:  result = a - b;
            `ALU_SLL:  result = a << shamt;
            `ALU_SLT:  result = {31'd0, $signed(a) < $signed(b)};   // 2의 보수로 해석해 비교
            `ALU_SLTU: result = {31'd0, a < b};                     // 부호 없는 수로 비교
            `ALU_XOR:  result = a ^ b;
            `ALU_SRL:  result = a >> shamt;
            `ALU_SRA:  result = $signed(a) >>> shamt;               // 부호 있는 피연산자여야 부호 비트로 채움
            `ALU_OR:   result = a | b;
            `ALU_AND:  result = a & b;
            default:   result = 32'd0;                               // 래치 방지
        endcase
    end
endmodule
