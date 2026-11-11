`timescale 1ns/1ps

// Instruction memory - read only, asynchronous read (single-cycle CPU fetches and executes in the same cycle)
//  - Word (32-bit) array; low 2 address bits ignored (instructions are always 4-byte aligned)
//  - Contents come from INIT_FILE ($readmemh, word hex) or are loaded directly by the testbench
module imem #(
    parameter ADDR_BITS = 13,       // 2^13 = 8 KB
    parameter INIT_FILE = ""
) (
    input  [31:0] addr,             // top-level pc
    output [31:0] inst
);
    localparam WORDS = 1 << (ADDR_BITS - 2);

    reg [31:0] mem [0:WORDS-1];

    initial
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    assign inst = mem[addr[ADDR_BITS-1:2]];
endmodule
