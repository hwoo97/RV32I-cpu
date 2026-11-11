`timescale 1ns/1ps
// Testbench for rv32i_sc (single-cycle CPU) - riscv-tests pass/fail check
//  - +HEX=<file>   : test program (word hex), loaded into both imem and dmem
//  - +TOHOST=<hex> : result address (default 1000, see sim/riscv-tests-env/link.ld)
//  - +MAXCYC=<dec> : max cycles (default 100000)
// Pass/fail
//  - value written to tohost: 1 = PASS, any other odd value = FAIL (failed test number = value >> 1)
//  - a trap (illegal instruction, misaligned access) or exceeding max cycles is also FAIL
module rv32i_sc_tb;
    reg clk = 0, rst_n = 0;
    wire [31:0] dbg_pc;
    wire        trap;

    reg  [8*256:1] hex;
    reg  [31:0]    tohost;
    integer        maxcyc, cycles;

    rv32i_sc #(.ADDR_BITS(13)) dut (.clk(clk), .rst_n(rst_n), .dbg_pc(dbg_pc), .trap(trap));

    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("HEX=%s", hex)) begin
            $display("FAIL: +HEX=<file> not given");
            $finish;
        end
        if (!$value$plusargs("TOHOST=%h", tohost)) tohost = 32'h0000_1000;
        if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 100000;

        $readmemh(hex, dut.u_imem.mem);
        $readmemh(hex, dut.u_dmem.mem);

        #12 rst_n = 1;
    end

    // Every clock: check tohost write, trap, cycle count (just before the rising edge = all values of this instruction settled)
    initial cycles = 0;
    always @(negedge clk) if (rst_n) begin
        cycles = cycles + 1;

        // Watch the core's data memory port: sw to tohost (wstrb = 1111)
        if (dut.dmem_wstrb == 4'b1111 && dut.dmem_addr == tohost) begin
            if (dut.dmem_wdata == 32'd1)
                $display("PASS: %0s (%0d cycles)", hex, cycles);
            else
                $display("FAIL: %0s test %0d (tohost=%h, pc=%h)", hex, dut.dmem_wdata >> 1, dut.dmem_wdata, dbg_pc);
            $finish;
        end

        if (trap) begin
            $display("FAIL: %0s trap at pc=%h inst=%h (illegal=%b misaligned=%b)",
                     hex, dbg_pc, dut.imem_rdata, dut.u_core.illegal, dut.u_core.mem_misaligned);
            $finish;
        end

        if (cycles >= maxcyc) begin
            $display("FAIL: %0s timeout after %0d cycles (pc=%h)", hex, cycles, dbg_pc);
            $finish;
        end
    end
endmodule
