`timescale 1ns/1ps

// 명령어 메모리 — 읽기 전용, 비동기 읽기 (단일 사이클 CPU는 같은 사이클에 명령어를 가져와 실행)
//  - 워드(32비트) 배열, 주소의 아래 2비트는 무시 (명령어는 항상 4바이트 정렬)
//  - 내용은 INIT_FILE($readmemh, 워드 단위 hex) 또는 테스트벤치가 직접 채운다
module imem #(
    parameter ADDR_BITS = 13,       // 2^13 = 8 KB
    parameter INIT_FILE = ""
) (
    input  [31:0] addr,             // 최상위 pc
    output [31:0] inst
);
    localparam WORDS = 1 << (ADDR_BITS - 2);

    reg [31:0] mem [0:WORDS-1];

    initial
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    assign inst = mem[addr[ADDR_BITS-1:2]];
endmodule
