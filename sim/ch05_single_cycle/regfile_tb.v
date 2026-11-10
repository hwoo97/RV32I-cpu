`timescale 1ns/1ps
// regfile 자가 검사 테스트벤치
// 확인 항목
//  1) 31개 레지스터에 서로 다른 값을 쓰고 두 읽기 포트로 모두 읽기
//  2) x0에 써도 0으로 읽힘
//  3) reg_we = 0이면 쓰지 않음
//  4) 쓰는 사이클에는 이전 값, 클럭 에지 뒤에는 새 값 (단일 사이클 CPU의 동작)
//  5) 무작위 쓰기·읽기 2000회를 테스트벤치 안의 기록 표(shadow)와 비교
module regfile_tb;
    reg         clk = 0;
    reg         reg_we = 0;
    reg  [4:0]  rs1_addr = 0, rs2_addr = 0, rd_addr = 0;
    reg  [31:0] rd_data = 0;
    wire [31:0] rs1_data, rs2_data;

    reg  [31:0] shadow [0:31];   // 지금까지 쓴 값 기록 (x0은 항상 0)
    integer     i, errors = 0;

    regfile dut (
        .clk      (clk),
        .reg_we   (reg_we),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (rd_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    always #5 clk = ~clk;

    task check(input [31:0] actual, input [31:0] expected, input [8*24:1] what);
        if (actual !== expected) begin
            if (errors < 10)
                $display("FAIL: %0s = %h (expected %h) at %0t", what, actual, expected, $time);
            errors = errors + 1;
        end
    endtask

    // 클럭 하강 에지에서 입력을 바꾸고, 다음 상승 에지에서 쓰기가 일어난다
    task write_reg(input [4:0] addr, input [31:0] data, input we);
        begin
            @(negedge clk);
            rd_addr = addr; rd_data = data; reg_we = we;
            @(posedge clk); #1;
            reg_we = 0;
            if (we && addr != 0) shadow[addr] = data;
        end
    endtask

    task read_check(input [4:0] a1, input [4:0] a2);
        begin
            rs1_addr = a1; rs2_addr = a2; #1;
            check(rs1_data, shadow[a1], "rs1_data");
            check(rs2_data, shadow[a2], "rs2_data");
        end
    endtask

    initial begin
        for (i = 0; i < 32; i = i + 1) shadow[i] = 32'd0;

        // 1) 모든 레지스터에 서로 다른 값 쓰기 → 두 포트로 읽기
        for (i = 1; i < 32; i = i + 1) write_reg(i, 32'h1000_0000 * (i % 16) + i * 32'h0101_0101, 1);
        for (i = 0; i < 32; i = i + 1) read_check(i, 31 - i);

        // 2) x0에 쓰기 → 0으로 읽혀야 함
        write_reg(0, 32'hdead_beef, 1);
        read_check(0, 0);

        // 3) reg_we = 0이면 쓰지 않음
        write_reg(5, 32'hffff_ffff, 0);
        read_check(5, 5);

        // 4) 쓰는 사이클에는 이전 값, 에지 뒤에는 새 값
        @(negedge clk);
        rd_addr = 7; rd_data = 32'h1234_5678; reg_we = 1;
        rs1_addr = 7; rs2_addr = 7; #1;
        check(rs1_data, shadow[7], "rs1_data before edge");
        @(posedge clk); #1;
        reg_we = 0; shadow[7] = 32'h1234_5678;
        check(rs1_data, 32'h1234_5678, "rs1_data after edge");

        // 5) 무작위 쓰기·읽기
        for (i = 0; i < 2000; i = i + 1) begin
            write_reg($random, $random, $random);
            read_check($random, $random);
        end

        if (errors == 0) $display("PASS: regfile");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #200000 $display("FAIL: timeout");
        $finish;
    end
endmodule
