`timescale 1ns/1ps

// 분기 비교기 — rs1_data와 rs2_data를 funct3가 정한 조건으로 비교한다 (조합 회로, decode.md 5절)
// br_taken은 "조건이 성립하는가"만 알려 준다. 실제로 분기할지는 최상위에서 branch & br_taken으로 정한다.
module branch_cmp (
    input  [31:0] rs1_data,
    input  [31:0] rs2_data,
    input  [2:0]  funct3,     // inst[14:12]
    output reg    br_taken
);
    wire eq  = (rs1_data == rs2_data);
    wire lt  = ($signed(rs1_data) < $signed(rs2_data));   // 부호 있는 비교 (blt, bge)
    wire ltu = (rs1_data < rs2_data);                     // 부호 없는 비교 (bltu, bgeu)

    always @(*) begin
        case (funct3)
            3'b000:  br_taken =  eq;    // beq
            3'b001:  br_taken = ~eq;    // bne
            3'b100:  br_taken =  lt;    // blt
            3'b101:  br_taken = ~lt;    // bge  (>= 는 < 의 반대)
            3'b110:  br_taken =  ltu;   // bltu
            3'b111:  br_taken = ~ltu;   // bgeu
            default: br_taken = 1'b0;   // 010·011은 정의 안 됨 (제어 유닛이 illegal로 처리)
        endcase
    end
endmodule
