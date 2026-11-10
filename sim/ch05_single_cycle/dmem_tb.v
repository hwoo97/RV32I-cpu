`timescale 1ns/1ps
// dmem 자가 검사 테스트벤치 (decode.md 6절)
// 테스트벤치 안에 바이트 단위 기록 표(shadow)를 두고, store할 때 같이 기록해 load 결과와 비교한다.
// 확인 항목
//  1) sw → lw (워드 64개)
//  2) sb를 네 바이트 위치에 → lb(부호 확장)·lbu(0 확장)
//  3) sh를 두 위치에 → lh·lhu
//  4) 정렬 안 된 접근: misaligned = 1, store는 메모리를 바꾸지 않음
//  5) mem_we = 0이면 쓰지 않음
//  6) 무작위 store·load 4000회 (정렬된 주소)
module dmem_tb;
    localparam SB = 3'b000, SH = 3'b001, SW = 3'b010, LB = 3'b000, LH = 3'b001, LW = 3'b010, LBU = 3'b100, LHU = 3'b101;
    localparam SPAN = 512;                 // 테스트에 쓰는 주소 범위 (바이트)

    reg         clk = 0;
    reg         mem_re = 0, mem_we = 0;
    reg  [2:0]  mem_size = 0;
    reg  [31:0] addr = 0, wdata = 0;
    wire [31:0] rdata;
    wire        misaligned;

    reg  [7:0]  shadow [0:SPAN-1];
    integer     i, k, errors = 0;
    reg  [31:0] r_addr, r_data;
    reg  [2:0]  r_size;

    dmem #(.ADDR_BITS(13)) dut (
        .clk(clk), .mem_re(mem_re), .mem_we(mem_we), .mem_size(mem_size),
        .addr(addr), .wdata(wdata), .rdata(rdata), .misaligned(misaligned)
    );

    always #5 clk = ~clk;

    task fail(input [8*40:1] what, input [31:0] actual, input [31:0] expected);
        begin
            if (errors < 10)
                $display("FAIL: %0s addr=%h size=%b -> %h (expected %h) at %0t", what, addr, mem_size, actual, expected, $time);
            errors = errors + 1;
        end
    endtask

    // store: 하강 에지에서 입력을 바꾸고 다음 상승 에지에서 쓰기
    task store(input [2:0] size, input [31:0] a, input [31:0] d);
        begin
            @(negedge clk);
            mem_we = 1; mem_re = 0; mem_size = size; addr = a; wdata = d;
            @(posedge clk); #1;
            mem_we = 0;
            case (size)
                SB: shadow[a] = d[7:0];
                SH: begin shadow[a] = d[7:0]; shadow[a+1] = d[15:8]; end
                SW: begin shadow[a] = d[7:0]; shadow[a+1] = d[15:8]; shadow[a+2] = d[23:16]; shadow[a+3] = d[31:24]; end
            endcase
        end
    endtask

    // load: 비동기 읽기라 입력을 바꾼 뒤 조금 기다리면 바로 값이 나온다
    task load(input [2:0] size, input [31:0] a);
        reg [31:0] exp;
        begin
            mem_re = 1; mem_we = 0; mem_size = size; addr = a; #1;
            case (size)
                LB:  exp = {{24{shadow[a][7]}}, shadow[a]};
                LBU: exp = {24'd0, shadow[a]};
                LH:  exp = {{16{shadow[a+1][7]}}, shadow[a+1], shadow[a]};
                LHU: exp = {16'd0, shadow[a+1], shadow[a]};
                default: exp = {shadow[a+3], shadow[a+2], shadow[a+1], shadow[a]};
            endcase
            if (rdata !== exp)    fail("rdata", rdata, exp);
            if (misaligned !== 0) fail("misaligned (aligned access)", misaligned, 0);
            mem_re = 0;
        end
    endtask

    initial begin
        for (i = 0; i < SPAN; i = i + 1) shadow[i] = 8'h00;
        for (i = 0; i < SPAN; i = i + 4) store(SW, i, 32'h0);          // 테스트 범위를 0으로 채움

        // 1) sw → lw
        for (i = 0; i < 256; i = i + 4) store(SW, i, 32'hA5000000 + i * 32'h0001_0103);
        for (i = 0; i < 256; i = i + 4) load(LW, i);

        // 2) sb 네 위치 → lb·lbu (0x80 이상이면 부호 확장 차이가 드러남)
        store(SB, 32'h100, 32'hFFFF_FF81);
        store(SB, 32'h101, 32'h0000_007F);
        store(SB, 32'h102, 32'h1234_56C3);
        store(SB, 32'h103, 32'h0000_0000);
        for (i = 32'h100; i < 32'h104; i = i + 1) begin load(LB, i); load(LBU, i); end
        load(LW, 32'h100);

        // 3) sh 두 위치 → lh·lhu
        store(SH, 32'h108, 32'h0000_8001);
        store(SH, 32'h10A, 32'hFFFF_7FFE);
        load(LH, 32'h108); load(LHU, 32'h108); load(LH, 32'h10A); load(LHU, 32'h10A); load(LW, 32'h108);

        // 4) 정렬 안 된 접근
        for (i = 1; i < 4; i = i + 1) begin
            mem_re = 1; mem_size = LW; addr = 32'h110 + i; #1;
            if (misaligned !== 1) fail("misaligned lw", misaligned, 1);
        end
        for (i = 1; i < 4; i = i + 2) begin
            mem_re = 1; mem_size = LH; addr = 32'h110 + i; #1;
            if (misaligned !== 1) fail("misaligned lh", misaligned, 1);
        end
        mem_re = 1; mem_size = LB; addr = 32'h113; #1;
        if (misaligned !== 0) fail("lb never misaligned", misaligned, 0);
        mem_re = 0; mem_we = 0; #1;
        if (misaligned !== 0) fail("misaligned without access", misaligned, 0);
        // 정렬 안 된 store는 메모리를 바꾸면 안 됨 (shadow는 그대로 두고 확인)
        @(negedge clk); mem_we = 1; mem_size = SW; addr = 32'h102; wdata = 32'hDEAD_BEEF; #1;
        if (misaligned !== 1) fail("misaligned sw", misaligned, 1);
        @(posedge clk); #1; mem_we = 0;
        @(negedge clk); mem_we = 1; mem_size = SH; addr = 32'h109; wdata = 32'hDEAD_BEEF;
        @(posedge clk); #1; mem_we = 0;
        load(LW, 32'h100); load(LW, 32'h104); load(LW, 32'h108);

        // 5) mem_we = 0이면 쓰지 않음
        @(negedge clk); mem_we = 0; mem_size = SW; addr = 32'h0; wdata = 32'hFFFF_FFFF;
        @(posedge clk); #1;
        load(LW, 32'h0);

        // 6) 무작위 store·load (정렬된 주소)
        for (k = 0; k < 4000; k = k + 1) begin
            r_data = $random;
            case ($unsigned($random) % 3)
                0: begin r_size = SB; r_addr = $unsigned($random) % SPAN; end
                1: begin r_size = SH; r_addr = ($unsigned($random) % (SPAN / 2)) * 2; end
                default: begin r_size = SW; r_addr = ($unsigned($random) % (SPAN / 4)) * 4; end
            endcase
            store(r_size, r_addr, r_data);
            case ($unsigned($random) % 5)
                0: load(LB,  $unsigned($random) % SPAN);
                1: load(LBU, $unsigned($random) % SPAN);
                2: load(LH,  ($unsigned($random) % (SPAN / 2)) * 2);
                3: load(LHU, ($unsigned($random) % (SPAN / 2)) * 2);
                default: load(LW, ($unsigned($random) % (SPAN / 4)) * 4);
            endcase
        end

        if (errors == 0) $display("PASS: dmem");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #1000000 $display("FAIL: timeout");
        $finish;
    end
endmodule
