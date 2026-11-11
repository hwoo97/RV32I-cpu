`timescale 1ns/1ps
// Self-checking testbench for apb_gpio (03_chapters/ch14a_mcu/design.md sec. 5.1)
//  - Two instances on one APB bus: GPIO_W = 16 (default) and GPIO_W = 32 (full width)
//  - APB master tasks from apb_master.vh
// Checks
//  1) reset values (registers and pins)
//  2) DATA_OUT / DIR write and read back (upper bits beyond GPIO_W read 0), pins follow
//  3) DATA_IN through the 2-flop synchronizer: old value for 2 rising edges, then the new one
//  4) errors: write to DATA_IN, unknown offsets -> PSLVERR, nothing changes, read 0
//  5) SETUP without ACCESS (psel without penable) must not write
//  6) every transfer takes 2 cycles (no wait states)
//  7) 3000 random accesses compared with a reference model
module gpio_tb;
    reg         clk = 0, presetn = 0;
    reg         psel = 0, penable = 0, pwrite = 0;
    reg  [31:0] paddr = 0, pwdata = 0;
    wire [31:0] prdata;
    wire        pready, pslverr;
    always #5 clk = ~clk;

    `include "apb_master.vh"

    // instance select: paddr[12] = 0 -> 16-bit GPIO, 1 -> 32-bit GPIO (test bus only)
    wire        sel_b = paddr[12];
    wire [31:0] prdata_a, prdata_b;
    wire        pready_a, pready_b, pslverr_a, pslverr_b;
    reg  [31:0] pins_in = 0;
    wire [15:0] out_a, oe_a;
    wire [31:0] out_b, oe_b;

    apb_gpio #(.GPIO_W(16)) dut_a (
        .pclk(clk), .presetn(presetn),
        .psel(psel & ~sel_b), .penable(penable), .pwrite(pwrite), .paddr(paddr[11:0]), .pwdata(pwdata),
        .prdata(prdata_a), .pready(pready_a), .pslverr(pslverr_a),
        .gpio_in(pins_in[15:0]), .gpio_out(out_a), .gpio_oe(oe_a)
    );
    apb_gpio #(.GPIO_W(32)) dut_b (
        .pclk(clk), .presetn(presetn),
        .psel(psel & sel_b), .penable(penable), .pwrite(pwrite), .paddr(paddr[11:0]), .pwdata(pwdata),
        .prdata(prdata_b), .pready(pready_b), .pslverr(pslverr_b),
        .gpio_in(pins_in), .gpio_out(out_b), .gpio_oe(oe_b)
    );
    assign prdata  = sel_b ? prdata_b  : prdata_a;
    assign pready  = sel_b ? pready_b  : pready_a;
    assign pslverr = sel_b ? pslverr_b : pslverr_a;

    integer errors = 0, nops = 0;
    task fail(input [8*50:1] what, input [31:0] a, input [31:0] got, input [31:0] exp);
        begin
            if (errors < 10) $display("FAIL: %0s addr=%h got %h expected %h at %0t", what, a, got, exp, $time);
            errors = errors + 1;
        end
    endtask

    // -- reference model --
    reg [31:0] r_out [0:1], r_dir [0:1];
    function [31:0] wmask(input b);
        wmask = b ? 32'hFFFF_FFFF : 32'h0000_FFFF;
    endfunction

    reg [31:0] rd; reg er;
    task do_write(input [31:0] a, input [31:0] d);
        reg b, expe;
        begin
            b = a[12];
            expe = !(a[11:0] == 12'h000 || a[11:0] == 12'h008);     // DATA_IN or unknown -> error
            apb_write(a, d, er);
            if (er !== expe) fail("pslverr on write", a, er, expe);
            if (apb_cycles != 2) fail("write cycles", a, apb_cycles, 2);
            if (a[11:0] == 12'h000) r_out[b] = d & wmask(b);
            if (a[11:0] == 12'h008) r_dir[b] = d & wmask(b);
            nops = nops + 1;
        end
    endtask

    task do_read(input [31:0] a, input [31:0] exp_in);
        reg b, expe; reg [31:0] expd;
        begin
            b = a[12];
            expe = 0;
            case (a[11:0])
                12'h000: expd = r_out[b];
                12'h004: expd = exp_in & wmask(b);
                12'h008: expd = r_dir[b];
                default: begin expd = 0; expe = 1; end
            endcase
            apb_read(a, rd, er);
            if (er !== expe) fail("pslverr on read", a, er, expe);
            if (rd !== expd) fail("read data", a, rd, expd);
            if (apb_cycles != 2) fail("read cycles", a, apb_cycles, 2);
            nops = nops + 1;
        end
    endtask

    task check_pins;
        begin
            if (out_a !== r_out[0][15:0]) fail("gpio_out (16)", 0, out_a, r_out[0]);
            if (oe_a  !== r_dir[0][15:0]) fail("gpio_oe (16)",  0, oe_a,  r_dir[0]);
            if (out_b !== r_out[1])       fail("gpio_out (32)", 0, out_b, r_out[1]);
            if (oe_b  !== r_dir[1])       fail("gpio_oe (32)",  0, oe_b,  r_dir[1]);
        end
    endtask

    integer t, seed;
    reg [31:0] a, d;
    initial begin
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        r_out[0] = 0; r_out[1] = 0; r_dir[0] = 0; r_dir[1] = 0;
        pins_in = 32'h0;
        #12 presetn = 1;

        // 1) reset values
        do_read(32'h0000, 0); do_read(32'h0008, 0); do_read(32'h0004, 0);
        do_read(32'h1000, 0); do_read(32'h1008, 0); do_read(32'h1004, 0);
        check_pins;

        // 2) write / read back, upper bits masked
        do_write(32'h0000, 32'hFFFF_A5C3); do_read(32'h0000, 0);
        do_write(32'h0008, 32'h1234_00FF); do_read(32'h0008, 0);
        do_write(32'h1000, 32'hFFFF_A5C3); do_read(32'h1000, 0);
        do_write(32'h1008, 32'h8000_0001); do_read(32'h1008, 0);
        check_pins;

        // 3) input synchronizer: change pins at a falling edge, count rising edges
        @(negedge clk); pins_in = 32'hDEAD_BEEF;
        @(posedge clk); #1;
        if (dut_a.in_sync !== 16'h0000) fail("sync after 1 edge (must be old)", 0, dut_a.in_sync, 0);
        @(posedge clk); #1;
        if (dut_a.in_sync !== 16'hBEEF) fail("sync after 2 edges (must be new)", 0, dut_a.in_sync, 16'hBEEF);
        do_read(32'h0004, 32'hDEAD_BEEF); do_read(32'h1004, 32'hDEAD_BEEF);

        // 4) errors: write to read-only DATA_IN, unknown offsets
        do_write(32'h0004, 32'hFFFF_FFFF);
        do_write(32'h000C, 32'hFFFF_FFFF); do_read(32'h000C, 0);
        do_write(32'h0FFC, 32'hFFFF_FFFF); do_read(32'h0FFC, 0);
        do_write(32'h0001, 32'hFFFF_FFFF); do_read(32'h0002, 0);
        do_read(32'h0000, 0); do_read(32'h0008, 0);         // unchanged
        check_pins;

        // 5) SETUP without ACCESS must not write
        @(negedge clk); psel = 1; penable = 0; pwrite = 1; paddr = 32'h0000; pwdata = 32'h0000_1111;
        @(negedge clk); psel = 0; pwrite = 0;
        do_read(32'h0000, 0);
        check_pins;

        // 7) random accesses
        for (t = 0; t < 3000; t = t + 1) begin
            a = {19'd0, $random(seed) % 2 == 0 ? 1'b0 : 1'b1, 12'd0};
            case ($unsigned($random(seed)) % 5)
                0, 1:    a[11:0] = 12'h000;
                2:       a[11:0] = 12'h008;
                3:       a[11:0] = 12'h004;
                default: a[11:0] = $random(seed);
            endcase
            d = $random(seed);
            if ($unsigned($random(seed)) % 4 == 0) begin
                @(negedge clk); pins_in = $random(seed);
                repeat (2) @(posedge clk);
            end
            if ($random(seed) & 1) do_write(a, d); else do_read(a, pins_in);
            check_pins;
        end

        if (errors == 0) $display("PASS: apb_gpio (%0d APB transfers, GPIO_W 16 and 32)", nops);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #2000000 $display("FAIL: timeout");
        $finish;
    end
endmodule
