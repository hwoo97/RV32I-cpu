`timescale 1ns/1ps

// RV32I 단일 사이클 CPU + 메모리 — 시뮬레이션·FPGA용 최상위
//  - rv32i_core(CPU 본체)에 명령어 메모리(imem)와 데이터 메모리(dmem)를 붙인다
//  - ASIC 합성은 메모리 매크로가 없어서 rv32i_core만 한다 (syn/ch05_single_cycle)
//  - 하버드 구조: imem과 dmem이 따로 있다. 둘 다 비동기 읽기, dmem은 clk 상승 에지에 쓰기
module rv32i_sc #(
    parameter RESET_PC  = 32'h0000_0000,
    parameter ADDR_BITS = 13,              // imem·dmem 각각 2^13 = 8 KB
    parameter IMEM_INIT = "",
    parameter DMEM_INIT = ""
) (
    input         clk,
    input         rst_n,                   // 0일 때 리셋 (비동기)
    output [31:0] dbg_pc,                  // 관찰용: 현재 PC
    output        trap                     // 관찰용: illegal | mem_misaligned
);
    // ── 코어 ↔ 메모리 연결 wire (decode.md 8.1) ──
    wire [31:0] imem_addr, imem_rdata;
    wire        dmem_re;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;

    rv32i_core #(.RESET_PC(RESET_PC)) u_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_re    (dmem_re),
        .dmem_addr  (dmem_addr),
        .dmem_wstrb (dmem_wstrb),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dbg_pc     (dbg_pc),
        .trap       (trap)
    );

    imem #(.ADDR_BITS(ADDR_BITS), .INIT_FILE(IMEM_INIT)) u_imem (
        .addr (imem_addr),
        .inst (imem_rdata)
    );

    dmem #(.ADDR_BITS(ADDR_BITS), .INIT_FILE(DMEM_INIT)) u_dmem (
        .clk   (clk),
        .addr  (dmem_addr),
        .wstrb (dmem_wstrb),
        .wdata (dmem_wdata),
        .rdata (dmem_rdata)
    );
endmodule
