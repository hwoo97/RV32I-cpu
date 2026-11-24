`timescale 1ns/1ps
// Self-checking testbench for uart_fifo (03_chapters/ip_uart/design.md sec. 8)
//  1) fill to full (count, full, write ignored when full), drain to empty (order, read ignored when empty)
//  2) simultaneous write + read at empty / middle / full
//  3) clear in the middle
//  4) 5000 random cycles against a reference queue
module uart_fifo_tb;
    reg        clk = 0, rst_n = 0;
    reg        clr = 0, wr = 0, rd = 0;
    reg  [9:0] wdata = 0;
    wire [9:0] rdata;
    wire [4:0] count;
    wire       full, empty;
    always #2.5 clk = ~clk;

    uart_fifo #(.W(10), .AW(4)) dut (
        .clk(clk), .rst_n(rst_n), .clr(clr), .wr(wr), .wdata(wdata), .rd(rd),
        .rdata(rdata), .count(count), .full(full), .empty(empty)
    );

    // reference queue
    reg [9:0] q [0:15];
    integer   qh = 0, qn = 0, errors = 0, i, checks = 0;

    task check(input [8*40:1] what, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                if (errors < 10) $display("FAIL: %0s got %h expected %h at %0t", what, got, exp, $time);
            end
        end
    endtask

    // compare outputs with the model (state before the clock), then apply one clock
    task op(input c, input w, input [9:0] d, input r);
        integer n0, h0;
        begin
            check("count", count, qn);
            check("full", full, qn == 16);
            check("empty", empty, qn == 0);
            if (qn != 0) check("rdata", rdata, q[qh]);
            n0 = qn; h0 = qh;
            clr = c; wr = w; wdata = d; rd = r;
            @(posedge clk); #0.5;
            clr = 0; wr = 0; rd = 0;
            if (c) begin
                qh = 0; qn = 0;
            end else begin
                if (w && n0 < 16) begin
                    q[(h0 + n0) % 16] = d;
                    qn = qn + 1;
                end
                if (r && n0 > 0) begin
                    qh = (qh + 1) % 16;
                    qn = qn - 1;
                end
            end
        end
    endtask

    initial begin
        #12 rst_n = 1;
        @(posedge clk); #0.5;
        // 1) fill and drain
        for (i = 0; i < 18; i = i + 1) op(0, 1, 10'h100 + i, 0);
        for (i = 0; i < 18; i = i + 1) op(0, 0, 0, 1);
        // 2) write + read together: at empty, in the middle, at full
        op(0, 1, 10'h3aa, 1);
        for (i = 0; i < 8; i = i + 1) op(0, 1, 10'h200 + i, 0);
        for (i = 0; i < 4; i = i + 1) op(0, 1, 10'h280 + i, 1);
        for (i = 0; i < 12; i = i + 1) op(0, 1, 10'h2c0 + i, 0);
        op(0, 1, 10'h3ff, 1);
        // 3) clear
        op(1, 0, 0, 0);
        op(0, 1, 10'h155, 0);
        op(1, 1, 10'h0aa, 1);
        op(0, 0, 0, 0);
        // 4) random
        for (i = 0; i < 5000; i = i + 1)
            op(($random % 64) == 0, $random, $random, $random);
        while (qn != 0) op(0, 0, 0, 1);
        op(0, 0, 0, 0);
        if (errors == 0) $display("PASS: uart_fifo_tb (%0d checks)", checks);
        else             $display("FAIL: uart_fifo_tb (%0d errors in %0d checks)", errors, checks);
        $finish;
    end
endmodule
