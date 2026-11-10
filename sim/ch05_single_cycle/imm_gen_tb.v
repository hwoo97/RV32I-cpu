`timescale 1ns/1ps
// imm_gen 자가 검사 테스트벤치 (decode.md 7절 규약: imm_sel 0:I 1:S 2:B 3:U 4:J, 그 밖은 0)
// 기댓값: riscv-tests·어셈블러로 확인한 실제 명령어 11개 + 무작위 60개 + 정의 안 된 imm_sel 3개.
// 기댓값은 명세의 비트 결합식으로 미리 계산해 넣었다 (테스트벤치 안에는 정답 회로가 없음).
module imm_gen_tb;
    localparam N = 74;
    reg  [31:0] vi [0:N-1];
    reg  [2:0]  vs [0:N-1];
    reg  [31:0] ve [0:N-1];

    reg  [31:0] inst;
    reg  [2:0]  imm_sel;
    wire [31:0] imm;
    integer     k, errors;

    imm_gen dut (.inst(inst), .imm_sel(imm_sel), .imm(imm));

    initial begin
        vi[0] = 32'h00800f93; vs[0] = 3'd0; ve[0] = 32'h00000008;  // addi t6,zero,8
        vi[1] = 32'hfff00093; vs[1] = 3'd0; ve[1] = 32'hffffffff;  // addi ra,zero,-1
        vi[2] = 32'h00012703; vs[2] = 3'd0; ve[2] = 32'h00000000;  // lw a4,0(sp)
        vi[3] = 32'hfc3f2223; vs[3] = 3'd1; ve[3] = 32'hffffffc4;  // sw gp,-60(t5)
        vi[4] = 32'h00b12023; vs[4] = 3'd1; ve[4] = 32'h00000000;  // sw a1,0(sp)
        vi[5] = 32'h03ff0863; vs[5] = 3'd2; ve[5] = 32'h00000030;  // beq t5,t6,+48
        vi[6] = 32'hfe0718e3; vs[6] = 3'd2; ve[6] = 32'hfffffff0;  // bne a4,zero,-16
        vi[7] = 32'h800002b7; vs[7] = 3'd3; ve[7] = 32'h80000000;  // lui t0,0x80000
        vi[8] = 32'h00000297; vs[8] = 3'd3; ve[8] = 32'h00000000;  // auipc t0,0
        vi[9] = 32'h0500006f; vs[9] = 3'd4; ve[9] = 32'h00000050;  // jal zero,+0x50
        vi[10] = 32'hffdff06f; vs[10] = 3'd4; ve[10] = 32'hfffffffc;  // jal zero,-4
        vi[11] = 32'h9f767c45; vs[11] = 3'd2; ve[11] = 32'hfffff1f8;  // random
        vi[12] = 32'hbde5c099; vs[12] = 3'd2; ve[12] = 32'hfffffbc0;  // random
        vi[13] = 32'hcb91ce37; vs[13] = 3'd4; ve[13] = 32'hfff1ccb8;  // random
        vi[14] = 32'h076ce2ef; vs[14] = 3'd3; ve[14] = 32'h076ce000;  // random
        vi[15] = 32'hc6a53877; vs[15] = 3'd1; ve[15] = 32'hfffffc70;  // random
        vi[16] = 32'ha6233255; vs[16] = 3'd0; ve[16] = 32'hfffffa62;  // random
        vi[17] = 32'he6a16a3b; vs[17] = 3'd1; ve[17] = 32'hfffffe74;  // random
        vi[18] = 32'h1cfb10f6; vs[18] = 3'd2; ve[18] = 32'h000009c0;  // random
        vi[19] = 32'h7814e8a2; vs[19] = 3'd1; ve[19] = 32'h00000791;  // random
        vi[20] = 32'h617959ce; vs[20] = 3'd4; ve[20] = 32'h00095e16;  // random
        vi[21] = 32'h1a1afe87; vs[21] = 3'd4; ve[21] = 32'h000af9a0;  // random
        vi[22] = 32'h3fd42359; vs[22] = 3'd0; ve[22] = 32'h000003fd;  // random
        vi[23] = 32'hbb2edb20; vs[23] = 3'd1; ve[23] = 32'hfffffbb6;  // random
        vi[24] = 32'h687c966c; vs[24] = 3'd2; ve[24] = 32'h0000068c;  // random
        vi[25] = 32'h2e9c82b1; vs[25] = 3'd3; ve[25] = 32'h2e9c8000;  // random
        vi[26] = 32'h28dbd25e; vs[26] = 3'd0; ve[26] = 32'h0000028d;  // random
        vi[27] = 32'h238642ea; vs[27] = 3'd4; ve[27] = 32'h00064238;  // random
        vi[28] = 32'h9e115e4b; vs[28] = 3'd3; ve[28] = 32'h9e115000;  // random
        vi[29] = 32'h206f5c66; vs[29] = 3'd1; ve[29] = 32'h00000218;  // random
        vi[30] = 32'h00745130; vs[30] = 3'd0; ve[30] = 32'h00000007;  // random
        vi[31] = 32'h359eeefb; vs[31] = 3'd1; ve[31] = 32'h0000035d;  // random
        vi[32] = 32'hf5cae3bf; vs[32] = 3'd1; ve[32] = 32'hffffff47;  // random
        vi[33] = 32'hdf561d80; vs[33] = 3'd1; ve[33] = 32'hfffffdfb;  // random
        vi[34] = 32'h4a0fe75d; vs[34] = 3'd2; ve[34] = 32'h000004ae;  // random
        vi[35] = 32'hf6236bf2; vs[35] = 3'd1; ve[35] = 32'hffffff77;  // random
        vi[36] = 32'h8a0a8c96; vs[36] = 3'd1; ve[36] = 32'hfffff8b9;  // random
        vi[37] = 32'h2e81d66d; vs[37] = 3'd1; ve[37] = 32'h000002ec;  // random
        vi[38] = 32'hf770c226; vs[38] = 3'd3; ve[38] = 32'hf770c000;  // random
        vi[39] = 32'h4c7d6df0; vs[39] = 3'd0; ve[39] = 32'h000004c7;  // random
        vi[40] = 32'h5c76f18a; vs[40] = 3'd3; ve[40] = 32'h5c76f000;  // random
        vi[41] = 32'h2a7c1880; vs[41] = 3'd1; ve[41] = 32'h000002b1;  // random
        vi[42] = 32'h43892dfc; vs[42] = 3'd0; ve[42] = 32'h00000438;  // random
        vi[43] = 32'h54f46a69; vs[43] = 3'd2; ve[43] = 32'h00000554;  // random
        vi[44] = 32'hd1412584; vs[44] = 3'd4; ve[44] = 32'hfff12514;  // random
        vi[45] = 32'h960d5a8f; vs[45] = 3'd0; ve[45] = 32'hfffff960;  // random
        vi[46] = 32'h98921396; vs[46] = 3'd2; ve[46] = 32'hfffff986;  // random
        vi[47] = 32'h10e6d8e6; vs[47] = 3'd2; ve[47] = 32'h00000910;  // random
        vi[48] = 32'h5af84e6b; vs[48] = 3'd2; ve[48] = 32'h000005bc;  // random
        vi[49] = 32'h7b121dc5; vs[49] = 3'd2; ve[49] = 32'h00000fba;  // random
        vi[50] = 32'h2f4d4c86; vs[50] = 3'd3; ve[50] = 32'h2f4d4000;  // random
        vi[51] = 32'h78f845f5; vs[51] = 3'd1; ve[51] = 32'h0000078b;  // random
        vi[52] = 32'h0e979cf3; vs[52] = 3'd2; ve[52] = 32'h000008f8;  // random
        vi[53] = 32'hf9a01fe8; vs[53] = 3'd0; ve[53] = 32'hffffff9a;  // random
        vi[54] = 32'hf3001cee; vs[54] = 3'd2; ve[54] = 32'hffffff38;  // random
        vi[55] = 32'hd84a1d3a; vs[55] = 3'd3; ve[55] = 32'hd84a1000;  // random
        vi[56] = 32'h04a012e8; vs[56] = 3'd4; ve[56] = 32'h0000104a;  // random
        vi[57] = 32'hc9a937a6; vs[57] = 3'd3; ve[57] = 32'hc9a93000;  // random
        vi[58] = 32'h5dbe4409; vs[58] = 3'd3; ve[58] = 32'h5dbe4000;  // random
        vi[59] = 32'h9419cf4d; vs[59] = 3'd0; ve[59] = 32'hfffff941;  // random
        vi[60] = 32'h73ec28d0; vs[60] = 3'd0; ve[60] = 32'h0000073e;  // random
        vi[61] = 32'hb52fa53c; vs[61] = 3'd1; ve[61] = 32'hfffffb4a;  // random
        vi[62] = 32'h9faba827; vs[62] = 3'd1; ve[62] = 32'hfffff9f0;  // random
        vi[63] = 32'h1e782196; vs[63] = 3'd1; ve[63] = 32'h000001e3;  // random
        vi[64] = 32'hedfde416; vs[64] = 3'd3; ve[64] = 32'hedfde000;  // random
        vi[65] = 32'h58296818; vs[65] = 3'd4; ve[65] = 32'h00096582;  // random
        vi[66] = 32'h5ad3ba32; vs[66] = 3'd4; ve[66] = 32'h0003bdac;  // random
        vi[67] = 32'h403a960a; vs[67] = 3'd3; ve[67] = 32'h403a9000;  // random
        vi[68] = 32'h1ba95a54; vs[68] = 3'd4; ve[68] = 32'h000951ba;  // random
        vi[69] = 32'hbf9703c0; vs[69] = 3'd2; ve[69] = 32'hfffffbe6;  // random
        vi[70] = 32'hdc14ed57; vs[70] = 3'd2; ve[70] = 32'hfffff5da;  // random
        vi[71] = 32'hffffffff; vs[71] = 3'd5; ve[71] = 32'h00000000;  // undefined imm_sel
        vi[72] = 32'hffffffff; vs[72] = 3'd6; ve[72] = 32'h00000000;  // undefined imm_sel
        vi[73] = 32'hffffffff; vs[73] = 3'd7; ve[73] = 32'h00000000;  // undefined imm_sel
    end

    initial begin
        errors = 0;
        #1;
        for (k = 0; k < N; k = k + 1) begin
            inst = vi[k]; imm_sel = vs[k];
            #1;
            if (imm !== ve[k]) begin
                $display("FAIL: vec %0d inst=%h imm_sel=%0d -> imm=%h (expected %h)", k, inst, imm_sel, imm, ve[k]);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS: %0d vectors", N);
        else             $display("FAIL: %0d / %0d vectors", errors, N);
        $finish;
    end
endmodule
