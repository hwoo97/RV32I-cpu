`timescale 1ns/1ps

// Data memory - plain RAM: word (32-bit) array + byte write enables (wstrb)
//  - Byte lane selection, sign extension and alignment check are done by lsu inside the core (decode.md sec. 6)
//  - Read: asynchronous (single-cycle CPU must compute address -> read -> write rd in the same cycle)
//  - Write: on clk rising edge, only the bytes selected by wstrb (no write when wstrb = 0)
//  - Address: only the low ADDR_BITS bits are used (upper bits ignored -> memory appears repeated)
//  - Not a synthesis target (simulation/FPGA only). ASIC synthesis covers the core (rv32i_core) only
module dmem #(
    parameter ADDR_BITS = 13,           // 2^13 = 8 KB
    parameter INIT_FILE = ""            // hex file for $readmemh (word format); empty = none
) (
    input         clk,
    input  [31:0] addr,                 // core dmem_addr
    input  [3:0]  wstrb,                // core dmem_wstrb
    input  [31:0] wdata,                // core dmem_wdata
    output [31:0] rdata                 // core dmem_rdata (raw word)
);
    localparam WORDS = 1 << (ADDR_BITS - 2);

    reg [31:0] mem [0:WORDS-1];

    initial
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    wire [ADDR_BITS-3:0] widx = addr[ADDR_BITS-1:2];   // word index

    always @(posedge clk) begin
        if (wstrb[0]) mem[widx][ 7: 0] <= wdata[ 7: 0];
        if (wstrb[1]) mem[widx][15: 8] <= wdata[15: 8];
        if (wstrb[2]) mem[widx][23:16] <= wdata[23:16];
        if (wstrb[3]) mem[widx][31:24] <= wdata[31:24];
    end

    assign rdata = mem[widx];
endmodule
