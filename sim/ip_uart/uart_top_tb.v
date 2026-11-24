`timescale 1ns/1ps
`include "uart_defs.vh"
// Self-checking testbench for the UART IP uart_top (03_chapters/ip_uart/design.md sec. 8)
//  - APB master tasks: sim/ch14a_mcu/apb_master.vh
//  - TX monitor: decodes frames on uart_tx with its own timing (bit time from DIV) and the frame
//    format the test sets; every frame is compared with the expected queue (data, parity, stop bits)
//  - RX driver (BFM): sends frames on uart_rx with any format, bit time, wrong parity / stop bit,
//    short flips near the middle of the data bits, or a short low pulse while the line is idle
// Tests (numbers printed in the log)
//   1 reset values, PSLVERR cases        6 interrupts: RXTHR, TXTHR, TXDONE, RXTO, errors
//   2 TX: all 24 frame formats            7 loopback (pin uart_tx stays 1, pin uart_rx ignored)
//   3 RX: all 24 frame formats            8 noise and baud error (+-3 %)
//   4 FIFO full / overflow, order          9 random: both directions at once, random formats
//   5 parity / framing errors, W1C
module uart_top_tb;
    reg         clk = 0, presetn = 0;
    reg         psel = 0, penable = 0, pwrite = 0;
    reg  [31:0] paddr = 0, pwdata = 0;
    wire [31:0] prdata;
    wire        pready, pslverr;
    localparam real TCLK = 5.0;                 // 200 MHz
    always #(TCLK / 2) clk = ~clk;

    `include "apb_master.vh"

    reg  bfm_rx = 1'b1;
    wire uart_tx, irq;

    uart_top dut (
        .pclk(clk), .presetn(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr[11:0]), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .irq(irq), .uart_rx(bfm_rx), .uart_tx(uart_tx)
    );

    // ---------------------------------------------------------------- checking helpers
    integer errors = 0, checks = 0;
    task check(input [8*48:1] what, input [31:0] got, input [31:0] exp);
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                if (errors <= 20) $display("FAIL: %0s got %h expected %h at %0t", what, got, exp, $time);
            end
        end
    endtask

    reg        e;
    reg [31:0] v;
    task wr(input [11:0] a, input [31:0] d);
        begin
            apb_write({20'd0, a}, d, e);
            check("PSLVERR on write", e, 1'b0);
        end
    endtask
    task rd(input [11:0] a, output [31:0] d);
        begin
            apb_read({20'd0, a}, d, e);
            check("PSLVERR on read", e, 1'b0);
        end
    endtask
    task rd_expect(input [8*48:1] what, input [11:0] a, input [31:0] exp);
        reg [31:0] d;
        begin
            rd(a, d);
            check(what, d, exp);
        end
    endtask

    // ---------------------------------------------------------------- frame format (test side)
    reg  [1:0] f_dbits = 2'd3;
    reg        f_pen = 0, f_peven = 0, f_stop2 = 0;
    reg [15:0] f_div = 16'd108;
    function [31:0] ctrl_word(input txen, input rxen, input loop);
        ctrl_word = {24'd0, loop, f_stop2, f_peven, f_pen, f_dbits, rxen, txen};
    endfunction
    task set_format(input [1:0] db, input p, input pe, input s2);
        begin
            f_dbits = db; f_pen = p; f_peven = pe; f_stop2 = s2;
            wr(`UART_OFS_CTRL, ctrl_word(1, 1, 0));
        end
    endtask
    task set_div(input [15:0] d);
        begin
            f_div = d;
            wr(`UART_OFS_BAUD, {16'd0, d});
        end
    endtask
    function [7:0] mask(input [7:0] d);
        mask = d & ((8'd1 << (5 + f_dbits)) - 8'd1);
    endfunction
    function real bit_ns(input dummy);
        bit_ns = 16.0 * (f_div + 1) * TCLK;
    endfunction
    function integer char_bits(input dummy);
        char_bits = 1 + 5 + f_dbits + f_pen + 1 + f_stop2;
    endfunction

    // ---------------------------------------------------------------- TX monitor
    reg  [7:0] exp_tx [0:1023];
    integer    tx_head = 0, tx_tail = 0, tx_frames = 0;
    reg        mon_en = 1'b1;
    task expect_tx(input [7:0] d);
        begin
            exp_tx[tx_tail % 1024] = mask(d);
            tx_tail = tx_tail + 1;
        end
    endtask

    always @(negedge uart_tx) if (mon_en) begin : monitor
        real    b;
        integer k;
        reg [7:0] d;
        reg       par, ok;
        b = bit_ns(0);
        #(b / 2);
        ok = (uart_tx === 1'b0);
        d = 8'd0; par = 1'b0;
        for (k = 0; k < 5 + f_dbits; k = k + 1) begin
            #(b);
            d[k] = uart_tx;
            par = par ^ uart_tx;
        end
        if (f_pen) begin
            #(b);
            if (uart_tx !== (f_peven ? par : ~par)) ok = 1'b0;
        end
        #(b);
        if (uart_tx !== 1'b1) ok = 1'b0;
        if (f_stop2) begin
            #(b);
            if (uart_tx !== 1'b1) ok = 1'b0;
        end
        tx_frames = tx_frames + 1;
        check("TX frame start/parity/stop", ok, 1'b1);
        if (tx_head == tx_tail) begin
            check("TX unexpected frame", d, 8'hxx);
        end else begin
            check("TX data", d, exp_tx[tx_head % 1024]);
            tx_head = tx_head + 1;
        end
    end

    // wait until all expected TX frames were seen (with a time limit)
    task wait_tx_done;
        integer t;
        begin
            t = 0;
            while (tx_head != tx_tail && t < 2000) begin
                #(bit_ns(0));
                t = t + 1;
            end
            check("TX frames missing", tx_tail - tx_head, 0);
            #(bit_ns(0));
        end
    endtask

    // ---------------------------------------------------------------- RX driver
    // bad: bit0 = wrong parity, bit1 = stop bit 0,
    //      bit2 = in every data bit, flip the line for 0.9 tick near the middle; the flip moves by
    //      half a tick from bit to bit (centre 6.5 .. 10 ticks), so it never covers two samples of one
    //      bit but hits sample 8 in some bit (majority must still give the right value)
    task send(input [7:0] d, input real scale, input [2:0] bad);
        real    b, t, c;
        integer k;
        reg     par, bv;
        begin
            b = bit_ns(0) * scale;
            t = b / 16.0;                      // one tick of the sender
            par = 1'b0;
            bfm_rx = 1'b0; #(b);
            for (k = 0; k < 5 + f_dbits; k = k + 1) begin
                bv = d[k];
                par = par ^ bv;
                bfm_rx = bv;
                if (bad[2]) begin
                    c = (6.5 + 0.5 * k) * t;
                    #(c - 0.45 * t); bfm_rx = ~bv; #(0.9 * t); bfm_rx = bv; #(b - c - 0.45 * t);
                end else begin
                    #(b);
                end
            end
            if (f_pen) begin
                bfm_rx = (f_peven ? par : ~par) ^ bad[0]; #(b);
            end
            bfm_rx = ~bad[1]; #(b);
            bfm_rx = 1'b1;
            if (f_stop2) #(b);
            if (bad[1]) #(b);                  // give a broken stop bit time to settle
        end
    endtask

    task expect_rx(input [7:0] d, input pe, input fe);
        begin
            rd_expect("RXDATA", `UART_OFS_RXDATA, {22'd0, fe, pe, mask(d)});
        end
    endtask

    task wait_clocks(input integer n);
        begin
            repeat (n) @(posedge clk);
        end
    endtask

    // ---------------------------------------------------------------- tests
    integer i, j, n, fmt, sent_rx, ti, ri;     // ti / ri: loop variables of the two forked branches
    reg [7:0] b8, rxq [0:31];
    reg       ok;
    integer   isr_seen;

    initial begin
        #23 presetn = 1;
        wait_clocks(2);

        // ---- 1 reset values and PSLVERR
        $display("test 1: reset values, PSLVERR");
        rd_expect("CTRL reset", `UART_OFS_CTRL, 32'h0000_000F);
        rd_expect("BAUD reset", `UART_OFS_BAUD, 32'd108);
        rd_expect("FIFO_THR reset", `UART_OFS_FIFO_THR, 32'h0000_0001);
        rd_expect("IER reset", `UART_OFS_IER, 32'd0);
        rd_expect("ISR reset (TXTHR, TXDONE)", `UART_OFS_ISR, 32'h0000_0006);
        rd_expect("STATUS reset", `UART_OFS_STATUS, 32'h0000_000A);
        rd_expect("RXDATA empty", `UART_OFS_RXDATA, 32'h8000_0000);
        check("irq reset", irq, 1'b0);
        apb_read(32'h000, v, e);  check("PSLVERR read TXDATA", e, 1'b1); check("read data on error", v, 0);
        apb_write(32'h004, 1, e); check("PSLVERR write RXDATA", e, 1'b1);
        apb_write(32'h008, 1, e); check("PSLVERR write STATUS", e, 1'b1);
        apb_read(32'h020, v, e);  check("PSLVERR unknown offset", e, 1'b1);
        apb_write(32'h00E, 0, e); check("PSLVERR unaligned", e, 1'b1);
        rd_expect("CTRL unchanged after error", `UART_OFS_CTRL, 32'h0000_000F);
        wr(`UART_OFS_FIFO_THR, 32'h0000_0A05);
        rd_expect("FIFO_THR write", `UART_OFS_FIFO_THR, 32'h0000_0A05);
        wr(`UART_OFS_FIFO_THR, 32'h0000_0001);
        wr(`UART_OFS_IER, 32'hFFFF_FFFF);
        rd_expect("IER write (8 bits)", `UART_OFS_IER, 32'h0000_00FF);
        wr(`UART_OFS_IER, 0);

        set_div(16'd3);                       // 4 clocks per tick, 64 clocks per bit (fast simulation)

        // ---- 2 TX, all formats
        $display("test 2: TX 24 frame formats");
        for (fmt = 0; fmt < 24; fmt = fmt + 1) begin
            set_format(fmt % 4, (fmt / 4) % 3 != 0, (fmt / 4) % 3 == 2, fmt / 12);
            b8 = $random; expect_tx(b8); wr(`UART_OFS_TXDATA, b8);
            b8 = $random; expect_tx(b8); wr(`UART_OFS_TXDATA, b8);
            wait_tx_done;
        end

        // ---- 3 RX, all formats
        $display("test 3: RX 24 frame formats");
        for (fmt = 0; fmt < 24; fmt = fmt + 1) begin
            set_format(fmt % 4, (fmt / 4) % 3 != 0, (fmt / 4) % 3 == 2, fmt / 12);
            rxq[0] = $random; rxq[1] = $random;
            send(rxq[0], 1.0, 0); send(rxq[1], 1.0, 0);
            wait_clocks(10);
            expect_rx(rxq[0], 0, 0); expect_rx(rxq[1], 0, 0);
            rd_expect("RXDATA empty after 2", `UART_OFS_RXDATA, 32'h8000_0000);
        end

        // ---- 4 FIFO full / overflow
        $display("test 4: FIFO full, overflow, order");
        set_format(2'd3, 0, 0, 0);
        f_dbits = 2'd3;
        wr(`UART_OFS_CTRL, ctrl_word(0, 1, 0));             // TX off: bytes stay in the FIFO
        for (i = 0; i < 16; i = i + 1) begin
            b8 = 8'h40 + i; expect_tx(b8); wr(`UART_OFS_TXDATA, b8);
        end
        rd_expect("STATUS TX full", `UART_OFS_STATUS, 32'h0000_1009);
        wr(`UART_OFS_TXDATA, 8'hEE);                        // dropped
        rd(`UART_OFS_ISR, v); check("ISR TXOVR set", v[`UART_ISR_TXOVR], 1'b1);
        wr(`UART_OFS_ISR, 32'h80);
        rd(`UART_OFS_ISR, v); check("ISR TXOVR cleared", v[`UART_ISR_TXOVR], 1'b0);
        wr(`UART_OFS_CTRL, ctrl_word(1, 1, 0));
        wait_tx_done;
        for (i = 0; i < 17; i = i + 1) send(8'h60 + i, 1.0, 0);
        wait_clocks(10);
        rd_expect("STATUS RX full", `UART_OFS_STATUS, 32'h0010_0006);
        rd(`UART_OFS_ISR, v); check("ISR RXOVR set", v[`UART_ISR_RXOVR], 1'b1);
        for (i = 0; i < 16; i = i + 1) expect_rx(8'h60 + i, 0, 0);
        rd_expect("RXDATA empty after 16", `UART_OFS_RXDATA, 32'h8000_0000);
        wr(`UART_OFS_ISR, 32'h10);
        // clear bits of CTRL
        wr(`UART_OFS_CTRL, ctrl_word(0, 1, 0));
        for (i = 0; i < 5; i = i + 1) wr(`UART_OFS_TXDATA, i);
        send(8'h11, 1.0, 0); wait_clocks(10);
        wr(`UART_OFS_CTRL, ctrl_word(0, 1, 0) | 32'h300);   // clear both FIFOs
        rd_expect("STATUS after clear", `UART_OFS_STATUS, 32'h0000_000A);
        rd_expect("CTRL clear bits not stored", `UART_OFS_CTRL, ctrl_word(0, 1, 0));
        wr(`UART_OFS_CTRL, ctrl_word(1, 1, 0));

        // ---- 5 parity / framing errors
        $display("test 5: parity and framing errors");
        set_format(2'd3, 1, 1, 0);                           // 8E1
        send(8'hA5, 1.0, 3'b001); wait_clocks(10);
        expect_rx(8'hA5, 1, 0);
        rd(`UART_OFS_ISR, v); check("ISR PERR", v[`UART_ISR_PERR], 1'b1); check("no FERR", v[`UART_ISR_FERR], 1'b0);
        send(8'h3C, 1.0, 3'b010); wait_clocks(10);
        expect_rx(8'h3C, 0, 1);
        rd_expect("no extra byte after bad stop", `UART_OFS_RXDATA, 32'h8000_0000);
        rd(`UART_OFS_ISR, v); check("ISR FERR", v[`UART_ISR_FERR], 1'b1);
        wr(`UART_OFS_ISR, 32'h40);                          // clear FERR only
        rd(`UART_OFS_ISR, v); check("W1C FERR only: PERR stays", v[6:5], 2'b01);
        wr(`UART_OFS_ISR, 32'h20);
        rd(`UART_OFS_ISR, v); check("PERR/FERR cleared", v[6:5], 2'b00);
        send(8'h5A, 1.0, 0); wait_clocks(10);
        expect_rx(8'h5A, 0, 0);

        // ---- 6 interrupts
        $display("test 6: interrupts");
        set_format(2'd3, 0, 0, 0);
        // RXTHR
        wr(`UART_OFS_FIFO_THR, 32'h0000_0004);
        wr(`UART_OFS_IER, 32'h01);
        for (i = 0; i < 3; i = i + 1) send(i, 1.0, 0);
        wait_clocks(10); check("irq RXTHR below", irq, 1'b0);
        send(3, 1.0, 0); wait_clocks(10); check("irq RXTHR reached", irq, 1'b1);
        rd(`UART_OFS_RXDATA, v); wait_clocks(2); check("irq RXTHR after read", irq, 1'b0);
        wr(`UART_OFS_CTRL, ctrl_word(1, 1, 0) | 32'h200);
        // TXTHR
        wr(`UART_OFS_CTRL, ctrl_word(0, 1, 0));
        wr(`UART_OFS_FIFO_THR, 32'h0000_0201);
        wr(`UART_OFS_IER, 32'h02);
        for (i = 0; i < 4; i = i + 1) begin b8 = 8'h90 + i; expect_tx(b8); wr(`UART_OFS_TXDATA, b8); end
        wait_clocks(2); check("irq TXTHR above", irq, 1'b0);
        wr(`UART_OFS_CTRL, ctrl_word(1, 1, 0));
        i = 0;
        while (!irq && i < 100000) begin @(posedge clk); i = i + 1; end
        rd(`UART_OFS_STATUS, v); check("TXTHR when TX count <= 2", v[12:8] <= 2, 1'b1);
        wait_tx_done;
        // TXDONE
        wr(`UART_OFS_IER, 32'h04);
        wait_clocks(2); check("irq TXDONE idle", irq, 1'b1);
        b8 = 8'h77; expect_tx(b8); wr(`UART_OFS_TXDATA, b8);
        wait_clocks(2); check("irq TXDONE busy", irq, 1'b0);
        wait_tx_done; wait_clocks(2); check("irq TXDONE after frame", irq, 1'b1);
        // RXTO
        wr(`UART_OFS_FIFO_THR, 32'h0000_0008);
        wr(`UART_OFS_IER, 32'h08);
        send(8'h21, 1.0, 0); send(8'h22, 1.0, 0);
        wait_clocks(10); check("irq RXTO not yet", irq, 1'b0);
        #(bit_ns(0) * (4 * char_bits(0) - 1));
        check("irq RXTO before 4 characters", irq, 1'b0);
        #(bit_ns(0) * 2);
        check("irq RXTO after 4 characters", irq, 1'b1);
        rd(`UART_OFS_RXDATA, v); wait_clocks(2); check("irq RXTO cleared by read", irq, 1'b0);
        rd(`UART_OFS_RXDATA, v);
        // error interrupts
        wr(`UART_OFS_IER, 32'h70);
        set_format(2'd3, 1, 0, 0);                           // 8O1
        send(8'h01, 1.0, 3'b001); wait_clocks(10); check("irq PERR", irq, 1'b1);
        wr(`UART_OFS_ISR, 32'h20); wait_clocks(2); check("irq after W1C", irq, 1'b0);
        rd(`UART_OFS_RXDATA, v);
        wr(`UART_OFS_IER, 0);
        wr(`UART_OFS_FIFO_THR, 32'h0000_0001);

        // ---- 7 loopback
        $display("test 7: loopback");
        set_format(2'd3, 0, 0, 0);
        mon_en = 1'b0;
        wr(`UART_OFS_CTRL, ctrl_word(1, 1, 1));
        bfm_rx = 1'b0;                                        // pin uart_rx must be ignored
        ok = 1'b1;
        for (i = 0; i < 8; i = i + 1) wr(`UART_OFS_TXDATA, 8'hC0 + i);
        fork
            begin : pin_watch
                forever begin @(uart_tx); ok = 1'b0; end
            end
            begin
                i = 0;
                v = 0;
                while (v[20:16] != 8 && i < 200) begin #(bit_ns(0)); rd(`UART_OFS_STATUS, v); i = i + 1; end
                disable pin_watch;
            end
        join
        check("uart_tx pin idle in loopback", ok & (uart_tx === 1'b1), 1'b1);
        for (i = 0; i < 8; i = i + 1) expect_rx(8'hC0 + i, 0, 0);
        bfm_rx = 1'b1;
        wr(`UART_OFS_CTRL, ctrl_word(1, 1, 0));
        #(bit_ns(0) * 2);
        mon_en = 1'b1;

        // ---- 8 noise and baud error
        $display("test 8: noise, baud error +-3 %%");
        set_format(2'd3, 1, 1, 1);                           // 8E2
        for (i = 0; i < 4; i = i + 1) begin                  // short low pulses on an idle line
            bfm_rx = 1'b0; #(bit_ns(0) / 20); bfm_rx = 1'b1; #(bit_ns(0) * 2);
        end
        rd_expect("no byte from idle glitches", `UART_OFS_RXDATA, 32'h8000_0000);
        rd(`UART_OFS_ISR, v); check("no error from idle glitches", v[6:4], 3'b000);
        for (i = 0; i < 4; i = i + 1) rxq[i] = $random;     // flipped samples in every data bit
        for (i = 0; i < 4; i = i + 1) send(rxq[i], 1.0, 3'b100);
        wait_clocks(10);
        for (i = 0; i < 4; i = i + 1) expect_rx(rxq[i], 0, 0);
        for (n = 0; n < 2; n = n + 1) begin
            for (fmt = 0; fmt < 2; fmt = fmt + 1) begin
                if (fmt == 0) set_format(2'd3, 0, 0, 0); else set_format(2'd3, 1, 1, 1);
                for (i = 0; i < 6; i = i + 1) rxq[i] = $random;
                for (i = 0; i < 6; i = i + 1) send(rxq[i], n == 0 ? 1.03 : 0.97, 0);
                wait_clocks(10);
                for (i = 0; i < 6; i = i + 1) expect_rx(rxq[i], 0, 0);
            end
        end

        // ---- 9 random, both directions at once
        $display("test 9: random");
        for (n = 0; n < 30; n = n + 1) begin
            fmt = {$random} % 24;
            set_format(fmt % 4, (fmt / 4) % 3 != 0, (fmt / 4) % 3 == 2, fmt / 12);
            sent_rx = 1 + {$random} % 12;
            for (i = 0; i < sent_rx; i = i + 1) rxq[i] = $random;
            fork
                begin                               // CPU side: TX (own loop variable)
                    j = 1 + {$random} % 20;
                    for (ti = 0; ti < j; ti = ti + 1) begin
                        v = 32'h1;
                        while (v[0]) rd(`UART_OFS_STATUS, v);
                        b8 = $random; expect_tx(b8); wr(`UART_OFS_TXDATA, b8);
                    end
                end
                begin                               // line side: RX (own loop variable)
                    for (ri = 0; ri < sent_rx; ri = ri + 1) begin
                        send(rxq[ri], 1.0, 0);
                        #(bit_ns(0) * ({$random} % 3));
                    end
                end
            join
            wait_clocks(10);
            for (i = 0; i < sent_rx; i = i + 1) expect_rx(rxq[i], 0, 0);
            rd_expect("RXDATA empty (random)", `UART_OFS_RXDATA, 32'h8000_0000);
            wait_tx_done;
        end
        rd(`UART_OFS_ISR, v); check("no error flags at the end", v[7:4], 4'b0000);

        if (errors == 0) $display("PASS: uart_top_tb (%0d checks, %0d TX frames)", checks, tx_frames);
        else             $display("FAIL: uart_top_tb (%0d errors in %0d checks)", errors, checks);
        $finish;
    end

    initial begin
        #200_000_000;
        $display("FAIL: uart_top_tb timeout");
        $finish;
    end
endmodule
