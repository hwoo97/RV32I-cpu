`timescale 1ns/1ps

// 데이터 메모리 — 워드(32비트) 배열 + 바이트 단위 쓰기(wstrb) + load 값 추출·확장 (decode.md 6절)
//  - 읽기: 비동기 (단일 사이클 CPU는 같은 사이클에 주소 계산 → 읽기 → rd 쓰기까지 끝내야 함)
//  - 쓰기: clk 상승 에지, wstrb로 고른 바이트만
//  - 주소: addr의 아래 ADDR_BITS비트만 쓴다 (위 비트는 무시 → 메모리 크기만큼 반복되어 보임)
//  - 정렬 안 된 접근(하프워드는 2의 배수, 워드는 4의 배수 주소가 아님)은 misaligned = 1, 쓰기는 하지 않음
//    3단계에서는 테스트벤치가 멈추고, 6장에서 예외(trap)로 바꾼다
module dmem #(
    parameter ADDR_BITS = 13,           // 2^13 = 8 KB
    parameter INIT_FILE = ""            // $readmemh로 읽을 hex 파일 (워드 단위), 없으면 비워 둠
) (
    input             clk,
    input             mem_re,           // 제어 유닛 출력
    input             mem_we,
    input      [2:0]  mem_size,         // = funct3: 000 b, 001 h, 010 w, 100 bu, 101 hu
    input      [31:0] addr,             // 최상위 alu_result (rs1 + imm)
    input      [31:0] wdata,            // 최상위 rs2_data
    output reg [31:0] rdata,            // 최상위 mem_rdata (확장까지 끝난 값)
    output            misaligned
);
    localparam WORDS = 1 << (ADDR_BITS - 2);

    reg [31:0] mem [0:WORDS-1];

    initial
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    wire [ADDR_BITS-3:0] widx = addr[ADDR_BITS-1:2];   // 워드 번호
    wire [1:0]           boff = addr[1:0];             // 워드 안의 바이트 위치
    wire [31:0]          word = mem[widx];

    // ── 정렬 검사 ──
    wire is_half = (mem_size[1:0] == 2'b01);
    wire is_word = (mem_size[1:0] == 2'b10);
    assign misaligned = (mem_re | mem_we) &
                        ((is_half & boff[0]) | (is_word & (boff != 2'b00)));

    // ── store: 바이트 쓰기 신호(wstrb)와 바이트 위치로 옮긴 쓰기 데이터 ──
    reg [3:0]  wstrb;
    reg [31:0] wdata_sh;
    always @(*) begin
        case (mem_size[1:0])
            2'b00:   begin wstrb = 4'b0001 << boff;          wdata_sh = {4{wdata[7:0]}};  end  // sb
            2'b01:   begin wstrb = 4'b0011 << {boff[1], 1'b0}; wdata_sh = {2{wdata[15:0]}}; end  // sh
            default: begin wstrb = 4'b1111;                  wdata_sh = wdata;            end  // sw
        endcase
    end

    always @(posedge clk)
        if (mem_we && !misaligned) begin
            if (wstrb[0]) mem[widx][ 7: 0] <= wdata_sh[ 7: 0];
            if (wstrb[1]) mem[widx][15: 8] <= wdata_sh[15: 8];
            if (wstrb[2]) mem[widx][23:16] <= wdata_sh[23:16];
            if (wstrb[3]) mem[widx][31:24] <= wdata_sh[31:24];
        end

    // ── load: 워드에서 바이트·하프워드를 골라 부호 확장(lb·lh) 또는 0 확장(lbu·lhu) ──
    wire [7:0]  byte_sel = word >> {boff, 3'b000};          // boff × 8비트만큼 오른쪽으로
    wire [15:0] half_sel = boff[1] ? word[31:16] : word[15:0];

    always @(*) begin
        case (mem_size)
            3'b000:  rdata = {{24{byte_sel[7]}},  byte_sel};   // lb
            3'b001:  rdata = {{16{half_sel[15]}}, half_sel};   // lh
            3'b100:  rdata = {24'd0, byte_sel};                // lbu
            3'b101:  rdata = {16'd0, half_sel};                // lhu
            default: rdata = word;                             // lw
        endcase
    end
endmodule
