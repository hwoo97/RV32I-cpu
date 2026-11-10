`timescale 1ns/1ps
// control 자가 검사 테스트벤치 (decode.md 3~6절, rv32i_defs.vh 값 기준)
// 벡터: RV32I 명령어 41개(어셈블러로 인코딩) + 정의되지 않은·지원하지 않는 명령어 19개.
// 기댓값은 decode.md 표를 옮긴 Python 기준 모델로 미리 계산했다.
// 출력 13개를 한 줄로 묶어 비교하고, 그 명령어에서 의미 없는 칸("—")은 마스크로 비교에서 뺀다.
// 묶는 순서(위→아래): reg_we imm_sel a_sel b_sel alu_op mem_re mem_we mem_size wb_sel branch jal jalr illegal
module control_tb;
    localparam N = 60;
    reg  [31:0] vi [0:N-1];
    reg  [20:0] ve [0:N-1];
    reg  [20:0] vm [0:N-1];

    reg  [31:0] inst;
    wire        reg_we, a_sel, b_sel, mem_re, mem_we, branch, jal, jalr, illegal;
    wire [2:0]  imm_sel, mem_size;
    wire [3:0]  alu_op;
    wire [1:0]  wb_sel;
    wire [20:0] sig = {reg_we, imm_sel, a_sel, b_sel, alu_op, mem_re, mem_we, mem_size, wb_sel, branch, jal, jalr, illegal};
    integer     k, errors;

    control dut (
        .inst(inst), .reg_we(reg_we), .imm_sel(imm_sel), .a_sel(a_sel), .b_sel(b_sel), .alu_op(alu_op),
        .mem_re(mem_re), .mem_we(mem_we), .mem_size(mem_size), .wb_sel(wb_sel),
        .branch(branch), .jal(jal), .jalr(jalr), .illegal(illegal)
    );

    initial begin
        vi[0] = 32'h00c58533; ve[0] = 21'h100000; vm[0] = 21'h11fe3f;  // add a0,a1,a2
        vi[1] = 32'h40c58533; ve[1] = 21'h100800; vm[1] = 21'h11fe3f;  // sub a0,a1,a2
        vi[2] = 32'h00c59533; ve[2] = 21'h101000; vm[2] = 21'h11fe3f;  // sll a0,a1,a2
        vi[3] = 32'h00c5a533; ve[3] = 21'h101800; vm[3] = 21'h11fe3f;  // slt a0,a1,a2
        vi[4] = 32'h00c5b533; ve[4] = 21'h102000; vm[4] = 21'h11fe3f;  // sltu a0,a1,a2
        vi[5] = 32'h00c5c533; ve[5] = 21'h102800; vm[5] = 21'h11fe3f;  // xor a0,a1,a2
        vi[6] = 32'h00c5d533; ve[6] = 21'h103000; vm[6] = 21'h11fe3f;  // srl a0,a1,a2
        vi[7] = 32'h40c5d533; ve[7] = 21'h103800; vm[7] = 21'h11fe3f;  // sra a0,a1,a2
        vi[8] = 32'h00c5e533; ve[8] = 21'h104000; vm[8] = 21'h11fe3f;  // or a0,a1,a2
        vi[9] = 32'h00c5f533; ve[9] = 21'h104800; vm[9] = 21'h11fe3f;  // and a0,a1,a2
        vi[10] = 32'hfff58513; ve[10] = 21'h108000; vm[10] = 21'h1ffe3f;  // addi a0,a1,-1
        vi[11] = 32'h80058513; ve[11] = 21'h108000; vm[11] = 21'h1ffe3f;  // addi a0,a1,-2048
        vi[12] = 32'h0055a513; ve[12] = 21'h109800; vm[12] = 21'h1ffe3f;  // slti a0,a1,5
        vi[13] = 32'hfff5b513; ve[13] = 21'h10a000; vm[13] = 21'h1ffe3f;  // sltiu a0,a1,-1
        vi[14] = 32'hfff5c513; ve[14] = 21'h10a800; vm[14] = 21'h1ffe3f;  // xori a0,a1,-1
        vi[15] = 32'h0555e513; ve[15] = 21'h10c000; vm[15] = 21'h1ffe3f;  // ori a0,a1,85
        vi[16] = 32'h7ff5f513; ve[16] = 21'h10c800; vm[16] = 21'h1ffe3f;  // andi a0,a1,2047
        vi[17] = 32'h01f59513; ve[17] = 21'h109000; vm[17] = 21'h1ffe3f;  // slli a0,a1,0x1f
        vi[18] = 32'h0015d513; ve[18] = 21'h10b000; vm[18] = 21'h1ffe3f;  // srli a0,a1,0x1
        vi[19] = 32'h41f5d513; ve[19] = 21'h10b800; vm[19] = 21'h1ffe3f;  // srai a0,a1,0x1f
        vi[20] = 32'hffc58503; ve[20] = 21'h108410; vm[20] = 21'h1fffff;  // lb a0,-4(a1)
        vi[21] = 32'h00259503; ve[21] = 21'h108450; vm[21] = 21'h1fffff;  // lh a0,2(a1)
        vi[22] = 32'h0005a503; ve[22] = 21'h108490; vm[22] = 21'h1fffff;  // lw a0,0(a1)
        vi[23] = 32'h0015c503; ve[23] = 21'h108510; vm[23] = 21'h1fffff;  // lbu a0,1(a1)
        vi[24] = 32'h0065d503; ve[24] = 21'h108550; vm[24] = 21'h1fffff;  // lhu a0,6(a1)
        vi[25] = 32'hfec58fa3; ve[25] = 21'h028200; vm[25] = 21'h1fffcf;  // sb a2,-1(a1)
        vi[26] = 32'h00c59123; ve[26] = 21'h028240; vm[26] = 21'h1fffcf;  // sh a2,2(a1)
        vi[27] = 32'hfcc5a223; ve[27] = 21'h028280; vm[27] = 21'h1fffcf;  // sw a2,-60(a1)
        vi[28] = 32'hf8b508e3; ve[28] = 21'h040008; vm[28] = 21'h1e060f;  // beq a0,a1,0 <l>
        vi[29] = 32'hf8b516e3; ve[29] = 21'h040008; vm[29] = 21'h1e060f;  // bne a0,a1,0 <l>
        vi[30] = 32'hf8b544e3; ve[30] = 21'h040008; vm[30] = 21'h1e060f;  // blt a0,a1,0 <l>
        vi[31] = 32'hf8b552e3; ve[31] = 21'h040008; vm[31] = 21'h1e060f;  // bge a0,a1,0 <l>
        vi[32] = 32'hf8b560e3; ve[32] = 21'h040008; vm[32] = 21'h1e060f;  // bltu a0,a1,0 <l>
        vi[33] = 32'hf6b57ee3; ve[33] = 21'h040008; vm[33] = 21'h1e060f;  // bgeu a0,a1,0 <l>
        vi[34] = 32'h80000537; ve[34] = 21'h160030; vm[34] = 21'h1e063f;  // lui a0,0x80000
        vi[35] = 32'h12345517; ve[35] = 21'h178000; vm[35] = 21'h1ffe3f;  // auipc a0,0x12345
        vi[36] = 32'hf71ff0ef; ve[36] = 21'h180024; vm[36] = 21'h1e063f;  // jal ra,0 <l>
        vi[37] = 32'hff8580e7; ve[37] = 21'h108022; vm[37] = 21'h1ffe3f;  // jalr ra,-8(a1)
        vi[38] = 32'h0ff0000f; ve[38] = 21'h000000; vm[38] = 21'h10060f;  // fence iorw,iorw
        vi[39] = 32'h00000073; ve[39] = 21'h000001; vm[39] = 21'h10060f;  // ecall
        vi[40] = 32'h00100073; ve[40] = 21'h000001; vm[40] = 21'h10060f;  // ebreak
        vi[41] = 32'h00000000; ve[41] = 21'h000001; vm[41] = 21'h10060f;  // all zero
        vi[42] = 32'hffffffff; ve[42] = 21'h000001; vm[42] = 21'h10060f;  // all one
        vi[43] = 32'h02c58533; ve[43] = 21'h000001; vm[43] = 21'h10060f;  // mul (M ext)
        vi[44] = 32'h20c58533; ve[44] = 21'h000001; vm[44] = 21'h10060f;  // add with bad funct7
        vi[45] = 32'h40c5c533; ve[45] = 21'h000001; vm[45] = 21'h10060f;  // xor with funct7=0100000
        vi[46] = 32'h02059513; ve[46] = 21'h000001; vm[46] = 21'h10060f;  // slli shamt[5]=1 (RV64)
        vi[47] = 32'h40059513; ve[47] = 21'h000001; vm[47] = 21'h10060f;  // slli with funct7=0100000
        vi[48] = 32'h2015d513; ve[48] = 21'h000001; vm[48] = 21'h10060f;  // srli bad funct7
        vi[49] = 32'h0005b503; ve[49] = 21'h000001; vm[49] = 21'h10060f;  // ld (RV64)
        vi[50] = 32'h0005e503; ve[50] = 21'h000001; vm[50] = 21'h10060f;  // load funct3=110
        vi[51] = 32'h00c5b023; ve[51] = 21'h000001; vm[51] = 21'h10060f;  // sd (RV64)
        vi[52] = 32'h00c5c023; ve[52] = 21'h000001; vm[52] = 21'h10060f;  // store funct3=100
        vi[53] = 32'h00b52063; ve[53] = 21'h000001; vm[53] = 21'h10060f;  // branch funct3=010
        vi[54] = 32'h000590e7; ve[54] = 21'h000001; vm[54] = 21'h10060f;  // jalr funct3=001
        vi[55] = 32'h0000100f; ve[55] = 21'h000001; vm[55] = 21'h10060f;  // fence.i (Zifencei)
        vi[56] = 32'h30529073; ve[56] = 21'h000001; vm[56] = 21'h10060f;  // csrw mtvec (Zicsr)
        vi[57] = 32'h30200073; ve[57] = 21'h000001; vm[57] = 21'h10060f;  // mret
        vi[58] = 32'h00000012; ve[58] = 21'h000001; vm[58] = 21'h10060f;  // opcode low bits 10 (compressed)
        vi[59] = 32'h0000000b; ve[59] = 21'h000001; vm[59] = 21'h10060f;  // custom-0 opcode
    end

    initial begin
        errors = 0;
        #1;
        for (k = 0; k < N; k = k + 1) begin
            inst = vi[k];
            #1;
            if ((sig & vm[k]) !== (ve[k] & vm[k])) begin
                $display("FAIL: vec %0d inst=%h sig=%b expected=%b mask=%b", k, inst, sig, ve[k], vm[k]);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("PASS: %0d instructions", N);
        else             $display("FAIL: %0d / %0d instructions", errors, N);
        $finish;
    end
endmodule
