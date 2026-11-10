`timescale 1ns/1ps

// Load/Store 유닛 — CPU 코어 안에서 load·store의 바이트 처리를 맡는다 (decode.md 6절)
//  - 메모리(dmem)는 워드 단위 RAM일 뿐이고, 바이트 위치 계산·부호 확장·정렬 검사는 여기서 한다
//    → 합성할 때 코어만 떼어 내도 load/store 로직이 코어에 포함된다 (MCU 단계에서 버스에 그대로 연결)
//  - 조합 회로만 있다 (클럭 없음)
//  - 정렬 안 된 접근(하프워드는 2의 배수, 워드는 4의 배수 주소가 아님)은 misaligned = 1,
//    이때 dmem_wstrb = 0 이라 메모리에 쓰지 않는다. 3단계에서는 테스트벤치가 멈추고, 6장에서 예외로 바꾼다
module lsu (
    input             mem_re,           // 제어 유닛 출력
    input             mem_we,
    input      [2:0]  mem_size,         // = funct3: 000 b, 001 h, 010 w, 100 bu, 101 hu
    input      [31:0] addr,             // 최상위 alu_result (rs1 + imm)
    input      [31:0] wdata,            // 최상위 rs2_data
    output reg [31:0] rdata,            // 최상위 mem_rdata (확장까지 끝난 값)
    output            misaligned,       // 최상위 mem_misaligned
    // 메모리 쪽 (워드 단위)
    output reg [3:0]  dmem_wstrb,       // 쓸 바이트 (0이면 쓰기 없음)
    output reg [31:0] dmem_wdata,       // 바이트 위치로 복제한 쓰기 데이터
    input      [31:0] dmem_rdata        // 메모리에서 읽은 워드 그대로
);
    wire [1:0] boff = addr[1:0];        // 워드 안의 바이트 위치

    // ── 정렬 검사 ──
    wire is_half = (mem_size[1:0] == 2'b01);
    wire is_word = (mem_size[1:0] == 2'b10);
    assign misaligned = (mem_re | mem_we) &
                        ((is_half & boff[0]) | (is_word & (boff != 2'b00)));

    // ── store: 바이트 쓰기 신호(wstrb)와 바이트 위치로 복제한 쓰기 데이터 ──
    reg [3:0] wstrb;
    always @(*) begin
        case (mem_size[1:0])
            2'b00:   begin wstrb = 4'b0001 << boff;            dmem_wdata = {4{wdata[7:0]}};  end  // sb
            2'b01:   begin wstrb = 4'b0011 << {boff[1], 1'b0}; dmem_wdata = {2{wdata[15:0]}}; end  // sh
            default: begin wstrb = 4'b1111;                    dmem_wdata = wdata;            end  // sw
        endcase
        dmem_wstrb = (mem_we && !misaligned) ? wstrb : 4'b0000;
    end

    // ── load: 워드에서 바이트·하프워드를 골라 부호 확장(lb·lh) 또는 0 확장(lbu·lhu) ──
    wire [7:0]  byte_sel = dmem_rdata >> {boff, 3'b000};          // boff × 8비트만큼 오른쪽으로
    wire [15:0] half_sel = boff[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];

    always @(*) begin
        case (mem_size)
            3'b000:  rdata = {{24{byte_sel[7]}},  byte_sel};   // lb
            3'b001:  rdata = {{16{half_sel[15]}}, half_sel};   // lh
            3'b100:  rdata = {24'd0, byte_sel};                // lbu
            3'b101:  rdata = {16'd0, half_sel};                // lhu
            default: rdata = dmem_rdata;                       // lw
        endcase
    end
endmodule
