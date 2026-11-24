`timescale 1ns/1ps

// Baud tick generator - UART IP (design.md sec. 1, 7)
//  tick is a 1-clock pulse every (div + 1) clocks = 16 times per bit.
//  baud rate = clk / (16 * (div + 1)). If div is lowered below the current count, the counter
//  restarts at the next clock (no long wrap-around).
module uart_baud (
    input             clk,
    input             rst_n,
    input      [15:0] div,
    output reg        tick
);
    reg [15:0] cnt;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            cnt  <= 16'd0;
            tick <= 1'b0;
        end else if (cnt >= div) begin
            cnt  <= 16'd0;
            tick <= 1'b1;
        end else begin
            cnt  <= cnt + 16'd1;
            tick <= 1'b0;
        end
endmodule
