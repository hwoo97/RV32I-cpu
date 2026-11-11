`timescale 1ns/1ps
// 4-bit counter for environment check (same behavior as the ch1 textbook example: +1 per clock when enabled)
module cnt (
    input            clk,
    input            clrn,     // asynchronous reset, active low
    input            enable,
    output reg [3:0] q
);
    always @(posedge clk or negedge clrn)
        if (!clrn)       q <= 4'd0;
        else if (enable) q <= q + 4'd1;
endmodule
