`timescale 1ns/1ps
// 환경 점검용 4비트 카운터 (1장 교재 예제와 같은 동작: enable일 때 클럭마다 1 증가)
module cnt (
    input            clk,
    input            clrn,     // 비동기 리셋, 0일 때 리셋
    input            enable,
    output reg [3:0] q
);
    always @(posedge clk or negedge clrn)
        if (!clrn)       q <= 4'd0;
        else if (enable) q <= q + 4'd1;
endmodule
