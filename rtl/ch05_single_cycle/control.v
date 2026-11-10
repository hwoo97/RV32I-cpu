`timescale 1ns/1ps
`include "rv32i_defs.vh"

// 제어 유닛 — 명령어를 해독해 데이터패스 제어 신호를 만든다 (조합 회로)
// decode.md 3절(opcode별 신호)·4절(ALU 연산)·5절(분기)·6절(load/store) 표를 그대로 옮긴 것.
// 3단계(단일 사이클 CPU)에서는 SYSTEM(ecall·ebreak·CSR)과 정의되지 않은 명령어를 모두 illegal로 처리한다.
module control (
    input      [31:0] inst,
    output reg        reg_we,
    output reg [2:0]  imm_sel,
    output reg        a_sel,
    output reg        b_sel,
    output reg [3:0]  alu_op,
    output reg        mem_re,
    output reg        mem_we,
    output     [2:0]  mem_size,   // load/store 크기 = funct3 (decode.md 6절)
    output reg [1:0]  wb_sel,
    output reg        branch,
    output reg        jal,
    output reg        jalr,
    output reg        illegal
);
    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];

    assign mem_size = funct3;

    // funct3 → ALU 연산 (OP와 OP-IMM 공통, inst[30]은 아래에서 따로 처리)
    reg [3:0] alu_from_funct3;
    always @(*) begin
        case (funct3)
            3'b000:  alu_from_funct3 = `ALU_ADD;
            3'b001:  alu_from_funct3 = `ALU_SLL;
            3'b010:  alu_from_funct3 = `ALU_SLT;
            3'b011:  alu_from_funct3 = `ALU_SLTU;
            3'b100:  alu_from_funct3 = `ALU_XOR;
            3'b101:  alu_from_funct3 = inst[30] ? `ALU_SRA : `ALU_SRL;
            3'b110:  alu_from_funct3 = `ALU_OR;
            default: alu_from_funct3 = `ALU_AND;   // 3'b111
        endcase
    end

    always @(*) begin
        // 기본값: 아무것도 쓰지 않고 다음 명령어로 (= NOP). 모든 출력에 값을 줘서 래치를 막는다.
        reg_we  = 1'b0;
        imm_sel = `IMM_I;
        a_sel   = `A_RS1;
        b_sel   = `B_RS2;
        alu_op  = `ALU_ADD;
        mem_re  = 1'b0;
        mem_we  = 1'b0;
        wb_sel  = `WB_ALU;
        branch  = 1'b0;
        jal     = 1'b0;
        jalr    = 1'b0;
        illegal = 1'b0;

        case (opcode)
            `OP_REG: begin                                   // add sub sll slt sltu xor srl sra or and
                // funct7은 0000000, 또는 sub·sra일 때만 0100000
                if (funct7 == 7'b0000000 ||
                    (funct7 == 7'b0100000 && (funct3 == 3'b000 || funct3 == 3'b101))) begin
                    reg_we = 1'b1;
                    alu_op = (funct3 == 3'b000 && inst[30]) ? `ALU_SUB : alu_from_funct3;
                end else
                    illegal = 1'b1;
            end

            `OP_IMM: begin                                   // addi slti sltiu xori ori andi slli srli srai
                // addi의 inst[30]은 즉치값 비트 → SUB로 보면 안 됨 (alu_from_funct3는 000을 항상 ADD로)
                // 시프트는 imm[11:5]가 0000000(slli·srli) 또는 0100000(srai)만 허용
                if ((funct3 == 3'b001 && funct7 != 7'b0000000) ||
                    (funct3 == 3'b101 && funct7 != 7'b0000000 && funct7 != 7'b0100000))
                    illegal = 1'b1;
                else begin
                    reg_we  = 1'b1;
                    imm_sel = `IMM_I;
                    b_sel   = `B_IMM;
                    alu_op  = alu_from_funct3;
                end
            end

            `OP_LOAD: begin                                  // lb lh lw lbu lhu (funct3 011·110·111 없음)
                if (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111)
                    illegal = 1'b1;
                else begin
                    reg_we  = 1'b1;
                    imm_sel = `IMM_I;
                    b_sel   = `B_IMM;
                    alu_op  = `ALU_ADD;                      // 주소 = rs1 + imm
                    mem_re  = 1'b1;
                    wb_sel  = `WB_MEM;
                end
            end

            `OP_STORE: begin                                 // sb sh sw (funct3 000~010만)
                if (funct3[2] || funct3 == 3'b011)
                    illegal = 1'b1;
                else begin
                    imm_sel = `IMM_S;
                    b_sel   = `B_IMM;
                    alu_op  = `ALU_ADD;                      // 주소 = rs1 + imm
                    mem_we  = 1'b1;
                end
            end

            `OP_BRANCH: begin                                // beq bne blt bge bltu bgeu (funct3 010·011 없음)
                if (funct3 == 3'b010 || funct3 == 3'b011)
                    illegal = 1'b1;
                else begin
                    imm_sel = `IMM_B;
                    branch  = 1'b1;                          // 성립 여부는 분기 비교기(funct3)가 판단
                end
            end

            `OP_LUI: begin
                reg_we  = 1'b1;
                imm_sel = `IMM_U;
                wb_sel  = `WB_IMM;                           // ALU를 거치지 않고 imm을 그대로
            end

            `OP_AUIPC: begin
                reg_we  = 1'b1;
                imm_sel = `IMM_U;
                a_sel   = `A_PC;
                b_sel   = `B_IMM;
                alu_op  = `ALU_ADD;                          // PC + imm
            end

            `OP_JAL: begin
                reg_we  = 1'b1;
                imm_sel = `IMM_J;
                wb_sel  = `WB_PC4;                           // rd = 돌아올 주소
                jal     = 1'b1;                              // 다음 PC = PC + imm (PC+imm 덧셈기)
            end

            `OP_JALR: begin
                if (funct3 != 3'b000)
                    illegal = 1'b1;
                else begin
                    reg_we  = 1'b1;
                    imm_sel = `IMM_I;
                    b_sel   = `B_IMM;
                    alu_op  = `ALU_ADD;                      // 대상 = rs1 + imm (최상위에서 & ~1)
                    wb_sel  = `WB_PC4;
                    jalr    = 1'b1;
                end
            end

            `OP_FENCE: begin
                if (funct3 != 3'b000)                        // fence.i(001)는 Zifencei 확장 → 지원 안 함
                    illegal = 1'b1;
                // fence: 단일 사이클·캐시 없음 → 할 일 없음 (NOP)
            end

            // `OP_SYSTEM (ecall, ebreak, CSR): 3단계에서는 illegal, 6장에서 트랩으로 구현
            default:
                illegal = 1'b1;
        endcase
    end
endmodule
