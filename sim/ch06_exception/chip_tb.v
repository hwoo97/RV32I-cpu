`timescale 1ns/1ps
`include "mcu_memmap.vh"
// Testbench for the ch6 chip (rv32i_chip: rv32i_mcu + IO pads) - same programs as mcu_exc_tb
//  - The memories sit outside the chip and use the 12-bit word addresses on the chip pins:
//      IMEM port A <- IMEM_ADDR, IMEM port B (data-side read) <- DADDR, DMEM <- DADDR / RAM_WSTRB / RAM_WDATA
//  - +HEX=<file>, +MAXCYC=<dec>, +TRACE (as in mcu_exc_tb), +PERIOD_PS=<dec> clock period in ps
//    (default 10000 = 10 ns; the gate-level run after PnR uses the PnR target, e.g. 13000)
//  - Reset is held for 4 clock cycles (gate-level: the reset pad and the clock tree have delays)
//  - Gate-level run (PnR netlist + SDF): sim/ch06_exception/run_chip_gate.sh
//  - Result: stores to the TOHOST words at the end of DMEM, watched on the chip pins (DMEM write pins)
//  - Pins: GPIO pads have a weak pull-down; EXT_IRQ = GPIO[15] (a program raises its own external
//    interrupt), UART_RX = UART_TX
//  - Pad models: sim/ch06_exception/pad_models.v on this PC, the PDK pad models on the server
module chip_tb;
    reg  clk = 0, rst_n = 0;
    integer period_ps;
    initial begin
        if (!$value$plusargs("PERIOD_PS=%d", period_ps)) period_ps = 10000;
        $display("clock period: %0d ps", period_ps);
        forever #(period_ps / 2000.0) clk = ~clk;
    end

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

    // -- gate-level run: SDF delays on the PnR netlist (set by run_chip_gate.sh, as in the lab flow)
    //    +define+GATE_SDF=\"<sdf file>\"  [+define+GATE_SDF_MIN for the fast (min) corner]
    //    Direct xrun from the repo root (sim/ch06_exception/chip_gate.f): +define+GATE_SDF_SLOW or
    //    +define+GATE_SDF_FAST reads the SDF of the GUI PnR run (pnr/ch06_chip/runs/work/out/)
`ifdef GATE_SDF
  `ifdef GATE_SDF_MIN
    initial $sdf_annotate(`GATE_SDF, dut, , "sdf_annotate.log", "MINIMUM");
  `else
    initial $sdf_annotate(`GATE_SDF, dut, , "sdf_annotate.log", "MAXIMUM");
  `endif
`elsif GATE_SDF_SLOW
    initial $sdf_annotate("pnr/ch06_chip/runs/work/out/rv32i_chip_slow.sdf", dut, , "sdf_annotate.log", "MAXIMUM");
`elsif GATE_SDF_FAST
    initial $sdf_annotate("pnr/ch06_chip/runs/work/out/rv32i_chip_fast.sdf", dut, , "sdf_annotate.log", "MINIMUM");
`endif

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
        repeat (4) @(negedge clk);
        rst_n = 1;
    end

    always @(posedge clk)
        if (trace && (TRAP || IRQ_TAKEN))
            $display("TRAP: %s (pins TRAP=%b IRQ_TAKEN=%b BUS_ERR=%b)", IRQ_TAKEN ? "irq" : "exc",
                     TRAP, IRQ_TAKEN, BUS_ERR);

    initial begin cycles = 0; n_exc = 0; n_irq = 0; end
    // Counts of the observation pins TRAP / IRQ_TAKEN (1-cycle pulses, combinational from the core).
    // RTL: sampled at the falling edge. Gate run with SDF: the TRAP path goes through the memory round
    // trip (pc -> pads -> memory -> pads -> decode) and settles late in the cycle, after the falling edge
    // (the first pre-layout run counted 14 exceptions instead of 5). The SDC constrains these pins to
    // the next rising edge, so the gate run samples them there (the value of the cycle that just ended).
`ifdef GATE_SDF
  `define CHIP_TB_COUNT_POSEDGE
`elsif GATE_SDF_SLOW
  `define CHIP_TB_COUNT_POSEDGE
`elsif GATE_SDF_FAST
  `define CHIP_TB_COUNT_POSEDGE
`endif
`ifdef CHIP_TB_COUNT_POSEDGE
    always @(posedge clk) if (rst_n) begin
`else
    always @(negedge clk) if (rst_n) begin
`endif
        if (TRAP === 1'b1)      n_exc = n_exc + 1;
        if (IRQ_TAKEN === 1'b1) n_irq = n_irq + 1;
    end
    always @(negedge clk) if (rst_n) begin
        cycles = cycles + 1;
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
