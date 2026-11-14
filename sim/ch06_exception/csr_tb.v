`timescale 1ns/1ps
// Self-checking testbench for csr.v (03_chapters/ch06_exception/design.md sec. 3, 4)
//  Directed checks, one instruction per clock (the testbench plays the core):
//   1 CSR read/write/set/clear (register and immediate forms), x0 forms that must not write
//   2 fixed fields: misa, mstatus.MPP = 11, mtvec MODE = 0, mepc[1:0] = 0, IDs, mip writes ignored
//   3 illegal: nonexistent CSR, write to a read-only CSR (csrrs x0 to it is legal)
//   4 trap entry for every exception cause: mepc, mcause, mtval, MIE -> MPIE; priority of causes
//   5 mret: MIE <- MPIE, MPIE <- 1
//   6 interrupts: need MIE and mie bit, external before timer, not taken while stalled or on a memory
//     instruction, taken before an illegal instruction
//   7 counters: mcycle every clock, minstret on retire only, CSR write wins over the increment
module csr_tb;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    reg  [31:0] pc, inst, csr_src, jmp_target, mem_addr;
    reg         stall, mem_op, csr_en;
    reg         e_fetch, e_ill, e_ecall, e_ebreak, e_jmp, e_ldm, e_stm, e_ldf, e_stf, is_mret;
    reg         irq_timer, irq_ext;
    wire [31:0] csr_rdata, trap_pc, mepc_pc;
    wire        trap, trap_is_irq, exc_taken, mret_take, retire;

    csr dut (
        .clk(clk), .rst_n(rst_n), .pc(pc), .inst(inst), .stall(stall), .mem_op(mem_op),
        .csr_en(csr_en), .csr_src(csr_src), .csr_rdata(csr_rdata),
        .exc_fetch_fault(e_fetch), .exc_illegal(e_ill), .exc_ecall(e_ecall), .exc_ebreak(e_ebreak),
        .exc_jmp_misalign(e_jmp), .jmp_target(jmp_target),
        .exc_ld_misalign(e_ldm), .exc_st_misalign(e_stm), .exc_ld_fault(e_ldf), .exc_st_fault(e_stf),
        .mem_addr(mem_addr), .is_mret(is_mret), .irq_timer(irq_timer), .irq_ext(irq_ext),
        .trap(trap), .trap_is_irq(trap_is_irq), .exc_taken(exc_taken), .trap_pc(trap_pc),
        .mret_take(mret_take), .mepc_pc(mepc_pc), .retire(retire)
    );

    integer errors = 0, checks = 0;
    task check(input [8*48:1] what, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("ERROR: %0s: got %h expected %h", what, got, exp);
            end
        end
    endtask

    task idle;   // nothing special in this cycle (a plain ALU instruction)
        begin
            inst = 32'h0000_0013; csr_en = 0; csr_src = 0; stall = 0; mem_op = 0;
            e_fetch = 0; e_ill = 0; e_ecall = 0; e_ebreak = 0; e_jmp = 0;
            e_ldm = 0; e_stm = 0; e_ldf = 0; e_stf = 0; is_mret = 0;
        end
    endtask

    // CSR instruction encodings: csrrw=001 csrrs=010 csrrc=011, +4 for the immediate forms
    function [31:0] enc(input [11:0] a, input [2:0] f3, input [4:0] rs1, input [4:0] rd);
        enc = {a, rs1, f3, rd, 7'b1110011};
    endfunction

    // Execute one CSR instruction at the next edge; returns the old value seen before the edge
    reg [31:0] old;
    task csrop(input [11:0] a, input [2:0] f3, input [4:0] rs1, input [31:0] src);
        begin
            @(negedge clk);
            idle; inst = enc(a, f3, rs1, 5'd1); csr_en = 1; csr_src = src;
            #1 old = csr_rdata;
            @(posedge clk); #1;
            @(negedge clk); idle;
        end
    endtask
    task rd(input [11:0] a, output [31:0] v);     // csrrs rd, a, x0
        begin
            @(negedge clk); idle; inst = enc(a, 3'b010, 5'd0, 5'd1); csr_en = 1;
            #1 v = csr_rdata;
            @(posedge clk); #1; @(negedge clk); idle;
        end
    endtask

    // one cycle with the given exception flags set; checks that a trap is taken and the CSR effects
    task exc(input [8*24:1] name, input integer which, input [4:0] cause, input [31:0] tval);
        reg [31:0] v;
        begin
            @(negedge clk); idle; pc = 32'h0000_0100 + which * 4; inst = 32'hDEAD_0003 + which;
            jmp_target = 32'h0000_0222; mem_addr = 32'h1000_0013;
            case (which)
                0: e_fetch = 1; 1: e_ill = 1; 2: e_ebreak = 1; 3: e_ecall = 1; 4: e_jmp = 1;
                5: begin e_ldm = 1; mem_op = 1; end 6: begin e_stm = 1; mem_op = 1; end
                7: begin e_ldf = 1; mem_op = 1; end default: begin e_stf = 1; mem_op = 1; end
            endcase
            #1 check({name, " trap"}, {exc_taken, trap_is_irq, trap, retire}, 4'b1010);
            @(posedge clk); #1; @(negedge clk); idle;
            rd(12'h341, v); check({name, " mepc"},   v, 32'h0000_0100 + which * 4);
            rd(12'h342, v); check({name, " mcause"}, v, {27'd0, cause});
            rd(12'h343, v); check({name, " mtval"},  v, tval);
        end
    endtask

    reg [31:0] v, w;
    integer i;
    initial begin
        pc = 32'h0000_0100; jmp_target = 0; mem_addr = 0; irq_timer = 0; irq_ext = 0;
        idle;
        #22 rst_n = 1;

        // ---- 1 read / write / set / clear ----
        csrop(12'h340, 3'b001, 5'd5, 32'h1234_5678);          // csrrw mscratch, x5
        csrop(12'h340, 3'b010, 5'd5, 32'h0000_00F0);          // csrrs
        check("csrrw old", old, 32'h1234_5678);
        csrop(12'h340, 3'b011, 5'd5, 32'h1200_0008);          // csrrc
        check("csrrs old", old, 32'h1234_56F8);
        rd(12'h340, v); check("csrrc result", v, 32'h0034_56F0);
        csrop(12'h340, 3'b101, 5'd31, 32'd31);                // csrrwi mscratch, 31
        rd(12'h340, v); check("csrrwi", v, 32'd31);
        csrop(12'h340, 3'b110, 5'd0, 32'd0);                  // csrrsi with uimm 0: read only
        csrop(12'h340, 3'b011, 5'd0, 32'hFFFF_FFFF);          // csrrc with x0: no write even if src != 0
        rd(12'h340, v); check("x0 forms do not write", v, 32'd31);

        // ---- 2 fixed fields ----
        rd(12'h301, v); check("misa", v, 32'h4000_0100);
        csrop(12'h300, 3'b001, 5'd5, 32'hFFFF_FFFF);          // mstatus all ones
        rd(12'h300, v); check("mstatus WARL", v, 32'h0000_1888);
        csrop(12'h300, 3'b001, 5'd5, 32'd0);
        rd(12'h300, v); check("mstatus MPP stays 11", v, 32'h0000_1800);
        csrop(12'h305, 3'b001, 5'd5, 32'h0000_0403);
        rd(12'h305, v); check("mtvec MODE 0", v, 32'h0000_0400);
        check("trap_pc", trap_pc, 32'h0000_0400);
        csrop(12'h341, 3'b001, 5'd5, 32'h0000_0123);
        rd(12'h341, v); check("mepc[1:0] = 0", v, 32'h0000_0120);
        rd(12'hF14, v); check("mhartid", v, 32'd0);
        csrop(12'h344, 3'b001, 5'd5, 32'hFFFF_FFFF);          // mip: no writable bits
        rd(12'h344, v); check("mip write ignored", v, 32'd0);

        // ---- 3 illegal CSR accesses ----
        @(negedge clk); idle; inst = enc(12'h7C0, 3'b001, 5'd5, 5'd1); csr_en = 1;   // nonexistent
        #1 check("nonexistent CSR -> trap", {exc_taken, retire}, 2'b10);
        @(negedge clk); idle; inst = enc(12'hF11, 3'b001, 5'd5, 5'd1); csr_en = 1;   // write mvendorid
        #1 check("write read-only -> trap", {exc_taken, retire}, 2'b10);
        @(negedge clk); idle; inst = enc(12'hC00, 3'b010, 5'd0, 5'd1); csr_en = 1;   // rdcycle (no write)
        #1 check("read read-only -> no trap", {exc_taken, retire}, 2'b01);
        @(negedge clk); idle; inst = enc(12'hC00, 3'b110, 5'd0, 5'd1); csr_en = 1;   // csrrsi 0
        #1 check("csrrsi 0 read-only -> no trap", {exc_taken, retire}, 2'b01);
        @(negedge clk); idle;
        rd(12'h342, v); check("illegal CSR mcause", v, 32'd2);
        rd(12'h343, v); check("illegal CSR mtval = inst", v, enc(12'hF11, 3'b001, 5'd5, 5'd1));  // last trap
        // the illegal writes did not change anything
        rd(12'h340, v); check("mscratch kept", v, 32'd31);

        // ---- 4 exceptions: cause and mtval ----
        exc("fetch fault",     0, 5'd1, 32'h0000_0100);
        exc("illegal",         1, 5'd2, 32'hDEAD_0004);
        exc("ebreak",          2, 5'd3, 32'd0);
        exc("ecall",           3, 5'd11, 32'd0);
        exc("jump misaligned", 4, 5'd0, 32'h0000_0222);
        exc("load misaligned", 5, 5'd4, 32'h1000_0013);
        exc("store misaligned",6, 5'd6, 32'h1000_0013);
        exc("load fault",      7, 5'd5, 32'h1000_0013);
        exc("store fault",     8, 5'd7, 32'h1000_0013);
        // priority: illegal + load fault together -> illegal
        @(negedge clk); idle; e_ill = 1; e_ldf = 1; mem_op = 1;
        @(posedge clk); #1; @(negedge clk); idle;
        rd(12'h342, v); check("priority illegal > fault", v, 32'd2);
        // fetch fault + ecall -> fetch fault
        @(negedge clk); idle; e_fetch = 1; e_ecall = 1;
        @(posedge clk); #1; @(negedge clk); idle;
        rd(12'h342, v); check("priority fetch > ecall", v, 32'd1);
        // a stalled cycle never traps
        @(negedge clk); idle; e_ldf = 1; mem_op = 1; stall = 1;
        #1 check("no trap while stalled", {trap, retire}, 2'b00);

        // ---- 5 mstatus stack on trap and mret ----
        csrop(12'h300, 3'b001, 5'd5, 32'h0000_0008);          // MIE = 1, MPIE = 0
        @(negedge clk); idle; e_ecall = 1;
        @(posedge clk); #1; @(negedge clk); idle;
        rd(12'h300, v); check("trap: MPIE <- 1, MIE <- 0", v, 32'h0000_1880);
        @(negedge clk); idle; is_mret = 1;
        #1 check("mret_take", {mret_take, mepc_pc[31:0] != 0}, 2'b11);
        @(posedge clk); #1; @(negedge clk); idle;
        rd(12'h300, v); check("mret: MIE <- MPIE, MPIE <- 1", v, 32'h0000_1888);
        csrop(12'h300, 3'b001, 5'd5, 32'h0000_0000);          // MIE = 0, MPIE = 0
        @(negedge clk); idle; is_mret = 1; @(posedge clk); #1; @(negedge clk); idle;
        rd(12'h300, v); check("mret with MPIE = 0: MIE 0, MPIE 1", v, 32'h0000_1880);
        csrop(12'h300, 3'b001, 5'd5, 32'h0000_0008);          // back to MIE = 1 for the next part

        // ---- 6 interrupts ----
        csrop(12'h304, 3'b001, 5'd5, 32'h0000_0000);          // mie = 0
        irq_timer = 1; irq_ext = 1;
        @(negedge clk); idle; #1 check("no irq when mie = 0", trap, 1'b0);
        rd(12'h344, v); check("mip shows MEIP MTIP", v, 32'h0000_0880);
        irq_timer = 0; irq_ext = 0;                           // (every idle cycle is an instruction:
        csrop(12'h304, 3'b001, 5'd5, 32'h0000_0880);          //  raise the requests only in the test cycle)
        @(negedge clk); idle; mem_op = 1; irq_timer = 1; irq_ext = 1;
        #1 check("no irq on a memory instruction", trap, 1'b0);
        stall = 1; #1 check("no irq while stalled", trap, 1'b0);
        stall = 0; mem_op = 0; e_ill = 1; pc = 32'h0000_0300;
        #1 check("irq before illegal instr", {trap_is_irq, exc_taken, retire}, 3'b100);
        @(posedge clk); #1; @(negedge clk); idle;
        rd(12'h342, v); check("external first", v, 32'h8000_000B);
        rd(12'h341, v); check("irq mepc = pc", v, 32'h0000_0300);
        @(negedge clk); idle; #1 check("MIE cleared by trap", trap, 1'b0);
        irq_timer = 0; irq_ext = 0;
        @(negedge clk); idle; is_mret = 1; @(posedge clk); #1; @(negedge clk); idle;   // MIE back on
        irq_timer = 1;
        #1 check("timer irq", trap_is_irq, 1'b1);
        @(posedge clk); #1; @(negedge clk); idle;
        rd(12'h342, v); check("timer cause", v, 32'h8000_0007);
        irq_timer = 0;
        csrop(12'h300, 3'b001, 5'd5, 32'h0000_0000);

        // ---- 7 counters ----
        // rd() reads in one cycle and is followed by one idle instruction: 2 cycles, 2 retires apart
        rd(12'hB00, v); rd(12'hB00, w);
        check("mcycle +2", w - v, 32'd2);
        rd(12'hB02, v); rd(12'hB02, w);
        check("minstret +2", w - v, 32'd2);
        csrop(12'hB00, 3'b001, 5'd5, 32'hFFFF_FFFF);          // mcycle low = all ones
        csrop(12'hB80, 3'b001, 5'd5, 32'h0000_0010);          // mcycleh = 0x10 (low went 0xFFFFFFFF+2)
        rd(12'hB80, v); check("mcycleh write replaces the carry", v, 32'h0000_0010);
        csrop(12'hB02, 3'b001, 5'd5, 32'h0000_0100);          // minstret = 0x100 (write wins, no +1)
        rd(12'hB02, v); check("minstret write wins (+1 idle)", v, 32'h0000_0101);
        rd(12'hC02, w); check("instret alias", w, 32'h0000_0103);
        // stalled / trapping cycles do not retire
        rd(12'hB02, v);
        @(negedge clk); idle; mem_op = 1; stall = 1; @(posedge clk); #1;
        @(negedge clk); idle; e_ill = 1; @(posedge clk); #1;
        @(negedge clk); idle;
        rd(12'hB02, w); check("no retire on stall / trap", w - v, 32'd3);   // rd, idle, idle (not 5)

        if (errors == 0) $display("PASS: csr (%0d checks)", checks);
        else             $display("FAIL: csr (%0d errors / %0d checks)", errors, checks);
        $finish;
    end

    initial begin #200000; $display("FAIL: timeout"); $finish; end
endmodule
