`timescale 1ns/1ps
// rv32i_sc(단일 사이클 CPU) 테스트벤치 — riscv-tests 판정
//  - +HEX=<파일>   : 테스트 프로그램 (워드 hex). imem·dmem에 똑같이 읽어 들인다
//  - +TOHOST=<hex> : 판정 주소 (기본 1000, sim/riscv-tests-env/link.ld)
//  - +MAXCYC=<10진수> : 최대 사이클 (기본 100000)
// 판정
//  - 프로그램이 tohost에 쓴 값이 1이면 PASS, 그 밖의 홀수면 FAIL (실패한 테스트 번호 = 값 >> 1)
//  - trap(illegal 명령어·정렬 오류)이나 최대 사이클 초과도 FAIL
module rv32i_sc_tb;
    reg clk = 0, rst_n = 0;
    wire [31:0] dbg_pc;
    wire        trap;

    reg  [8*256:1] hex;
    reg  [31:0]    tohost;
    integer        maxcyc, cycles;

    rv32i_sc #(.ADDR_BITS(13)) dut (.clk(clk), .rst_n(rst_n), .dbg_pc(dbg_pc), .trap(trap));

    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("HEX=%s", hex)) begin
            $display("FAIL: +HEX=<file> not given");
            $finish;
        end
        if (!$value$plusargs("TOHOST=%h", tohost)) tohost = 32'h0000_1000;
        if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 100000;

        $readmemh(hex, dut.u_imem.mem);
        $readmemh(hex, dut.u_dmem.mem);

        #12 rst_n = 1;
    end

    // 매 클럭: tohost 쓰기·trap·사이클 수 확인 (상승 에지 직전 = 이번 명령어의 값이 다 정해진 시점)
    initial cycles = 0;
    always @(negedge clk) if (rst_n) begin
        cycles = cycles + 1;

        // 코어의 데이터 메모리 포트를 본다: tohost에 sw(wstrb = 1111)
        if (dut.dmem_wstrb == 4'b1111 && dut.dmem_addr == tohost) begin
            if (dut.dmem_wdata == 32'd1)
                $display("PASS: %0s (%0d cycles)", hex, cycles);
            else
                $display("FAIL: %0s test %0d (tohost=%h, pc=%h)", hex, dut.dmem_wdata >> 1, dut.dmem_wdata, dbg_pc);
            $finish;
        end

        if (trap) begin
            $display("FAIL: %0s trap at pc=%h inst=%h (illegal=%b misaligned=%b)",
                     hex, dbg_pc, dut.imem_rdata, dut.u_core.illegal, dut.u_core.mem_misaligned);
            $finish;
        end

        if (cycles >= maxcyc) begin
            $display("FAIL: %0s timeout after %0d cycles (pc=%h)", hex, cycles, dbg_pc);
            $finish;
        end
    end
endmodule
