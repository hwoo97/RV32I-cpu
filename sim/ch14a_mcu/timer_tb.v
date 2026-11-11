`timescale 1ns/1ps
// Self-checking testbench for apb_timer (03_chapters/ch14a_mcu/design.md sec. 5.2)
//  - APB master tasks from apb_master.vh
//  - A cycle-accurate reference model runs next to the DUT and is compared every cycle
//    (count, CTRL bits, MATCH, irq) and on every APB read (PRDATA) and transfer (PSLVERR).
// Checks
//  1) one-shot: CMP = 10 from COUNT = 0 -> MATCH set exactly 11 rising edges after EN
//  2) auto reload: CMP = 4 -> a match every 5 clocks
//  3) STATUS write-1-to-clear, and a new match in the same cycle wins over the clear
//  4) irq = IE & MATCH
//  5) EN = 0 holds the counter; a COUNT write wins over counting
//  6) unknown offset -> PSLVERR, read 0, nothing changes
//  7) 3000 random register accesses (small CMP values so matches happen often) with idle cycles
module timer_tb;
    reg         clk = 0, presetn = 0;
    reg         psel = 0, penable = 0, pwrite = 0;
    reg  [31:0] paddr = 0, pwdata = 0;
    wire [31:0] prdata;
    wire        pready, pslverr, irq;
    always #5 clk = ~clk;

    `include "apb_master.vh"

    apb_timer dut (
        .pclk(clk), .presetn(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr[11:0]), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr), .irq(irq)
    );

    integer errors = 0, nreads = 0, nmatch = 0;
    task fail(input [8*50:1] what, input [31:0] got, input [31:0] exp);
        begin
            if (errors < 10) $display("FAIL: %0s got %h expected %h at %0t", what, got, exp, $time);
            errors = errors + 1;
        end
    endtask

    // -- reference model (updated at the same rising edge as the DUT) --
    reg        m_en = 0, m_auto = 0, m_ie = 0, m_match = 0;
    reg [31:0] m_count = 0, m_cmp = 0;
    reg [31:0] m_rd;
    reg        m_hit, m_known, m_wr;
    reg [11:0] ofs;
    always @(posedge clk) if (presetn) begin
        ofs     = paddr[11:0];
        m_known = (ofs == 12'h000) || (ofs == 12'h004) || (ofs == 12'h008) || (ofs == 12'h00C);
        if (psel && penable) begin
            if (pslverr !== !m_known) fail("pslverr", pslverr, !m_known);
            if (!pwrite) begin
                case (ofs)
                    12'h000: m_rd = {29'd0, m_ie, m_auto, m_en};
                    12'h004: m_rd = m_count;
                    12'h008: m_rd = m_cmp;
                    12'h00C: m_rd = {31'd0, m_match};
                    default: m_rd = 0;
                endcase
                if (prdata !== m_rd) fail("prdata", prdata, m_rd);
                nreads = nreads + 1;
            end
        end
        m_wr  = psel && penable && pwrite && m_known;
        m_hit = m_en && (m_count == m_cmp);
        if (m_hit) nmatch = nmatch + 1;
        // MATCH: set wins over clear
        if (m_hit) m_match = 1;
        else if (m_wr && ofs == 12'h00C && pwdata[0]) m_match = 0;
        // COUNT: write wins over counting
        if (m_wr && ofs == 12'h004) m_count = pwdata;
        else if (m_en) m_count = (m_hit && m_auto) ? 0 : m_count + 1;
        if (m_wr && ofs == 12'h000) {m_ie, m_auto, m_en} = pwdata[2:0];
        if (m_wr && ofs == 12'h008) m_cmp = pwdata;
    end

    // compare DUT state with the model in the middle of every cycle
    always @(negedge clk) if (presetn) begin
        if (dut.count !== m_count)                      fail("count", dut.count, m_count);
        if (dut.match_flag !== m_match)                 fail("MATCH", dut.match_flag, m_match);
        if ({dut.ie, dut.auto_rl, dut.en} !== {m_ie, m_auto, m_en}) fail("CTRL", {dut.ie, dut.auto_rl, dut.en}, {m_ie, m_auto, m_en});
        if (dut.cmp !== m_cmp)                          fail("CMP", dut.cmp, m_cmp);
        if (irq !== (m_ie & m_match))                   fail("irq", irq, m_ie & m_match);
    end

    reg [31:0] rd; reg er;
    task wr(input [11:0] o, input [31:0] d); begin apb_write({20'd0, o}, d, er); end endtask
    task rdreg(input [11:0] o); begin apb_read({20'd0, o}, rd, er); end endtask

    integer t, seed, n, last, gap;
    reg [11:0] o;
    initial begin
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        #12 presetn = 1;

        // reset values
        rdreg(12'h000); if (rd !== 0) fail("reset CTRL", rd, 0);
        rdreg(12'h004); if (rd !== 0) fail("reset COUNT", rd, 0);

        // 1) one-shot: count from 0 to CMP = 10
        wr(12'h008, 10); wr(12'h004, 0);
        wr(12'h000, 32'b001);                       // EN; counting starts at the edge that completes this write
        n = 0;
        while (dut.match_flag !== 1'b1 && n < 50) begin @(posedge clk); #1; n = n + 1; end
        if (n != 11) fail("one-shot edges until MATCH", n, 11);
        repeat (5) @(posedge clk); #1;
        if (dut.count !== 32'd16) fail("no reload without AUTO (count)", dut.count, 16);

        // 3) write-1-to-clear
        wr(12'h00C, 32'h1); rdreg(12'h00C); if (rd !== 0) fail("W1C", rd, 0);

        // 2) auto reload: CMP = 4 -> a match every 5 clocks
        wr(12'h000, 32'b000); wr(12'h004, 0); wr(12'h008, 4); wr(12'h000, 32'b011);
        last = -1;
        for (n = 0; n < 40; n = n + 1) begin
            @(negedge clk);
            if (dut.match) begin
                if (last >= 0 && (n - last) != 5) fail("auto reload period", n - last, 5);
                last = n;
            end
        end

        // 3b) a new match in the same cycle as a clear: CMP = 0 with AUTO matches every clock
        wr(12'h008, 0); wr(12'h004, 0);
        wr(12'h00C, 32'h1);
        if (dut.match_flag !== 1'b1) fail("set wins over clear", dut.match_flag, 1);

        // 4) irq
        wr(12'h000, 32'b000); wr(12'h00C, 1);
        if (irq !== 0) fail("irq when MATCH = 0", irq, 0);
        wr(12'h008, 3); wr(12'h004, 0); wr(12'h000, 32'b101);  // EN + IE
        repeat (6) @(posedge clk); #1;
        if (irq !== 1) fail("irq = IE & MATCH", irq, 1);
        wr(12'h000, 32'b001); if (irq !== 0) fail("irq off when IE = 0", irq, 0);

        // 5) EN = 0 holds, COUNT write
        wr(12'h000, 0); wr(12'h004, 32'h1234_5678);
        repeat (10) @(posedge clk); #1;
        if (dut.count !== 32'h1234_5678) fail("hold when EN = 0", dut.count, 32'h1234_5678);
        wr(12'h000, 1); wr(12'h004, 32'hFFFF_FFFE);              // write wins while counting
        repeat (3) @(posedge clk); #1;                            // wraps past 0xFFFFFFFF

        // 6) unknown offsets
        wr(12'h010, 32'hFFFF_FFFF); if (er !== 1) fail("pslverr 0x010", er, 1);
        rdreg(12'hFFC);             if (er !== 1 || rd !== 0) fail("unknown read", rd, 0);
        wr(12'h001, 32'hFFFF_FFFF); if (er !== 1) fail("pslverr 0x001", er, 1);

        // 7) random
        for (t = 0; t < 3000; t = t + 1) begin
            case ($unsigned($random(seed)) % 10)
                0, 1:    o = 12'h000;
                2, 3:    o = 12'h004;
                4, 5:    o = 12'h008;
                6, 7:    o = 12'h00C;
                default: o = $random(seed);
            endcase
            if ($random(seed) & 1) begin
                case (o)
                    12'h004, 12'h008: wr(o, $unsigned($random(seed)) % 24);   // small values: frequent matches
                    default:          wr(o, $random(seed));
                endcase
            end else
                rdreg(o);
            repeat ($unsigned($random(seed)) % 4) @(posedge clk);
        end

        #20;
        if (errors == 0) $display("PASS: apb_timer (%0d reads checked, %0d matches)", nreads, nmatch);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #3000000 $display("FAIL: timeout");
        $finish;
    end
endmodule
