`timescale 1ns/1ps
// Self-checking testbench for apb_uart (03_chapters/ch14a_mcu/design.md sec. 5.3)
//  - APB master tasks from apb_master.vh
//  - TX monitor: decodes every frame on uart_tx with its own timing (middle of each bit, from the
//    falling edge of the start bit) and compares it with the bytes the test expects to be sent
//  - RX driver (BFM): sends 8N1 frames on uart_rx with a chosen bit time, stop bit and glitches
//  - Loopback: uart_rx = uart_tx for the random test
// Checks
//  1) reset values, PSLVERR for wrong direction / unknown offsets
//  2) TX one byte; TX buffer: 2nd byte waits in the holding register (TX_FULL), 3rd write is ignored
//  3) RX one byte, RX_VALID cleared by reading RXDATA
//  4) overrun (new byte replaces the old one, flag cleared by reading STATUS), framing error, start glitch
//  5) RX with the sender's bit time 3 % too slow / too fast
//  6) loopback with BAUDDIV 3, 5, 16, 100: 40 random bytes each, sent and received by polling STATUS
module uart_tb;
    reg         clk = 0, presetn = 0;
    reg         psel = 0, penable = 0, pwrite = 0;
    reg  [31:0] paddr = 0, pwdata = 0;
    wire [31:0] prdata;
    wire        pready, pslverr;
    always #5 clk = ~clk;
    localparam real TCLK = 10.0;

    `include "apb_master.vh"

    wire uart_tx;
    reg  bfm_rx = 1'b1, loopback = 1'b0;
    wire uart_rx = loopback ? uart_tx : bfm_rx;

    apb_uart dut (
        .pclk(clk), .presetn(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr[11:0]), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr),
        .uart_rx(uart_rx), .uart_tx(uart_tx)
    );

    integer errors = 0;
    task fail(input [8*50:1] what, input [31:0] got, input [31:0] exp);
        begin
            if (errors < 10) $display("FAIL: %0s got %h expected %h at %0t", what, got, exp, $time);
            errors = errors + 1;
        end
    endtask

    integer cur_div = 433;                      // BAUDDIV the monitor and driver use
    integer seed;
    reg [31:0] rd; reg er;
    task wr(input [11:0] o, input [31:0] d); begin apb_write({20'd0, o}, d, er); end endtask
    task rdreg(input [11:0] o);              begin apb_read({20'd0, o}, rd, er);  end endtask
    task set_div(input integer d); begin wr(12'h00C, d); cur_div = d; end endtask

    // -- expected TX bytes (queue) and the TX monitor --
    reg [7:0] txq [0:1023];
    integer   txq_w = 0, txq_r = 0, tx_frames = 0;
    task expect_tx(input [7:0] b); begin txq[txq_w] = b; txq_w = txq_w + 1; end endtask

    real tbit;
    integer k;
    reg [9:0] frame;
    always begin
        @(negedge uart_tx);
        if (presetn) begin
            tbit = (cur_div + 1) * TCLK;
            for (k = 0; k < 10; k = k + 1) begin
                if (k == 0) #(tbit / 2.0); else #(tbit);
                frame[k] = uart_tx;
            end
            if (frame[0] !== 1'b0) fail("TX start bit", frame[0], 0);
            if (frame[9] !== 1'b1) fail("TX stop bit", frame[9], 1);
            if (txq_r >= txq_w)                  fail("TX unexpected byte", frame[8:1], 0);
            else if (frame[8:1] !== txq[txq_r])  fail("TX byte", frame[8:1], txq[txq_r]);
            txq_r = txq_r + 1; tx_frames = tx_frames + 1;
            #(tbit / 2.0 - 1.0);                // stay inside the stop bit until its end
            if (uart_tx !== 1'b1) fail("TX stop bit too short", uart_tx, 1);
        end
    end

    // -- RX driver: one 8N1 frame with bit time scaled by 'scale' and a chosen stop bit --
    task send(input [7:0] b, input real scale, input stopbit);
        real t; integer i;
        begin
            t = (cur_div + 1) * TCLK * scale;
            bfm_rx = 1'b0; #(t);
            for (i = 0; i < 8; i = i + 1) begin bfm_rx = b[i]; #(t); end
            bfm_rx = stopbit; #(t);
            bfm_rx = 1'b1; #(t);                // one idle bit
        end
    endtask

    task wait_tx_idle;
        integer n;
        begin
            n = 0; rdreg(12'h008);
            while (rd[3] !== 1'b1) begin rdreg(12'h008); n = n + 1; if (n > 100000) begin fail("TX never idle", 0, 1); disable wait_tx_idle; end end
            #((cur_div + 1) * TCLK);            // let the monitor finish the last frame
        end
    endtask

    // -- loopback test at one BAUDDIV --
    reg [7:0] lbq [0:63];
    integer   lb_sent, lb_rcvd, lb_iter;
    task loopback_run(input integer d, input integer nbytes);
        begin
            set_div(d);
            loopback = 1'b1;
            for (k = 0; k < nbytes; k = k + 1) lbq[k] = $random(seed);
            lb_sent = 0; lb_rcvd = 0; lb_iter = 0;
            while (lb_rcvd < nbytes && lb_iter < 200000) begin
                rdreg(12'h008);
                if (rd[2]) fail("loopback overrun", rd, 0);
                if (rd[4]) fail("loopback framing error", rd, 0);
                if (rd[1]) begin
                    rdreg(12'h004);
                    if (rd[7:0] !== lbq[lb_rcvd]) fail("loopback RX byte", rd[7:0], lbq[lb_rcvd]);
                    lb_rcvd = lb_rcvd + 1;
                end else if (!rd[0] && lb_sent < nbytes) begin
                    expect_tx(lbq[lb_sent]);
                    wr(12'h000, lbq[lb_sent]);
                    lb_sent = lb_sent + 1;
                end
                lb_iter = lb_iter + 1;
            end
            if (lb_rcvd != nbytes) fail("loopback bytes received", lb_rcvd, nbytes);
            wait_tx_idle;
            loopback = 1'b0;
        end
    endtask

    initial begin
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        #12 presetn = 1;

        // 1) reset values and errors
        rdreg(12'h008); if (rd !== 32'h8)   fail("reset STATUS (TX_IDLE only)", rd, 32'h8);
        rdreg(12'h00C); if (rd !== 32'd433) fail("reset BAUDDIV", rd, 433);
        wr(12'h004, 0);   if (er !== 1) fail("write RXDATA -> PSLVERR", er, 1);
        wr(12'h008, 0);   if (er !== 1) fail("write STATUS -> PSLVERR", er, 1);
        rdreg(12'h000);   if (er !== 1 || rd !== 0) fail("read TXDATA -> PSLVERR", er, 1);
        rdreg(12'h010);   if (er !== 1 || rd !== 0) fail("unknown offset", er, 1);
        if (uart_tx !== 1'b1) fail("TX idle high", uart_tx, 1);

        // 2) TX
        set_div(7);
        rdreg(12'h00C); if (rd !== 32'd7) fail("BAUDDIV read back", rd, 7);
        expect_tx(8'hA5); wr(12'h000, 32'hFFFF_FFA5);              // only the low 8 bits are sent
        wait_tx_idle;
        expect_tx(8'h01); wr(12'h000, 8'h01);                       // goes into the shifter
        expect_tx(8'h80); wr(12'h000, 8'h80);                       // waits in the holding register
        rdreg(12'h008); if (rd[0] !== 1'b1 || rd[3] !== 1'b0) fail("TX_FULL=1, TX_IDLE=0", rd, 1);
        wr(12'h000, 8'hFF);                                         // ignored (TX_FULL)
        wait_tx_idle;
        if (txq_r != txq_w || tx_frames != 3) fail("TX frames sent", tx_frames, 3);

        // 3) RX one byte
        send(8'h3C, 1.0, 1'b1);
        rdreg(12'h008); if (rd[1] !== 1'b1) fail("RX_VALID after a byte", rd, 2);
        rdreg(12'h004); if (rd !== 32'h3C)  fail("RXDATA", rd, 32'h3C);
        rdreg(12'h008); if (rd[1] !== 1'b0) fail("RX_VALID cleared by reading RXDATA", rd, 0);

        // 4) overrun, framing error, glitch
        send(8'h11, 1.0, 1'b1); send(8'h22, 1.0, 1'b1);
        rdreg(12'h008); if (rd[2:1] !== 2'b11) fail("RX_VALID and RX_OVERRUN", rd, 6);
        rdreg(12'h004); if (rd !== 32'h22)     fail("overrun keeps the new byte", rd, 32'h22);
        rdreg(12'h008); if (rd[2] !== 1'b0)    fail("RX_OVERRUN cleared by reading STATUS", rd, 0);
        send(8'h5A, 1.0, 1'b0);                                     // stop bit 0
        rdreg(12'h008); if (rd[4] !== 1'b1 || rd[1] !== 1'b0) fail("RX_FRAME set, no RX_VALID", rd, 32'h10);
        rdreg(12'h008); if (rd[4] !== 1'b0)    fail("RX_FRAME cleared by reading STATUS", rd, 0);
        @(negedge clk); bfm_rx = 1'b0; repeat (2) @(negedge clk); bfm_rx = 1'b1;   // 2-clock glitch
        repeat (12 * (cur_div + 1)) @(negedge clk);
        rdreg(12'h008); if (rd[1] !== 1'b0 || rd[4] !== 1'b0) fail("glitch ignored", rd, 0);

        // 5) bit time 3 % slow / fast
        set_div(15);
        send(8'hC3, 1.03, 1'b1); rdreg(12'h004); if (rd !== 32'hC3) fail("RX 3% slow", rd, 32'hC3);
        send(8'h69, 0.97, 1'b1); rdreg(12'h004); if (rd !== 32'h69) fail("RX 3% fast", rd, 32'h69);

        // 6) loopback
        loopback_run(3,   40);
        loopback_run(5,   40);
        loopback_run(16,  40);
        loopback_run(100, 40);

        if (txq_r != txq_w) fail("TX bytes still expected", txq_w - txq_r, 0);
        if (errors == 0) $display("PASS: apb_uart (%0d TX frames checked, loopback BAUDDIV 3/5/16/100)", tx_frames);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #20000000 $display("FAIL: timeout");
        $finish;
    end
endmodule
