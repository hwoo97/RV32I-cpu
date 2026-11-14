`timescale 1ns/1ps
// Testbench for the ch6 mcu_top (traps and interrupts) - riscv-tests built with the original
// environment (env mcu_p: sim/riscv-tests-hex/rv32ui_mcu_p, rv32mi_mcu_p) and the ch6 trap tests
//  - +HEX=<file>    program image for IMEM: code + .data image
//  - +MAXCYC=<dec>  max cycles (default 200000)
//  - +TRACE         print every trap (exception / interrupt) with pc, mcause, mtval
//  - The test ends by storing to the TOHOST FINISH word at the end of DMEM (tohost_mon watches the DMEM
//    write port): 1 = PASS, odd = FAIL (riscv-tests: (n << 1) | 1, or 1337 marks an unexpected trap)
//  - Traps are normal behaviour now (the program handles them); only timeout or a partial store to
//    FINISH make the testbench itself fail
//  - Pins: ext_irq = gpio_out[15] (a program raises its own external interrupt through GPIO),
//    gpio_in = 0, uart_rx looped back from uart_tx
module mcu_exc_tb;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    wire [15:0] gpio_out, gpio_oe;
    wire        uart_tx, timer_irq, trap, irq_taken, bus_err;
    wire [31:0] dbg_pc;
    wire        sim_done, sim_bad_store;
    wire [31:0] sim_result;

    mcu_top dut (
        .clk(clk), .rst_n(rst_n),
        .gpio_in(16'h0000), .gpio_out(gpio_out), .gpio_oe(gpio_oe),
        .uart_rx(uart_tx), .uart_tx(uart_tx),
        .ext_irq(gpio_out[15]), .timer_irq(timer_irq),
        .dbg_pc(dbg_pc), .trap(trap), .irq_taken(irq_taken), .bus_err(bus_err)
    );

    // test result: the program stores to the TOHOST words at the end of DMEM (watched on the DMEM write port)
    tohost_mon u_tohost (
        .clk(clk), .rst_n(rst_n),
        .addr(dut.ram_addr), .wstrb(dut.ram_wstrb), .wdata(dut.ram_wdata),
        .done(sim_done), .result(sim_result), .bad_store(sim_bad_store)
    );

    reg [8*256:1] hex;
    integer maxcyc, cycles, i, n_exc, n_irq;
    reg trace;
    initial begin
        if (!$value$plusargs("HEX=%s", hex)) begin
            $display("FAIL: +HEX=<file> not given");
            $finish;
        end
        if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 200000;
        trace = $test$plusargs("TRACE");
        for (i = 0; i < (1 << 12); i = i + 1) begin
            dut.u_imem.mem[i] = 32'h0000_0013;      // nop
            dut.u_dmem.mem[i] = 32'd0;
        end
        $readmemh(hex, dut.u_imem.mem);
        #12 rst_n = 1;
    end

    // trap trace (values are those written at the next edge: read them from the CSR file one cycle later)
    reg trap_d, irq_d;
    reg [31:0] pc_d;
    always @(posedge clk) begin
        trap_d <= trap; irq_d <= irq_taken; pc_d <= dbg_pc;
        if (trace && (trap_d || irq_d))
            $display("TRAP: %s at pc=%h mcause=%h mtval=%h", irq_d ? "irq" : "exc", pc_d,
                     {dut.u_mcu.u_core.u_csr.mcause_int, 26'd0, dut.u_mcu.u_core.u_csr.mcause_code},
                     dut.u_mcu.u_core.u_csr.mtval);
    end

    initial begin cycles = 0; n_exc = 0; n_irq = 0; end
    always @(negedge clk) if (rst_n) begin
        cycles = cycles + 1;
        if (trap)      n_exc = n_exc + 1;
        if (irq_taken) n_irq = n_irq + 1;
        if (sim_done) begin
            if (sim_result == 32'd1)
                $display("PASS: %0s (%0d cycles, %0d exceptions, %0d interrupts)", hex, cycles, n_exc, n_irq);
            else
                $display("FAIL: %0s test %0d (result=%h, pc=%h)", hex, sim_result >> 1, sim_result, dbg_pc);
            $finish;
        end
        if (sim_bad_store) begin
            $display("FAIL: %0s partial store to TOHOST FINISH at pc=%h", hex, dbg_pc);
            $finish;
        end
        if (cycles >= maxcyc) begin
            $display("FAIL: %0s timeout after %0d cycles (pc=%h, %0d exceptions, %0d interrupts)",
                     hex, cycles, dbg_pc, n_exc, n_irq);
            $finish;
        end
    end
endmodule
