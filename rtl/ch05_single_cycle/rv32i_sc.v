`timescale 1ns/1ps

// RV32I single-cycle CPU + memories - top level for simulation and FPGA
//  - Attaches instruction memory (imem) and data memory (dmem) to rv32i_core (the CPU)
//  - ASIC synthesis covers rv32i_core only, since there are no memory macros (syn/ch05_single_cycle)
//  - Harvard: separate imem and dmem. Both read asynchronously; dmem writes on the clk rising edge
module rv32i_sc #(
    parameter RESET_PC  = 32'h0000_0000,
    parameter ADDR_BITS = 13,              // imem and dmem each 2^13 = 8 KB
    parameter IMEM_INIT = "",
    parameter DMEM_INIT = ""
) (
    input         clk,
    input         rst_n,                   // reset when 0 (asynchronous)
    output [31:0] dbg_pc,                  // observation: current PC
    output        trap                     // observation: illegal | mem_misaligned
);
    // -- Core <-> memory wires (decode.md 8.1) --
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
