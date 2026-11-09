`timescale 1ns/1ps
// 환경 점검용 자가 검사 테스트벤치 — xsim(이 PC)과 Xcelium(학교 서버) 모두에서 실행
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
        check(4'd0);                       // 리셋 직후 0
        enable = 1;
        repeat (10) @(posedge clk); #1;
        check(4'd10);                      // 10번 증가
        enable = 0;
        repeat (3) @(posedge clk); #1;
        check(4'd10);                      // enable = 0이면 멈춤
        enable = 1;
        repeat (6) @(posedge clk); #1;
        check(4'd0);                       // 15 다음 0으로 돌아감
        if (errors == 0) $display("PASS");
        $finish;
    end

    initial begin
        #10000 $display("FAIL: timeout");
        $finish;
    end
endmodule
