`timescale 1ns/1ps
`include "mcu_memmap.vh"
// Self-checking testbench for bus_mux + apb_bridge (03_chapters/ch14a_mcu/design.md sec. 2, 2.2, 4)
//  - A master model drives the core data port like rv32i_core: it holds the request until dmem_ready.
//  - Memories: IMEM data-side read model (preloaded), DMEM byte-write model.
//  - APB slaves: model slaves in slots 0, 1, 2, 15 (4 KB of registers each, random PREADY wait states,
//    PSLVERR at offset 0xFFC); the other slots are tied to "no slave" (PREADY=1, PSLVERR=1, PRDATA=0).
//  - A reference model (scoreboard) predicts read data, error and the number of cycles.
//  - An APB protocol checker watches every cycle:
//      at most one PSEL, PENABLE only with PSEL, SETUP is followed by ACCESS, ACCESS only after SETUP
//      or a waiting ACCESS, PSEL/PADDR/PWRITE/PWDATA stable from SETUP to the end of ACCESS.
// Checks
//  1) directed: each target read/write, error cases, fetch address check
//  2) random: 4000 accesses over all targets (plusarg +WAITPCT=<0..90> sets slave wait %, +SEED=<n>)
module bus_tb;
    localparam NSLOT = 16;

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    // -- core-side request (master model) --
    reg         dmem_re = 0;
    reg  [31:0] dmem_addr = 0, dmem_wdata = 0, imem_addr = 0;
    reg  [3:0]  dmem_wstrb = 0;
    wire [31:0] dmem_rdata;
    wire        dmem_ready, data_err, fetch_err;

    // -- memory ports --
    wire [31:0] irom_addr, ram_addr, ram_wdata;
    wire [3:0]  ram_wstrb;
    reg  [31:0] imem  [0:4095];
    reg  [7:0]  dram  [0:16383];
    wire [31:0] irom_rdata = imem[irom_addr[13:2]];
    wire [31:0] ram_rdata  = {dram[{ram_addr[13:2], 2'd3}], dram[{ram_addr[13:2], 2'd2}],
                              dram[{ram_addr[13:2], 2'd1}], dram[{ram_addr[13:2], 2'd0}]};
    always @(posedge clk) begin : dram_write
        integer b;
        for (b = 0; b < 4; b = b + 1)
            if (ram_wstrb[b]) dram[{ram_addr[13:2], b[1:0]}] <= ram_wdata[8*b +: 8];
    end

    // -- bus_mux <-> apb_bridge --
    wire        apb_req, apb_write, apb_ready, apb_err;
    wire [31:0] apb_rdata;

    // -- APB --
    wire [31:0]         paddr, pwdata;
    wire                pwrite, penable;
    wire [NSLOT-1:0]    psel;
    wire [NSLOT*32-1:0] prdata;
    wire [NSLOT-1:0]    pready, pslverr;

    bus_mux u_mux (
        .dmem_re(dmem_re), .dmem_addr(dmem_addr), .dmem_wstrb(dmem_wstrb), .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready),
        .imem_addr(imem_addr), .data_err(data_err), .fetch_err(fetch_err),
        .irom_addr(irom_addr), .irom_rdata(irom_rdata),
        .ram_addr(ram_addr), .ram_wstrb(ram_wstrb), .ram_wdata(ram_wdata), .ram_rdata(ram_rdata),
        .apb_req(apb_req), .apb_write(apb_write), .apb_rdata(apb_rdata), .apb_ready(apb_ready), .apb_err(apb_err)
    );

    apb_bridge u_bridge (
        .clk(clk), .rst_n(rst_n),
        .req(apb_req), .write(apb_write), .addr(dmem_addr), .wdata(dmem_wdata),
        .rdata(apb_rdata), .ready(apb_ready), .err(apb_err),
        .paddr(paddr), .pwrite(pwrite), .pwdata(pwdata), .penable(penable), .psel(psel),
        .prdata(prdata), .pready(pready), .pslverr(pslverr)
    );

    // -- APB model slaves (slots 0, 1, 2, 15) and empty slots --
    integer waitpct, seed;
    reg [31:0] sregs [0:NSLOT*1024-1];          // slave registers, index {slot, word}
    reg [NSLOT-1:0] rdy_rand = {NSLOT{1'b1}};
    function has_slave(input integer s);
        has_slave = (s == 0) || (s == 1) || (s == 2) || (s == 15);
    endfunction

    genvar g;
    generate for (g = 0; g < NSLOT; g = g + 1) begin : slv
        if (g == 0 || g == 1 || g == 2 || g == 15) begin : model
            assign prdata[32*g +: 32] = sregs[g*1024 + paddr[11:2]];
            assign pready[g]          = rdy_rand[g];
            assign pslverr[g]         = (paddr[11:0] == 12'hFFC);
            always @(posedge clk)
                if (psel[g] && penable && pready[g] && pwrite) sregs[g*1024 + paddr[11:2]] <= pwdata;
        end else begin : empty
            assign prdata[32*g +: 32] = 32'd0;
            assign pready[g]          = 1'b1;
            assign pslverr[g]         = 1'b1;
        end
    end endgenerate

    // new random PREADY per slave each cycle
    integer r, k;
    always @(posedge clk) for (k = 0; k < NSLOT; k = k + 1) begin
        r = $random(seed); if (r < 0) r = -r;
        rdy_rand[k] <= (waitpct == 0) ? 1'b1 : ((r % 100) >= waitpct);
    end

    // -- APB protocol checker (sampled at each rising edge = values of the cycle that just ended;
    //    the master changes its request at the falling edge, so this does not race with it) --
    integer errors = 0;
    reg        p_valid = 0, p_setup = 0, p_wait = 0;
    reg [NSLOT-1:0] p_psel;
    reg [31:0] p_paddr, p_pwdata;
    reg        p_pwrite;
    integer apb_transfers = 0;
    task perr(input [8*60:1] msg);
        begin
            if (errors < 10) $display("FAIL: APB protocol: %0s at %0t", msg, $time);
            errors = errors + 1;
        end
    endtask
    always @(posedge clk) if (rst_n) begin
        if ((psel & (psel - 1)) != 0)             perr("more than one PSEL");
        if (penable && psel == 0)                 perr("PENABLE without PSEL");
        if (p_setup && !(penable && psel != 0))   perr("SETUP not followed by ACCESS");
        if (penable && !(p_setup || p_wait))      perr("ACCESS without SETUP");
        if ((p_setup || p_wait) &&
            (psel !== p_psel || paddr !== p_paddr || pwrite !== p_pwrite || (pwrite && pwdata !== p_pwdata)))
                                                  perr("signals changed during transfer");
        p_setup  = (psel != 0) && !penable;
        p_wait   = (psel != 0) && penable && !(|(psel & pready));
        if ((psel != 0) && penable && (|(psel & pready))) apb_transfers = apb_transfers + 1;
        p_psel = psel; p_paddr = paddr; p_pwrite = pwrite; p_pwdata = pwdata;
    end

    // -- reference model --
    reg [31:0] ref_sreg [0:NSLOT*1024-1];
    reg [7:0]  ref_dram [0:16383];
    integer n_ok = 0;

    task fail(input [8*60:1] what, input [31:0] addr, input [31:0] got, input [31:0] exp);
        begin
            if (errors < 10) $display("FAIL: %0s addr=%h got %h expected %h at %0t", what, addr, got, exp, $time);
            errors = errors + 1;
        end
    endtask

    // One access like the core: request held until dmem_ready; returns data, error, cycles
    reg [31:0] got_data; reg got_err; integer got_cyc;
    task access(input wr, input [31:0] a, input [3:0] strb, input [31:0] d);
        begin
            @(negedge clk);
            dmem_addr = a; dmem_wdata = d;
            dmem_re = !wr; dmem_wstrb = wr ? strb : 4'b0000;
            got_cyc = 1; #1;
            while (!dmem_ready) begin
                @(negedge clk); #1; got_cyc = got_cyc + 1;
                if (got_cyc > 200) begin fail("no ready", a, 0, 0); disable access; end
            end
            got_data = dmem_rdata; got_err = data_err;
            @(posedge clk); #1;
            dmem_re = 0; dmem_wstrb = 0;
        end
    endtask

    // Expected result of an access (and update of the reference model)
    reg [31:0] exp_data; reg exp_err; reg exp_apb;
    task predict(input wr, input [31:0] a, input [3:0] strb, input [31:0] d);
        integer s, b;
        begin
            exp_data = 0; exp_err = 0; exp_apb = 0;
            s = a[15:12];
            if (`MM_IMEM_HIT(a)) begin
                if (wr) exp_err = 1; else exp_data = imem[a[13:2]];
            end else if (`MM_DMEM_HIT(a)) begin
                for (b = 0; b < 4; b = b + 1) begin
                    if (wr && strb[b]) ref_dram[{a[13:2], b[1:0]}] = d[8*b +: 8];
                    exp_data[8*b +: 8] = ref_dram[{a[13:2], b[1:0]}];
                end
                if (wr) exp_data = 0;
            end else if (`MM_APB_HIT(a)) begin
                if (wr && strb != 4'b1111) exp_err = 1;               // partial write to APB: no transfer
                else begin
                    exp_apb = 1;
                    if (has_slave(s)) begin
                        if (wr) ref_sreg[{s[3:0], a[11:2]}] = d;
                        else    exp_data = ref_sreg[{s[3:0], a[11:2]}];
                        exp_err = (a[11:0] == 12'hFFC);
                    end else
                        exp_err = 1;                                   // empty slot
                end
            end else
                exp_err = 1;                                           // unmapped
        end
    endtask

    task check(input wr, input [31:0] a, input [3:0] strb, input [31:0] d);
        integer before;
        begin
            predict(wr, a, strb, d);
            before = apb_transfers;
            access(wr, a, strb, d);
            if (!wr && got_data !== exp_data)       fail("read data", a, got_data, exp_data);
            if (got_err !== exp_err)                fail("data_err", a, got_err, exp_err);
            if (exp_apb && got_cyc < 2)             fail("APB took < 2 cycles", a, got_cyc, 2);
            if (!exp_apb && got_cyc != 1)           fail("non-APB not 1 cycle", a, got_cyc, 1);
            if ((apb_transfers - before) != (exp_apb ? 1 : 0)) fail("APB transfer count", a, apb_transfers - before, exp_apb);
            n_ok = n_ok + 1;
        end
    endtask

    task fetch_check(input [31:0] a, input exp);
        begin
            imem_addr = a; #1;
            if (fetch_err !== exp) fail("fetch_err", a, fetch_err, exp);
        end
    endtask

    integer i, t;
    reg [31:0] ra, rd; reg [3:0] rs; reg rw;
    initial begin
        if (!$value$plusargs("WAITPCT=%d", waitpct)) waitpct = 30;
        if (!$value$plusargs("SEED=%d", seed))       seed    = 1;
        for (i = 0; i < 4096; i = i + 1)        imem[i] = 32'hA000_0000 + i * 32'h0001_0001;
        for (i = 0; i < 16384; i = i + 1)       begin dram[i] = i[7:0] ^ 8'h5A; ref_dram[i] = i[7:0] ^ 8'h5A; end
        for (i = 0; i < NSLOT*1024; i = i + 1)  begin sregs[i] = 32'hC000_0000 + i; ref_sreg[i] = 32'hC000_0000 + i; end
        #12 rst_n = 1;

        // 1) directed
        check(0, 32'h0000_0000, 0, 0);                  // IMEM first word
        check(0, 32'h0000_3FFC, 0, 0);                  // IMEM last word
        check(1, 32'h0000_0010, 4'b1111, 32'hDEAD_BEEF);// write to IMEM -> error
        check(1, 32'h1000_0000, 4'b1111, 32'h1122_3344);// DMEM word
        check(0, 32'h1000_0000, 0, 0);
        check(1, 32'h1000_3FFE, 4'b1100, 32'hAABB_0000);// DMEM high half of last word
        check(0, 32'h1000_3FFC, 0, 0);
        check(1, 32'h4000_0004, 4'b1111, 32'h0000_00F0);// GPIO slot 0
        check(0, 32'h4000_0004, 0, 0);
        check(1, 32'h4000_2008, 4'b1111, 32'h1234_5678);// UART slot 2
        check(0, 32'h4000_2008, 0, 0);
        check(0, 32'h4000_F000, 0, 0);                  // SIMCTL slot 15
        check(1, 32'h4000_1000, 4'b0001, 32'h0000_0055);// sb to APB -> error, no transfer
        check(0, 32'h4000_1FFC, 0, 0);                  // PSLVERR offset
        check(0, 32'h4000_5000, 0, 0);                  // empty slot 5 -> error
        check(1, 32'h4000_5000, 4'b1111, 32'h1);        // empty slot write -> error
        check(0, 32'h2000_0000, 0, 0);                  // unmapped
        check(1, 32'h1000_4000, 4'b1111, 32'h1);        // just past DMEM -> unmapped
        check(0, 32'h4001_0000, 0, 0);                  // just past APB window
        fetch_check(32'h0000_0000, 0);
        fetch_check(32'h0000_3FFC, 0);
        fetch_check(32'h0000_4000, 1);
        fetch_check(32'h1000_0000, 1);
        fetch_check(32'hFFFF_FFFC, 1);

        // 2) random accesses
        for (t = 0; t < 4000; t = t + 1) begin
            rw = $random(seed); rd = $random(seed);
            case ($unsigned($random(seed)) % 8)
                0:       ra = ($unsigned($random(seed)) % 4096) * 4;                              // IMEM
                1, 2:    ra = 32'h1000_0000 | ($unsigned($random(seed)) % 16384);                 // DMEM
                3:       ra = 32'h4000_0000 | ($unsigned($random(seed)) % 1024) * 4;              // GPIO
                4:       ra = 32'h4000_1000 | ($unsigned($random(seed)) % 1024) * 4;              // TIMER
                5:       ra = 32'h4000_2000 | ($unsigned($random(seed)) % 1024) * 4;              // UART
                6:       ra = 32'h4000_0000 | (($unsigned($random(seed)) % 16) << 12) | 12'hFFC; // any slot, err offset
                default: ra = $random(seed) & 32'hFFFF_FFFC;                                      // anywhere
            endcase
            case ($unsigned($random(seed)) % 3)
                0:       rs = 4'b0001 << ra[1:0];                                   // byte
                1:       begin ra[0] = 1'b0; rs = ra[1] ? 4'b1100 : 4'b0011; end   // halfword
                default: begin ra[1:0] = 2'b00; rs = 4'b1111; end                 // word
            endcase
            check(rw, ra, rs, rd);
        end

        if (errors == 0) $display("PASS: bus_mux + apb_bridge (%0d accesses, %0d APB transfers, WAITPCT=%0d)", n_ok, apb_transfers, waitpct);
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #5000000 $display("FAIL: timeout");
        $finish;
    end
endmodule
