`timescale 1ns/1ps

// Synchronous FIFO, flip-flop storage (gpdk045 has no SRAM) - UART IP (design.md sec. 2, decision E)
//  - Depth = 2**AW, width = W. Show-ahead read: rdata is the oldest entry whenever empty = 0.
//  - wr is ignored when full (even if rd is 1 in the same cycle), rd is ignored when empty.
//  - clr empties the FIFO (pointers and count to 0); the storage is not cleared.
module uart_fifo #(
    parameter W  = 8,
    parameter AW = 4
) (
    input               clk,
    input               rst_n,          // asynchronous reset, active low
    input               clr,            // synchronous clear
    input               wr,
    input      [W-1:0]  wdata,
    input               rd,
    output     [W-1:0]  rdata,
    output reg [AW:0]   count,          // 0 .. 2**AW
    output              full,
    output              empty
);
    localparam DEPTH = 1 << AW;

    reg [W-1:0]  mem [0:DEPTH-1];
    reg [AW-1:0] wp, rp;

    assign full  = (count == DEPTH);
    assign empty = (count == 0);
    assign rdata = mem[rp];

    wire do_wr = wr & ~full;
    wire do_rd = rd & ~empty;

    always @(posedge clk)
        if (do_wr && !clr) mem[wp] <= wdata;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            wp    <= {AW{1'b0}};
            rp    <= {AW{1'b0}};
            count <= {(AW+1){1'b0}};
        end else if (clr) begin
            wp    <= {AW{1'b0}};
            rp    <= {AW{1'b0}};
            count <= {(AW+1){1'b0}};
        end else begin
            if (do_wr) wp <= wp + 1'b1;
            if (do_rd) rp <= rp + 1'b1;
            if (do_wr & ~do_rd)      count <= count + 1'b1;
            else if (do_rd & ~do_wr) count <= count - 1'b1;
        end
endmodule
