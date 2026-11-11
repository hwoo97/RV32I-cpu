`timescale 1ns/1ps
// Self-checking testbench for environment check - runs on both xsim (this PC) and Xcelium (school server)
module cnt_tb;
    reg        clk = 0, clrn = 0, enable = 0;
    wire [3:0] q;
    integer    errors = 0;

    cnt dut (.clk(clk), .clrn(clrn), .enable(enable), .q(q));

    always #5 clk = ~clk;          // 100 MHz

    task check(input [3:0] expected);
        if (q !== expected) begin
            $display("FAIL: q = %0d (expected %0d) at %0t", q, expected, $time);
            errors = errors + 1;
        end
    endtask

    initial begin
        #12 clrn = 1;
        check(4'd0);                       // 0 right after reset
        enable = 1;
        repeat (10) @(posedge clk); #1;
        check(4'd10);                      // incremented 10 times
        enable = 0;
        repeat (3) @(posedge clk); #1;
        check(4'd10);                      // holds when enable = 0
        enable = 1;
        repeat (6) @(posedge clk); #1;
        check(4'd0);                       // wraps from 15 to 0
        if (errors == 0) $display("PASS");
        $finish;
    end

    initial begin
        #10000 $display("FAIL: timeout");
        $finish;
    end
endmodule
