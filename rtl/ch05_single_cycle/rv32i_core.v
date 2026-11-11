`timescale 1ns/1ps
`include "rv32i_defs.vh"

// RV32I single-cycle CPU core - the CPU without memories (ASIC synthesis target)
//  - Connected per the block diagram (img/datapath.svg) and the naming table in decode.md sec. 8
//  - Finishes one instruction per clock: fetch -> decode -> register read -> ALU -> memory -> register write
//  - Harvard: separate instruction memory port (imem_*) and data memory port (dmem_*)
//    Memories live outside (rv32i_sc or the MCU bus). Both are assumed to have asynchronous read (single cycle)
//  - trap: unsupported instruction (illegal) or misaligned memory access. Stage 3: the testbench reports and stops
module rv32i_core #(
    parameter RESET_PC = 32'h0000_0000
) (
    input         clk,
    input         rst_n,                   // reset when 0 (asynchronous)
    // Instruction memory
    output [31:0] imem_addr,               // = pc
    input  [31:0] imem_rdata,              // = inst
    // Data memory (word based; byte handling is in lsu)
    output        dmem_re,                 // load (aligned only). Unused by the async RAM, kept for bus connection
    output [31:0] dmem_addr,               // = alu_result
    output [3:0]  dmem_wstrb,              // bytes to write (0 = no write)
    output [31:0] dmem_wdata,
    input  [31:0] dmem_rdata,
    // Debug / observation
    output [31:0] dbg_pc,                  // current PC
    output        trap                     // illegal | mem_misaligned
);
    // -- Top-level wires (decode.md 8.1) --
    wire [31:0] pc_next, pc_plus4, pc_target;
    reg  [31:0] pc;
    wire [31:0] inst, imm, rs1_data, rs2_data;
    wire [31:0] alu_a, alu_b, alu_result, mem_rdata;
    reg  [31:0] wb_data;
    wire        br_taken, mem_misaligned;

    // -- Control signals (decode.md sec. 2) --
    wire        reg_we, a_sel, b_sel, mem_re, mem_we, branch, jal, jalr, illegal;
    wire [2:0]  imm_sel, mem_size;
    wire [3:0]  alu_op;
    wire [1:0]  wb_sel;

    // -- PC register: the only state that needs reset (start address must be defined) --
    always @(posedge clk or negedge rst_n)
        if (!rst_n) pc <= RESET_PC;
        else        pc <= pc_next;

    // -- Next PC: (1) PC+4  (2) PC+imm (taken branch, jal)  (3) (rs1+imm) & ~1 (jalr) --
    assign pc_plus4  = pc + 32'd4;
    assign pc_target = pc + imm;
    assign pc_next   = jalr                       ? {alu_result[31:1], 1'b0} :
                       (jal | (branch & br_taken)) ? pc_target :
                                                     pc_plus4;

    // -- Instruction memory port --
    assign imem_addr = pc;
    assign inst      = imem_rdata;

    // -- Control unit --
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

    // -- Register file (a misaligned load does not write rd) --
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

    // -- Immediate generator --
    imm_gen u_imm_gen (
        .inst    (inst),
        .imm_sel (imm_sel),
        .imm     (imm)
    );

    // -- ALU input muxes and ALU --
    assign alu_a = (a_sel == `A_PC)  ? pc  : rs1_data;
    assign alu_b = (b_sel == `B_IMM) ? imm : rs2_data;

    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .alu_op (alu_op),
        .result (alu_result)
    );

    // -- Branch comparator --
    branch_cmp u_branch_cmp (
        .rs1_data (rs1_data),
        .rs2_data (rs2_data),
        .funct3   (inst[14:12]),
        .br_taken (br_taken)
    );

    // -- Load/Store unit -> data memory port --
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

    // -- WB mux: value written to rd --
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
