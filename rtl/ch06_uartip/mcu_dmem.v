`timescale 1ns/1ps

// MCU data memory - word array with byte write enables (03_chapters/ch14a_mcu/design.md sec. 1)
//  - Read: asynchronous; write: rising edge, only the bytes selected by wstrb
//  - Only address bits [AW-1:2] are used (the decoder already checked the region)
//  - Not a synthesis target for ASIC (an SRAM macro would sit here); FPGA: distributed RAM
module mcu_dmem #(
    parameter AW        = 14,              // byte address bits: 2^14 = 16 KB
    parameter INIT_FILE = ""
) (
    input         clk,
    input  [31:0] addr,
    input  [3:0]  wstrb,
    input  [31:0] wdata,
    output [31:0] rdata
);
    reg [31:0] mem [0:(1 << (AW - 2)) - 1];

    initial
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    wire [AW-3:0] widx = addr[AW-1:2];

    always @(posedge clk) begin
        if (wstrb[0]) mem[widx][ 7: 0] <= wdata[ 7: 0];
        if (wstrb[1]) mem[widx][15: 8] <= wdata[15: 8];
        if (wstrb[2]) mem[widx][23:16] <= wdata[23:16];
        if (wstrb[3]) mem[widx][31:24] <= wdata[31:24];
    end

    assign rdata = mem[widx];
endmodule
