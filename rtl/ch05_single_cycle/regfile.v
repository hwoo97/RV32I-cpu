`timescale 1ns/1ps

// 레지스터 파일 — 32비트 레지스터 32개 (x0 ~ x31)
//  - 읽기 포트 2개: 비동기 (주소가 바뀌면 바로 값이 나옴, 조합 회로)
//  - 쓰기 포트 1개: 동기 (clk 상승 에지에서 reg_we = 1일 때 rd_addr에 rd_data를 씀)
//  - x0은 항상 0: 읽으면 0, 써도 무시 → 실제 저장 공간은 x1 ~ x31의 31개만 둔다
//  - 리셋 없음: RISC-V는 레지스터 초기값을 정하지 않는다 (시작 코드가 0으로 채움)
module regfile (
    input         clk,
    input         reg_we,     // 제어 유닛 출력
    input  [4:0]  rs1_addr,   // inst[19:15]
    input  [4:0]  rs2_addr,   // inst[24:20]
    input  [4:0]  rd_addr,    // inst[11:7]
    input  [31:0] rd_data,    // 최상위 wb_data
    output [31:0] rs1_data,
    output [31:0] rs2_data
);
    reg [31:0] regs [1:31];

    // 쓰기: 한 사이클에 한 번, 클럭 상승 에지에서
    always @(posedge clk)
        if (reg_we && rd_addr != 5'd0)
            regs[rd_addr] <= rd_data;

    // 읽기: x0이면 0, 아니면 저장된 값 (같은 사이클에 쓰는 값은 다음 사이클부터 보임)
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];
endmodule
