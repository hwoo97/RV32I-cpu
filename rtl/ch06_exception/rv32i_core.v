`timescale 1ns/1ps
`include "rv32i_defs.vh"

// RV32I single-cycle CPU core with Zicsr, M-mode traps and interrupts - ch6
//  - Copy of rtl/ch14a_mcu/rv32i_core.v (data-port wait) + csr.v (03_chapters/ch06_exception/design.md)
//  - Finishes one instruction per clock: fetch -> decode -> register read -> ALU -> memory -> register write
//  - Data port wait: when a load/store is issued and dmem_ready = 0, the core stalls (PC and all state are
//    held, the request stays stable). The access completes at the edge where dmem_ready = 1.
//  - Traps (decided in csr.v):
//      exception: the instruction does not complete - no rd write, no CSR write, no memory write
//                 (misaligned: lsu blocks the request; access fault: the address decoder blocks it;
//                  fetch fault: the data request of the garbage instruction is blocked here)
//                 next pc = mtvec, mepc = pc
//      interrupt: taken before an instruction without data access; that instruction is not executed
//      mret     : next pc = mepc
//  - Exception sources: fetch_fault (from the MCU decoder), illegal instruction / CSR, ecall, ebreak,
//    jump or taken branch to an address that is not 4-byte aligned, misaligned load/store,
//    data_fault (from the MCU decoder, reported in the completing cycle of the access)
//  - Harvard: separate instruction port (imem_*) and data port (dmem_*), memories outside (async read)
module rv32i_core #(
    parameter RESET_PC = 32'h0000_0000
) (
    input         clk,
    input         rst_n,                   // reset when 0 (asynchronous, already synchronized by the MCU)
    // Instruction memory
    output [31:0] imem_addr,               // = pc
    input  [31:0] imem_rdata,              // = inst
    input         fetch_fault,             // 1 = pc is outside the instruction memory
    // Data memory (word based; byte handling is in lsu)
    output        dmem_re,
    output [31:0] dmem_addr,               // = alu_result
    output [3:0]  dmem_wstrb,              // bytes to write (0 = no write)
    output [31:0] dmem_wdata,
    input  [31:0] dmem_rdata,
    input         dmem_ready,              // 1 = data access completes this cycle
    input         data_fault,              // 1 = the data access failed (access fault), with dmem_ready
    // Interrupt requests (level, synchronized)
    input         irq_timer,
    input         irq_ext,
    // Debug / observation
    output [31:0] dbg_pc,                  // current PC
    output        trap,                    // 1-cycle pulse: an exception is taken this cycle
    output        irq_taken                // 1-cycle pulse: an interrupt is taken this cycle
);
    // -- Top-level wires (decode.md 8.1) --
    wire [31:0] pc_next, pc_plus4, pc_target, pc_seq;
    reg  [31:0] pc;
    wire [31:0] inst, imm, rs1_data, rs2_data;
    wire [31:0] alu_a, alu_b, alu_result, mem_rdata;
    reg  [31:0] wb_data;
    wire        br_taken, mem_misaligned;
    wire        mem_wait;                  // 1 = load/store waiting for dmem_ready (stall this cycle)

    // -- Control signals (decode.md sec. 2) --
    wire        reg_we, a_sel, b_sel, mem_re, mem_we, branch, jal, jalr, illegal;
    wire        csr_en, ecall, ebreak, mret;
    wire [2:0]  imm_sel, mem_size;
    wire [3:0]  alu_op;
    wire [1:0]  wb_sel;

    // -- Trap control (csr.v) --
    wire        trap_take, exc_taken, mret_take;
    wire [31:0] trap_pc, mepc_pc, csr_rdata;

    // -- Stall: a load/store is issued but the data port is not ready yet --
    assign mem_wait = (dmem_re | (|dmem_wstrb)) & ~dmem_ready;

    // -- PC register: holds while stalled; trap / mret override the normal next PC --
    always @(posedge clk or negedge rst_n)
        if (!rst_n)          pc <= RESET_PC;
        else if (!mem_wait)  pc <= trap_take ? trap_pc : mret_take ? mepc_pc : pc_next;

    // -- Next PC: (1) PC+4  (2) PC+imm (taken branch, jal)  (3) (rs1+imm) & ~1 (jalr) --
    assign pc_plus4  = pc + 32'd4;
    assign pc_target = pc + imm;
    assign pc_seq    = (jal | (branch & br_taken)) ? pc_target : pc_plus4;
    assign pc_next   = jalr ? {alu_result[31:1], 1'b0} : pc_seq;
    // jump / taken branch to an address that is not 4-byte aligned (no compressed instructions)
    wire   jmp_misalign = (jal | jalr | (branch & br_taken)) & (pc_next[1:0] != 2'b00);

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
        .illegal  (illegal),
        .csr_en   (csr_en),
        .ecall    (ecall),
        .ebreak   (ebreak),
        .mret     (mret)
    );

    // -- Register file: written only when the instruction completes (no stall, no trap) --
    regfile u_regfile (
        .clk      (clk),
        .reg_we   (reg_we & ~mem_wait & ~trap_take),
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
    //    A fetched word from outside the instruction memory is not an instruction: no data request
    wire mem_re_v = mem_re & ~fetch_fault;
    wire mem_we_v = mem_we & ~fetch_fault;

    lsu u_lsu (
        .mem_re     (mem_re_v),
        .mem_we     (mem_we_v),
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
    assign dmem_re   = mem_re_v & ~mem_misaligned;

    // -- CSR file and trap decision --
    csr u_csr (
        .clk              (clk),
        .rst_n            (rst_n),
        .pc               (pc),
        .inst             (inst),
        .stall            (mem_wait),
        .mem_op           (mem_re | mem_we),
        .csr_en           (csr_en),
        .csr_src          (inst[14] ? {27'd0, inst[19:15]} : rs1_data),   // csrr?i: uimm = rs1 field
        .csr_rdata        (csr_rdata),
        .exc_fetch_fault  (fetch_fault),
        .exc_illegal      (illegal),
        .exc_ecall        (ecall),
        .exc_ebreak       (ebreak),
        .exc_jmp_misalign (jmp_misalign),
        .jmp_target       (pc_next),
        .exc_ld_misalign  (mem_re_v & mem_misaligned),
        .exc_st_misalign  (mem_we_v & mem_misaligned),
        .exc_ld_fault     (data_fault & mem_re_v),
        .exc_st_fault     (data_fault & mem_we_v),
        .mem_addr         (alu_result),
        .is_mret          (mret),
        .irq_timer        (irq_timer),
        .irq_ext          (irq_ext),
        .trap             (trap_take),
        .trap_is_irq      (irq_taken),
        .exc_taken        (exc_taken),
        .trap_pc          (trap_pc),
        .mret_take        (mret_take),
        .mepc_pc          (mepc_pc),
        .retire           ()
    );

    // -- WB mux: value written to rd --
    always @(*) begin
        if (csr_en)
            wb_data = csr_rdata;
        else begin
            case (wb_sel)
                `WB_MEM: wb_data = mem_rdata;
                `WB_PC4: wb_data = pc_plus4;
                `WB_IMM: wb_data = imm;
                default: wb_data = alu_result;   // `WB_ALU
            endcase
        end
    end

    assign dbg_pc = pc;
    assign trap   = exc_taken;
endmodule
