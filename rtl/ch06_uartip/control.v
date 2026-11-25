`timescale 1ns/1ps
`include "rv32i_defs.vh"

// Control unit - decodes the instruction into datapath control signals (combinational)
// Direct translation of the decode.md tables: sec. 3 (per opcode), 4 (ALU op), 5 (branch), 6 (load/store).
// ch6 version: SYSTEM is decoded (03_chapters/ch06_exception/design.md):
//   csrrw/csrrs/csrrc and the immediate forms -> csr_en (rd gets the old CSR value)
//   ecall, ebreak, mret; wfi is executed as a NOP (allowed by the spec)
//   Other SYSTEM encodings and all undefined instructions are illegal.
module control (
    input      [31:0] inst,
    output reg        reg_we,
    output reg [2:0]  imm_sel,
    output reg        a_sel,
    output reg        b_sel,
    output reg [3:0]  alu_op,
    output reg        mem_re,
    output reg        mem_we,
    output     [2:0]  mem_size,   // load/store size = funct3 (decode.md sec. 6)
    output reg [1:0]  wb_sel,
    output reg        branch,
    output reg        jal,
    output reg        jalr,
    output reg        illegal,
    output reg        csr_en,     // CSR instruction
    output reg        ecall,
    output reg        ebreak,
    output reg        mret
);
    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];

    assign mem_size = funct3;

    // funct3 -> ALU op (shared by OP and OP-IMM; inst[30] is handled separately below)
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
        // Defaults: write nothing and go to the next instruction (= NOP). Every output gets a value to avoid latches.
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
        csr_en  = 1'b0;
        ecall   = 1'b0;
        ebreak  = 1'b0;
        mret    = 1'b0;

        case (opcode)
            `OP_REG: begin                                   // add sub sll slt sltu xor srl sra or and
                // funct7 must be 0000000, or 0100000 only for sub/sra
                if (funct7 == 7'b0000000 ||
                    (funct7 == 7'b0100000 && (funct3 == 3'b000 || funct3 == 3'b101))) begin
                    reg_we = 1'b1;
                    alu_op = (funct3 == 3'b000 && inst[30]) ? `ALU_SUB : alu_from_funct3;
                end else
                    illegal = 1'b1;
            end

            `OP_IMM: begin                                   // addi slti sltiu xori ori andi slli srli srai
                // addi's inst[30] is an immediate bit -> must not be treated as SUB (alu_from_funct3 maps 000 to ADD)
                // shifts allow imm[11:5] = 0000000 (slli/srli) or 0100000 (srai) only
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

            `OP_LOAD: begin                                  // lb lh lw lbu lhu (no funct3 011/110/111)
                if (funct3 == 3'b011 || funct3 == 3'b110 || funct3 == 3'b111)
                    illegal = 1'b1;
                else begin
                    reg_we  = 1'b1;
                    imm_sel = `IMM_I;
                    b_sel   = `B_IMM;
                    alu_op  = `ALU_ADD;                      // address = rs1 + imm
                    mem_re  = 1'b1;
                    wb_sel  = `WB_MEM;
                end
            end

            `OP_STORE: begin                                 // sb sh sw (funct3 000..010 only)
                if (funct3[2] || funct3 == 3'b011)
                    illegal = 1'b1;
                else begin
                    imm_sel = `IMM_S;
                    b_sel   = `B_IMM;
                    alu_op  = `ALU_ADD;                      // address = rs1 + imm
                    mem_we  = 1'b1;
                end
            end

            `OP_BRANCH: begin                                // beq bne blt bge bltu bgeu (no funct3 010/011)
                if (funct3 == 3'b010 || funct3 == 3'b011)
                    illegal = 1'b1;
                else begin
                    imm_sel = `IMM_B;
                    branch  = 1'b1;                          // taken/not-taken decided by branch_cmp (funct3)
                end
            end

            `OP_LUI: begin
                reg_we  = 1'b1;
                imm_sel = `IMM_U;
                wb_sel  = `WB_IMM;                           // write imm directly, bypassing the ALU
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
                wb_sel  = `WB_PC4;                           // rd = return address
                jal     = 1'b1;                              // next PC = PC + imm (PC+imm adder)
            end

            `OP_JALR: begin
                if (funct3 != 3'b000)
                    illegal = 1'b1;
                else begin
                    reg_we  = 1'b1;
                    imm_sel = `IMM_I;
                    b_sel   = `B_IMM;
                    alu_op  = `ALU_ADD;                      // target = rs1 + imm (& ~1 at the top)
                    wb_sel  = `WB_PC4;
                    jalr    = 1'b1;
                end
            end

            `OP_FENCE: begin
                if (funct3 != 3'b000)                        // fence.i (001) is Zifencei -> not supported
                    illegal = 1'b1;
                // fence: single cycle, no cache -> nothing to do (NOP)
            end

            `OP_SYSTEM: begin
                if (funct3 == 3'b000) begin                  // privileged: rs1 = 0 and rd = 0 required
                    if (inst[19:15] != 5'd0 || inst[11:7] != 5'd0)
                        illegal = 1'b1;
                    else begin
                        case (inst[31:20])
                            12'h000: ecall  = 1'b1;
                            12'h001: ebreak = 1'b1;
                            12'h302: mret   = 1'b1;
                            12'h105: ;                       // wfi: NOP
                            default: illegal = 1'b1;
                        endcase
                    end
                end else if (funct3 == 3'b100)               // no such CSR instruction
                    illegal = 1'b1;
                else begin                                   // csrrw csrrs csrrc csrrwi csrrsi csrrci
                    csr_en = 1'b1;                           // nonexistent / read-only CSR: decided in csr.v
                    reg_we = 1'b1;
                end
            end

            default:
                illegal = 1'b1;
        endcase
    end
endmodule
