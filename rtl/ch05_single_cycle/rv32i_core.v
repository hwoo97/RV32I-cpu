`timescale 1ns/1ps
`include "rv32i_defs.vh"

// RV32I 단일 사이클 CPU 코어 — 메모리를 뺀 CPU 본체 (ASIC 합성 대상)
//  - 블록 다이어그램(img/datapath.svg)과 decode.md 8절 이름표대로 연결
//  - 명령어 하나를 한 클럭 사이클에 끝낸다: 가져오기 → 해독 → 레지스터 읽기 → ALU → 메모리 → 레지스터 쓰기
//  - 하버드 구조: 명령어 메모리 포트(imem_*)와 데이터 메모리 포트(dmem_*)가 따로 있다
//    메모리는 바깥(rv32i_sc 또는 MCU 버스)에 둔다. 둘 다 비동기 읽기를 가정한다 (단일 사이클)
//  - trap: 지원하지 않는 명령어(illegal) 또는 정렬 안 된 메모리 접근. 3단계에서는 테스트벤치가 보고 멈춘다
module rv32i_core #(
    parameter RESET_PC = 32'h0000_0000
) (
    input         clk,
    input         rst_n,                   // 0일 때 리셋 (비동기)
    // 명령어 메모리
    output [31:0] imem_addr,               // = pc
    input  [31:0] imem_rdata,              // = inst
    // 데이터 메모리 (워드 단위, 바이트 처리는 lsu)
    output        dmem_re,                 // load (정렬된 경우만). 비동기 RAM은 쓰지 않지만 버스 연결용
    output [31:0] dmem_addr,               // = alu_result
    output [3:0]  dmem_wstrb,              // 쓸 바이트 (0이면 쓰기 없음)
    output [31:0] dmem_wdata,
    input  [31:0] dmem_rdata,
    // 관찰용
    output [31:0] dbg_pc,                  // 현재 PC
    output        trap                     // illegal | mem_misaligned
);
    // ── 최상위 wire (decode.md 8.1) ──
    wire [31:0] pc_next, pc_plus4, pc_target;
    reg  [31:0] pc;
    wire [31:0] inst, imm, rs1_data, rs2_data;
    wire [31:0] alu_a, alu_b, alu_result, mem_rdata;
    reg  [31:0] wb_data;
    wire        br_taken, mem_misaligned;

    // ── 제어 신호 (decode.md 2절) ──
    wire        reg_we, a_sel, b_sel, mem_re, mem_we, branch, jal, jalr, illegal;
    wire [2:0]  imm_sel, mem_size;
    wire [3:0]  alu_op;
    wire [1:0]  wb_sel;

    // ── PC 레지스터: 리셋이 필요한 유일한 상태 (시작 주소가 정해져 있어야 함) ──
    always @(posedge clk or negedge rst_n)
        if (!rst_n) pc <= RESET_PC;
        else        pc <= pc_next;

    // ── 다음 PC: ① PC+4  ② PC+imm (분기 성립·jal)  ③ (rs1+imm) & ~1 (jalr) ──
    assign pc_plus4  = pc + 32'd4;
    assign pc_target = pc + imm;
    assign pc_next   = jalr                       ? {alu_result[31:1], 1'b0} :
                       (jal | (branch & br_taken)) ? pc_target :
                                                     pc_plus4;

    // ── 명령어 메모리 포트 ──
    assign imem_addr = pc;
    assign inst      = imem_rdata;

    // ── 제어 유닛 ──
    control u_control (
        .inst     (inst),
        .reg_we   (reg_we),
        .imm_sel  (imm_sel),
        .a_sel    (a_sel),
        .b_sel    (b_sel),
        .alu_op   (alu_op),
        .mem_re   (mem_re),
        .mem_we   (mem_we),
        .mem_size (mem_size),
        .wb_sel   (wb_sel),
        .branch   (branch),
        .jal      (jal),
        .jalr     (jalr),
        .illegal  (illegal)
    );

    // ── 레지스터 파일 (정렬 오류인 load는 rd에 쓰지 않음) ──
    regfile u_regfile (
        .clk      (clk),
        .reg_we   (reg_we & ~mem_misaligned),
        .rs1_addr (inst[19:15]),
        .rs2_addr (inst[24:20]),
        .rd_addr  (inst[11:7]),
        .rd_data  (wb_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ── 즉치값 생성기 ──
    imm_gen u_imm_gen (
        .inst    (inst),
        .imm_sel (imm_sel),
        .imm     (imm)
    );

    // ── ALU 입력 MUX와 ALU ──
    assign alu_a = (a_sel == `A_PC)  ? pc  : rs1_data;
    assign alu_b = (b_sel == `B_IMM) ? imm : rs2_data;

    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .alu_op (alu_op),
        .result (alu_result)
    );

    // ── 분기 비교기 ──
    branch_cmp u_branch_cmp (
        .rs1_data (rs1_data),
        .rs2_data (rs2_data),
        .funct3   (inst[14:12]),
        .br_taken (br_taken)
    );

    // ── Load/Store 유닛 → 데이터 메모리 포트 ──
    lsu u_lsu (
        .mem_re     (mem_re),
        .mem_we     (mem_we),
        .mem_size   (mem_size),
        .addr       (alu_result),
        .wdata      (rs2_data),
        .rdata      (mem_rdata),
        .misaligned (mem_misaligned),
        .dmem_wstrb (dmem_wstrb),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata)
    );

    assign dmem_addr = alu_result;
    assign dmem_re   = mem_re & ~mem_misaligned;

    // ── WB MUX: rd에 쓸 값 ──
    always @(*) begin
        case (wb_sel)
            `WB_MEM: wb_data = mem_rdata;
            `WB_PC4: wb_data = pc_plus4;
            `WB_IMM: wb_data = imm;
            default: wb_data = alu_result;   // `WB_ALU
        endcase
    end

    assign dbg_pc = pc;
    assign trap   = illegal | mem_misaligned;
endmodule
