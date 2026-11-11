`timescale 1ns/1ps
// Testbench for mcu_top (rv32i_mcu + memories) - riscv-tests built for the MCU memory map
//  - +HEX=<file>    program image for IMEM (sim/riscv-tests-hex/rv32ui_mcu/<test>.hex): code + .data image
//  - +MAXCYC=<dec>  max cycles (default 200000)
//  - The test ends by storing to the TOHOST FINISH word at the end of DMEM (tohost_mon watches the DMEM
//    write port): 1 = PASS, (n << 1) | 1 = FAIL
//  - trap, bus_err or timeout -> FAIL
//  - UART: uart_rx is looped back from uart_tx; GPIO inputs are 0
module mcu_tb;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    wire [15:0] gpio_out, gpio_oe;
    wire        uart_tx, timer_irq, trap, bus_err;
    wire [31:0] dbg_pc;
    wire        sim_done, sim_bad_store;
    wire [31:0] sim_result;

    mcu_top dut (
        .clk(clk), .rst_n(rst_n),
        .gpio_in(16'h0000), .gpio_out(gpio_out), .gpio_oe(gpio_oe),
        .uart_rx(uart_tx), .uart_tx(uart_tx), .timer_irq(timer_irq),
        .dbg_pc(dbg_pc), .trap(trap), .bus_err(bus_err)
    );

    // test result: the program stores to the TOHOST words at the end of DMEM (watched on the DMEM write port)
    tohost_mon u_tohost (
        .clk(clk), .rst_n(rst_n),
        .addr(dut.ram_addr), .wstrb(dut.ram_wstrb), .wdata(dut.ram_wdata),
        .done(sim_done), .result(sim_result), .bad_store(sim_bad_store)
    );

    reg [8*256:1] hex;
    integer maxcyc, cycles, i;
    initial begin
        if (!$value$plusargs("HEX=%s", hex)) begin
            $display("FAIL: +HEX=<file> not given");
            $finish;
        end
        if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 200000;
        for (i = 0; i < (1 << 12); i = i + 1) begin
            dut.u_imem.mem[i] = 32'h0000_0013;      // nop
            dut.u_dmem.mem[i] = 32'd0;
        end
        $readmemh(hex, dut.u_imem.mem);
        #12 rst_n = 1;
    end

    initial cycles = 0;
    always @(negedge clk) if (rst_n) begin
        cycles = cycles + 1;
        if (sim_done) begin
            if (sim_result == 32'd1)
                $display("PASS: %0s (%0d cycles)", hex, cycles);
            else
                $display("FAIL: %0s test %0d (result=%h, pc=%h)", hex, sim_result >> 1, sim_result, dbg_pc);
            $finish;
        end
        if (sim_bad_store) begin
            $display("FAIL: %0s partial store to TOHOST FINISH at pc=%h", hex, dbg_pc);
            $finish;
        end
        if (trap) begin
            $display("FAIL: %0s trap at pc=%h inst=%h", hex, dbg_pc, dut.u_mcu.imem_rdata);
            $finish;
        end
        if (bus_err) begin
            $display("FAIL: %0s bus_err at pc=%h (fetch_err=%b data_err=%b, addr=%h)", hex, dbg_pc,
                     dut.u_mcu.fetch_err, dut.u_mcu.data_err, dut.u_mcu.dmem_addr);
            $finish;
        end
        if (cycles >= maxcyc) begin
            $display("FAIL: %0s timeout after %0d cycles (pc=%h)", hex, cycles, dbg_pc);
            $finish;
        end
    end
endmodule
