`timescale 1ns/1ps
// Testbench for C firmware on the ch6 mcu_top - copy of sim/ch14a_mcu/fw_tb.v with the ch6 ports
// (ext_irq tied to 0, irq_taken) for the firmware regression on the ch6 core
// Original description:
// Testbench for C firmware on mcu_top (fw/<prog>, simulation build -> fw/hex/<prog>.hex)
//  - +HEX=<file>     program image (fw/hex/<prog>.hex)
//  - +EXP=<file>     expected UART text (default: the HEX path with ".hex" replaced by ".exp")
//  - +MAXCYC=<dec>   max cycles (default 2000000)
//  - UART decoder on uart_tx: the bit time is read from the UART's BAUDDIV register at each start bit,
//    each bit is sampled in its middle, a stop bit of 0 is a FAIL. Decoded text is printed as "UART| ..."
//  - PASS = firmware stored FINISH = 1 to TOHOST at the end of DMEM (main returned 0) and the UART text equals the expected file
//    (CR characters are ignored on both sides, so CRLF checkouts work)
//  - trap, bus_err, a UART frame error or timeout -> FAIL
//  - gpio_in = {gpio_out[7:0], 8'hC3} (loop-back used by fw/hello)
module fw_exc_tb;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    wire [15:0] gpio_out, gpio_oe;
    wire        uart_tx, timer_irq, trap, irq_taken, bus_err;
    wire [31:0] dbg_pc;
    wire        sim_done, sim_bad_store;
    wire [31:0] sim_result;

    mcu_top dut (
        .clk(clk), .rst_n(rst_n),
        .gpio_in({gpio_out[7:0], 8'hC3}), .gpio_out(gpio_out), .gpio_oe(gpio_oe),
        .uart_rx(1'b1), .uart_tx(uart_tx), .ext_irq(1'b0), .timer_irq(timer_irq),
        .dbg_pc(dbg_pc), .trap(trap), .irq_taken(irq_taken), .bus_err(bus_err)
    );

    // test result: the program stores to the TOHOST words at the end of DMEM (watched on the DMEM write port)
    tohost_mon u_tohost (
        .clk(clk), .rst_n(rst_n),
        .addr(dut.ram_addr), .wstrb(dut.ram_wstrb), .wdata(dut.ram_wdata),
        .done(sim_done), .result(sim_result), .bad_store(sim_bad_store)
    );

    // ---------------- program load ----------------
    reg [8*256:1] hex, exp;
    integer maxcyc, cycles, i;
    initial begin
        if (!$value$plusargs("HEX=%s", hex)) begin
            $display("FAIL: +HEX=<file> not given");
            $finish;
        end
        if (!$value$plusargs("EXP=%s", exp)) begin
            exp = hex;
            exp[32:1] = ".exp";               // the last 4 characters ".hex" -> ".exp"
        end
        if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 2000000;
        for (i = 0; i < (1 << 12); i = i + 1) begin
            dut.u_imem.mem[i] = 32'h0000_0013;      // nop
            dut.u_dmem.mem[i] = 32'h0000_0000;
        end
        $readmemh(hex, dut.u_imem.mem);
        #12 rst_n = 1;
    end

    // ---------------- UART decoder ----------------
    reg [7:0] got [0:8191];
    integer   ngot = 0, bitclk, k, frame_err = 0;
    reg [7:0] ch;
    reg       bol = 1'b1;                       // at the beginning of a line
    always begin
        @(negedge uart_tx);
        if (rst_n) begin
            bitclk = dut.u_mcu.u_uart.div + 1;
            repeat (bitclk / 2) @(posedge clk);
            if (uart_tx === 1'b0) begin         // still low in the middle of the start bit
                for (k = 0; k < 8; k = k + 1) begin
                    repeat (bitclk) @(posedge clk);
                    ch[k] = uart_tx;
                end
                repeat (bitclk) @(posedge clk);
                if (uart_tx !== 1'b1) frame_err = frame_err + 1;
                if (ngot < 8192) got[ngot] = ch;
                ngot = ngot + 1;
                if (bol) $write("UART| ");
                $write("%c", ch);
                bol = (ch == 8'h0A);
            end
        end
    end

    // ---------------- compare with the expected text ----------------
    integer fd, c, pos, mism;
    task check_output;
        begin
            mism = 0; pos = 0;
            fd = $fopen(exp, "r");
            if (fd == 0) begin
                $display("FAIL: %0s cannot open expected file %0s", hex, exp);
                mism = -1;
            end else begin
                c = $fgetc(fd);
                while (c != -1 && mism == 0) begin
                    if (c != 13) begin
                        while (pos < ngot && got[pos] == 8'h0D) pos = pos + 1;
                        if (pos >= ngot || got[pos] != c[7:0]) begin
                            $display("FAIL: %0s UART output differs from %0s at character %0d (got %0s, expected %h)",
                                     hex, exp, pos, (pos >= ngot) ? "end" : "other", c[7:0]);
                            mism = 1;
                        end
                        pos = pos + 1;
                    end
                    c = $fgetc(fd);
                end
                $fclose(fd);
                while (mism == 0 && pos < ngot && got[pos] == 8'h0D) pos = pos + 1;
                if (mism == 0 && pos < ngot) begin
                    $display("FAIL: %0s UART output has %0d extra characters", hex, ngot - pos);
                    mism = 1;
                end
            end
        end
    endtask

    // ---------------- end of test ----------------
    initial cycles = 0;
    always @(negedge clk) if (rst_n) begin
        cycles = cycles + 1;
        if (sim_done) begin
            if (!bol) $write("\n");
            check_output;
            if (mism != 0)
                ;                               // message printed by check_output
            else if (frame_err != 0)
                $display("FAIL: %0s %0d UART frame errors", hex, frame_err);
            else if (sim_result != 32'd1)
                $display("FAIL: %0s main returned %0d (result=%h)", hex, sim_result >> 1, sim_result);
            else
                $display("PASS: %0s (%0d cycles, %0d UART chars)", hex, cycles, ngot);
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
            $display("FAIL: %0s timeout after %0d cycles (pc=%h, %0d UART chars)", hex, cycles, dbg_pc, ngot);
            $finish;
        end
    end
endmodule
