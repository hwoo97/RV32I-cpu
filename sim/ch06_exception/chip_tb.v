`timescale 1ns/1ps
`include "mcu_memmap.vh"
// Testbench for the ch6 chip (rv32i_chip: rv32i_mcu + IO pads) - same programs as mcu_exc_tb
//  - The memories sit outside the chip and use the 12-bit word addresses on the chip pins:
//      IMEM port A <- IMEM_ADDR, IMEM port B (data-side read) <- DADDR, DMEM <- DADDR / RAM_WSTRB / RAM_WDATA
//  - +HEX=<file>, +MAXCYC=<dec>, +TRACE (as in mcu_exc_tb)
//  - Result: stores to the TOHOST words at the end of DMEM, watched on the chip pins (DMEM write pins)
//  - Pins: GPIO pads have a weak pull-down; EXT_IRQ = GPIO[15] (a program raises its own external
//    interrupt), UART_RX = UART_TX
//  - Pad models: sim/ch06_exception/pad_models.v on this PC, the PDK pad models on the server
module chip_tb;
    reg  clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    wire [11:0] IMEM_ADDR, DADDR;
    wire [31:0] IMEM_DATA, IROM_DATA, RAM_RDATA, RAM_WDATA;
    wire [3:0]  RAM_WSTRB;
    wire [15:0] GPIO;
    wire        UART_TX, TRAP, IRQ_TAKEN, BUS_ERR, TIMER_IRQ;
    pulldown pd [15:0] (GPIO);

    rv32i_chip dut (
        .IMEM_ADDR(IMEM_ADDR), .IMEM_DATA(IMEM_DATA),
        .DADDR(DADDR), .RAM_WSTRB(RAM_WSTRB), .RAM_WDATA(RAM_WDATA), .RAM_RDATA(RAM_RDATA),
        .GPIO(GPIO), .IROM_DATA(IROM_DATA),
        .RST_N(rst_n), .EXT_IRQ(GPIO[15]), .CLK(clk),
        .UART_RX(UART_TX), .UART_TX(UART_TX),
        .TRAP(TRAP), .IRQ_TAKEN(IRQ_TAKEN), .BUS_ERR(BUS_ERR), .TIMER_IRQ(TIMER_IRQ)
    );

    // -- memories outside the chip (byte address = word address << 2) --
    mcu_imem #(.AW(`MM_IMEM_AW)) u_imem (
        .addr_a  ({18'd0, IMEM_ADDR, 2'b00}), .rdata_a (IMEM_DATA),
        .addr_b  ({18'd0, DADDR, 2'b00}),     .rdata_b (IROM_DATA)
    );
    mcu_dmem #(.AW(`MM_DMEM_AW)) u_dmem (
        .clk(clk), .addr({18'd0, DADDR, 2'b00}), .wstrb(RAM_WSTRB), .wdata(RAM_WDATA), .rdata(RAM_RDATA)
    );

    // -- test result: DMEM writes seen on the chip pins --
    wire        sim_done, sim_bad_store;
    wire [31:0] sim_result;
    tohost_mon u_tohost (
        .clk(clk), .rst_n(rst_n),
        .addr(`MM_DMEM_BASE | {18'd0, DADDR, 2'b00}), .wstrb(RAM_WSTRB), .wdata(RAM_WDATA),
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
            u_imem.mem[i] = 32'h0000_0013;          // nop
            u_dmem.mem[i] = 32'd0;
        end
        $readmemh(hex, u_imem.mem);
        #12 rst_n = 1;
    end

    always @(posedge clk)
        if (trace && (TRAP || IRQ_TAKEN))
            $display("TRAP: %s (pins TRAP=%b IRQ_TAKEN=%b BUS_ERR=%b)", IRQ_TAKEN ? "irq" : "exc",
                     TRAP, IRQ_TAKEN, BUS_ERR);

    initial begin cycles = 0; n_exc = 0; n_irq = 0; end
    always @(negedge clk) if (rst_n) begin
        cycles = cycles + 1;
        if (TRAP === 1'b1)      n_exc = n_exc + 1;
        if (IRQ_TAKEN === 1'b1) n_irq = n_irq + 1;
        if (sim_done) begin
            if (sim_result == 32'd1)
                $display("PASS: %0s (%0d cycles, %0d exceptions, %0d interrupts)", hex, cycles, n_exc, n_irq);
            else
                $display("FAIL: %0s test %0d (result=%h)", hex, sim_result >> 1, sim_result);
            $finish;
        end
        if (sim_bad_store) begin
            $display("FAIL: %0s partial store to TOHOST FINISH", hex);
            $finish;
        end
        if (cycles >= maxcyc) begin
            $display("FAIL: %0s timeout after %0d cycles (%0d exceptions, %0d interrupts)", hex, cycles, n_exc, n_irq);
            $finish;
        end
    end
endmodule
