`timescale 1ns/1ps
// Self-checking testbench for lsu + dmem (decode.md sec. 6)
// Connects lsu (byte handling, alignment check) to the plain word RAM dmem and checks the whole load/store behavior.
// A byte-level shadow table in the testbench is updated on every store and compared with load results.
// Checks
//  1) sw -> lw (64 words)
//  2) sb to all four byte lanes -> lb (sign extend) / lbu (zero extend)
//  3) sh to both halves -> lh / lhu
//  4) misaligned access: misaligned = 1 and a store does not change memory
//  5) no write when mem_we = 0
//  6) 4000 random stores/loads (aligned addresses)
module dmem_tb;
    localparam SB = 3'b000, SH = 3'b001, SW = 3'b010, LB = 3'b000, LH = 3'b001, LW = 3'b010, LBU = 3'b100, LHU = 3'b101;
    localparam SPAN = 512;                 // address range used by the test (bytes)

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

    wire [3:0]  dmem_wstrb;
    wire [31:0] dmem_wdata, dmem_rdata;

    lsu u_lsu (
        .mem_re(mem_re), .mem_we(mem_we), .mem_size(mem_size), .addr(addr), .wdata(wdata),
        .rdata(rdata), .misaligned(misaligned),
        .dmem_wstrb(dmem_wstrb), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata)
    );

    dmem #(.ADDR_BITS(13)) u_dmem (
        .clk(clk), .addr(addr), .wstrb(dmem_wstrb), .wdata(dmem_wdata), .rdata(dmem_rdata)
    );

    always #5 clk = ~clk;

    task fail(input [8*40:1] what, input [31:0] actual, input [31:0] expected);
        begin
            if (errors < 10)
                $display("FAIL: %0s addr=%h size=%b -> %h (expected %h) at %0t", what, addr, mem_size, actual, expected, $time);
            errors = errors + 1;
        end
    endtask

    // store: change inputs on the falling edge, write happens on the next rising edge
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

    // load: asynchronous read, so the value is ready shortly after the inputs change
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
        for (i = 0; i < SPAN; i = i + 4) store(SW, i, 32'h0);          // clear the test range

        // 1) sw -> lw
        for (i = 0; i < 256; i = i + 4) store(SW, i, 32'hA5000000 + i * 32'h0001_0103);
        for (i = 0; i < 256; i = i + 4) load(LW, i);

        // 2) sb to four lanes -> lb / lbu (values >= 0x80 expose sign-extension errors)
        store(SB, 32'h100, 32'hFFFF_FF81);
        store(SB, 32'h101, 32'h0000_007F);
        store(SB, 32'h102, 32'h1234_56C3);
        store(SB, 32'h103, 32'h0000_0000);
        for (i = 32'h100; i < 32'h104; i = i + 1) begin load(LB, i); load(LBU, i); end
        load(LW, 32'h100);

        // 3) sh to two positions -> lh / lhu
        store(SH, 32'h108, 32'h0000_8001);
        store(SH, 32'h10A, 32'hFFFF_7FFE);
        load(LH, 32'h108); load(LHU, 32'h108); load(LH, 32'h10A); load(LHU, 32'h10A); load(LW, 32'h108);

        // 4) misaligned access
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
        // a misaligned store must not change memory (shadow left unchanged, then checked)
        @(negedge clk); mem_we = 1; mem_size = SW; addr = 32'h102; wdata = 32'hDEAD_BEEF; #1;
        if (misaligned !== 1) fail("misaligned sw", misaligned, 1);
        @(posedge clk); #1; mem_we = 0;
        @(negedge clk); mem_we = 1; mem_size = SH; addr = 32'h109; wdata = 32'hDEAD_BEEF;
        @(posedge clk); #1; mem_we = 0;
        load(LW, 32'h100); load(LW, 32'h104); load(LW, 32'h108);

        // 5) no write when mem_we = 0
        @(negedge clk); mem_we = 0; mem_size = SW; addr = 32'h0; wdata = 32'hFFFF_FFFF;
        @(posedge clk); #1;
        load(LW, 32'h0);

        // 6) random stores/loads (aligned addresses)
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

        if (errors == 0) $display("PASS: lsu + dmem");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #1000000 $display("FAIL: timeout");
        $finish;
    end
endmodule
