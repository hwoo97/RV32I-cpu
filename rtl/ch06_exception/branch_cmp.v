`timescale 1ns/1ps

// Branch comparator - compares rs1_data and rs2_data by the condition in funct3 (combinational, decode.md sec. 5)
// br_taken only says whether the condition holds. Whether to branch is decided at the top as branch & br_taken.
module branch_cmp (
    input  [31:0] rs1_data,
    input  [31:0] rs2_data,
    input  [2:0]  funct3,     // inst[14:12]
    output reg    br_taken
);
    wire eq  = (rs1_data == rs2_data);
    wire lt  = ($signed(rs1_data) < $signed(rs2_data));   // signed compare (blt, bge)
    wire ltu = (rs1_data < rs2_data);                     // unsigned compare (bltu, bgeu)

    always @(*) begin
        case (funct3)
            3'b000:  br_taken =  eq;    // beq
            3'b001:  br_taken = ~eq;    // bne
            3'b100:  br_taken =  lt;    // blt
            3'b101:  br_taken = ~lt;    // bge  (>= is the inverse of <)
            3'b110:  br_taken =  ltu;   // bltu
            3'b111:  br_taken = ~ltu;   // bgeu
            default: br_taken = 1'b0;   // 010/011 undefined (control unit flags them illegal)
        endcase
    end
endmodule
