`timescale 1ns/1ps

// Load/Store unit - handles byte-level load/store processing inside the CPU core (decode.md sec. 6)
//  - dmem is just a word RAM; byte lane selection, sign extension and alignment check are done here
//    -> the load/store logic stays in the core when the core is synthesized alone (connects to the MCU bus as is)
//  - Combinational only (no clock)
//  - Misaligned access (halfword not on a 2-byte boundary, word not on a 4-byte boundary) gives misaligned = 1,
//    and dmem_wstrb = 0 so memory is not written. ch6: becomes a load/store address-misaligned exception
module lsu (
    input             mem_re,           // from control unit
    input             mem_we,
    input      [2:0]  mem_size,         // = funct3: 000 b, 001 h, 010 w, 100 bu, 101 hu
    input      [31:0] addr,             // top-level alu_result (rs1 + imm)
    input      [31:0] wdata,            // top-level rs2_data
    output reg [31:0] rdata,            // top-level mem_rdata (already extended)
    output            misaligned,       // top-level mem_misaligned
    // Memory side (word based)
    output reg [3:0]  dmem_wstrb,       // bytes to write (0 = no write)
    output reg [31:0] dmem_wdata,       // write data replicated to the byte lanes
    input      [31:0] dmem_rdata        // raw word read from memory
);
    wire [1:0] boff = addr[1:0];        // byte offset within the word

    // -- Alignment check --
    wire is_half = (mem_size[1:0] == 2'b01);
    wire is_word = (mem_size[1:0] == 2'b10);
    assign misaligned = (mem_re | mem_we) &
                        ((is_half & boff[0]) | (is_word & (boff != 2'b00)));

    // -- Store: byte write enables (wstrb) and write data replicated to the byte lanes --
    reg [3:0] wstrb;
    always @(*) begin
        case (mem_size[1:0])
            2'b00:   begin wstrb = 4'b0001 << boff;            dmem_wdata = {4{wdata[7:0]}};  end  // sb
            2'b01:   begin wstrb = 4'b0011 << {boff[1], 1'b0}; dmem_wdata = {2{wdata[15:0]}}; end  // sh
            default: begin wstrb = 4'b1111;                    dmem_wdata = wdata;            end  // sw
        endcase
        dmem_wstrb = (mem_we && !misaligned) ? wstrb : 4'b0000;
    end

    // -- Load: pick byte/halfword from the word, sign-extend (lb/lh) or zero-extend (lbu/lhu) --
    wire [7:0]  byte_sel = dmem_rdata >> {boff, 3'b000};          // shift right by boff x 8 bits
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
