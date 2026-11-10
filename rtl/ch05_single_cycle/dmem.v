`timescale 1ns/1ps

// 데이터 메모리 — 워드(32비트) 배열 + 바이트 단위 쓰기(wstrb)만 하는 단순 RAM
//  - 바이트 위치 계산·부호 확장·정렬 검사는 코어 안의 lsu가 한다 (decode.md 6절)
//  - 읽기: 비동기 (단일 사이클 CPU는 같은 사이클에 주소 계산 → 읽기 → rd 쓰기까지 끝내야 함)
//  - 쓰기: clk 상승 에지, wstrb로 고른 바이트만 (wstrb = 0이면 쓰지 않음)
//  - 주소: addr의 아래 ADDR_BITS비트만 쓴다 (위 비트는 무시 → 메모리 크기만큼 반복되어 보임)
//  - 합성 대상이 아니다 (시뮬레이션·FPGA용). ASIC 합성은 코어(rv32i_core)만 한다
module dmem #(
    parameter ADDR_BITS = 13,           // 2^13 = 8 KB
    parameter INIT_FILE = ""            // $readmemh로 읽을 hex 파일 (워드 단위), 없으면 비워 둠
) (
    input         clk,
    input  [31:0] addr,                 // 코어 dmem_addr
    input  [3:0]  wstrb,                // 코어 dmem_wstrb
    input  [31:0] wdata,                // 코어 dmem_wdata
    output [31:0] rdata                 // 코어 dmem_rdata (워드 그대로)
);
    localparam WORDS = 1 << (ADDR_BITS - 2);

    reg [31:0] mem [0:WORDS-1];

    initial
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    wire [ADDR_BITS-3:0] widx = addr[ADDR_BITS-1:2];   // 워드 번호

    always @(posedge clk) begin
        if (wstrb[0]) mem[widx][ 7: 0] <= wdata[ 7: 0];
        if (wstrb[1]) mem[widx][15: 8] <= wdata[15: 8];
        if (wstrb[2]) mem[widx][23:16] <= wdata[23:16];
        if (wstrb[3]) mem[widx][31:24] <= wdata[31:24];
    end

    assign rdata = mem[widx];
endmodule
