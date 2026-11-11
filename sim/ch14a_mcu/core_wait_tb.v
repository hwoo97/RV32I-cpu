`timescale 1ns/1ps
// Testbench for rv32i_core with data-port wait states (stall) - riscv-tests pass/fail check
//  - Core: rtl/ch14a_mcu/rv32i_core.v (dmem_ready input)
//  - Memories: the stage 3 models rtl/ch05_single_cycle/imem.v, dmem.v (8 KB, same hex images as stage 3)
//  - Wait injection: every cycle dmem_ready is 0 with probability WAITPCT %, also when there is no request
//    (the core must ignore it then). The DMEM write happens only at the completing edge (wstrb & ready).
// Plusargs
//  - +HEX=<file>     test program (word hex), loaded into both imem and dmem
//  - +TOHOST=<hex>   result address (default 1000)
//  - +MAXCYC=<dec>   max cycles (default 200000)
//  - +WAITPCT=<dec>  percent of cycles with dmem_ready = 0 (default 0 = never wait)
//  - +SEED=<dec>     random seed (default 1)
// Checks
//  - value written to tohost (on the completing edge): 1 = PASS, other odd value = FAIL (test number = value >> 1)
//  - trap, timeout -> FAIL
//  - protocol: while the core waits, the request (re, addr, wstrb, wdata) must not change -> FAIL if it does
// Output on PASS: "PASS: <hex> (<cycles> cycles, <retired> retired, <wait> wait)"
//  - retired = cycles that finished an instruction; it must equal the stage 3 cycle count for the same test
module core_wait_tb;
    reg clk = 0, rst_n = 0;
    wire [31:0] dbg_pc;
    wire        trap;

    wire [31:0] imem_addr, imem_rdata;
    wire        dmem_re;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    reg         dmem_ready = 1'b1;

    reg  [8*256:1] hex;
    reg  [31:0]    tohost;
    integer        maxcyc, waitpct, seed, cycles, waits;

    rv32i_core dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_re    (dmem_re),
        .dmem_addr  (dmem_addr),
        .dmem_wstrb (dmem_wstrb),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_ready (dmem_ready),
        .dbg_pc     (dbg_pc),
        .trap       (trap)
    );

    imem #(.ADDR_BITS(13)) u_imem (.addr(imem_addr), .inst(imem_rdata));

    // write only at the completing edge
    dmem #(.ADDR_BITS(13)) u_dmem (
        .clk   (clk),
        .addr  (dmem_addr),
        .wstrb (dmem_wstrb & {4{dmem_ready}}),
        .wdata (dmem_wdata),
        .rdata (dmem_rdata)
    );

    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("HEX=%s", hex)) begin
            $display("FAIL: +HEX=<file> not given");
            $finish;
        end
        if (!$value$plusargs("TOHOST=%h", tohost))   tohost  = 32'h0000_1000;
        if (!$value$plusargs("MAXCYC=%d", maxcyc))   maxcyc  = 200000;
        if (!$value$plusargs("WAITPCT=%d", waitpct)) waitpct = 0;
        if (!$value$plusargs("SEED=%d", seed))       seed    = 1;

        $readmemh(hex, u_imem.mem);
        $readmemh(hex, u_dmem.mem);

        #12 rst_n = 1;
    end

    // New dmem_ready value right after each rising edge (stable for the whole cycle)
    integer r;
    always @(posedge clk) begin
        r = $random(seed);
        if (r < 0) r = -r;
        dmem_ready <= (waitpct == 0) ? 1'b1 : ((r % 100) >= waitpct);
    end

    // Request seen in the previous cycle (for the protocol check)
    reg        prev_wait = 1'b0;
    reg        prev_re;
    reg [31:0] prev_addr, prev_wdata;
    reg [3:0]  prev_wstrb;

    initial begin cycles = 0; waits = 0; end

    // Checks just before the rising edge (all values of this cycle are settled)
    always @(negedge clk) if (rst_n) begin
        cycles = cycles + 1;
        if (dut.mem_wait) waits = waits + 1;

        if (prev_wait && (dmem_re !== prev_re || dmem_addr !== prev_addr ||
                          dmem_wstrb !== prev_wstrb || dmem_wdata !== prev_wdata)) begin
            $display("FAIL: %0s request changed while waiting at pc=%h (addr %h -> %h, wstrb %b -> %b)",
                     hex, dbg_pc, prev_addr, dmem_addr, prev_wstrb, dmem_wstrb);
            $finish;
        end
        prev_wait  = dut.mem_wait;
        prev_re    = dmem_re;
        prev_addr  = dmem_addr;
        prev_wstrb = dmem_wstrb;
        prev_wdata = dmem_wdata;

        if (dmem_ready && dmem_wstrb == 4'b1111 && dmem_addr == tohost) begin
            if (dmem_wdata == 32'd1)
                $display("PASS: %0s (%0d cycles, %0d retired, %0d wait)", hex, cycles, cycles - waits, waits);
            else
                $display("FAIL: %0s test %0d (tohost=%h, pc=%h)", hex, dmem_wdata >> 1, dmem_wdata, dbg_pc);
            $finish;
        end

        if (trap) begin
            $display("FAIL: %0s trap at pc=%h inst=%h (illegal=%b misaligned=%b)",
                     hex, dbg_pc, imem_rdata, dut.illegal, dut.mem_misaligned);
            $finish;
        end

        if (cycles >= maxcyc) begin
            $display("FAIL: %0s timeout after %0d cycles (pc=%h)", hex, cycles, dbg_pc);
            $finish;
        end
    end
endmodule
