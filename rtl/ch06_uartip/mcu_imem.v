`timescale 1ns/1ps

// MCU instruction memory - 2 asynchronous read ports, read only (03_chapters/ch14a_mcu/design.md sec. 1, 2.1)
//  - Port A: instruction fetch (rv32i_mcu imem_*)
//  - Port B: data-side reads of constants and .data initial values (rv32i_mcu irom_*)
//  - Word array; only address bits [AW-1:2] are used (the decoder already checked the region)
//  - Contents: INIT_FILE ($readmemh, word hex) or loaded by the testbench
//  - Not a synthesis target for ASIC (an SRAM macro would sit here); FPGA: distributed RAM
module mcu_imem #(
    parameter AW        = 14,              // byte address bits: 2^14 = 16 KB
    parameter INIT_FILE = ""
) (
    input  [31:0] addr_a,
    output [31:0] rdata_a,
    input  [31:0] addr_b,
    output [31:0] rdata_b
);
    reg [31:0] mem [0:(1 << (AW - 2)) - 1];

    initial
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    assign rdata_a = mem[addr_a[AW-1:2]];
    assign rdata_b = mem[addr_b[AW-1:2]];
endmodule
