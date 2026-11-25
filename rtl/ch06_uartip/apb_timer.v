`timescale 1ns/1ps

// TIMER - APB3 slave, 32-bit up counter with compare (03_chapters/ch14a_mcu/design.md sec. 5.2)
//  Registers (32-bit, word access only; offsets from the TIMER base 0x4000_1000)
//    0x00 CTRL    R/W  bit0 EN   : count up by 1 every clock
//                      bit1 AUTO : on a match the counter goes back to 0 (period = CMP + 1 clocks)
//                      bit2 IE   : drive irq when MATCH is set
//    0x04 COUNT   R/W  counter value (a write sets the counter)
//    0x08 CMP     R/W  compare value
//    0x0C STATUS  R/W1C bit0 MATCH: set when COUNT == CMP while EN = 1; write 1 to clear
//  Rules at each rising edge (when EN = 1):
//    match = (COUNT == CMP)  -> MATCH <= 1
//    COUNT <= match & AUTO ? 0 : COUNT + 1
//    A COUNT write from APB in the same cycle wins over counting; a new match wins over a MATCH clear.
//  - irq = IE & MATCH (connected to the interrupt logic in ch6)
//  - No wait states: PREADY = 1; PSLVERR = 1 for an unknown offset (nothing changes, reads 0)
module apb_timer (
    input             pclk,
    input             presetn,       // reset when 0 (asynchronous)
    // APB3 slave
    input             psel,
    input             penable,
    input             pwrite,
    input      [11:0] paddr,         // offset inside the 4 KB slot
    input      [31:0] pwdata,
    output reg [31:0] prdata,
    output            pready,
    output            pslverr,
    // interrupt request (level)
    output            irq
);
    localparam OFS_CTRL   = 12'h000,
               OFS_COUNT  = 12'h004,
               OFS_CMP    = 12'h008,
               OFS_STATUS = 12'h00C;

    reg        en, auto_rl, ie, match_flag;
    reg [31:0] count, cmp;

    // -- APB decode --
    wire access    = psel & penable;
    wire is_ctrl   = (paddr == OFS_CTRL);
    wire is_count  = (paddr == OFS_COUNT);
    wire is_cmp    = (paddr == OFS_CMP);
    wire is_status = (paddr == OFS_STATUS);
    wire known     = is_ctrl | is_count | is_cmp | is_status;
    wire wr        = access & pwrite & known;

    assign pready  = 1'b1;
    assign pslverr = access & ~known;

    // -- Counter --
    wire match = en & (count == cmp);

    always @(posedge pclk or negedge presetn)
        if (!presetn)
            count <= 32'd0;
        else if (wr && is_count)
            count <= pwdata;                          // software write wins
        else if (en)
            count <= (match && auto_rl) ? 32'd0 : count + 32'd1;

    // -- MATCH flag (set has priority over clear) --
    always @(posedge pclk or negedge presetn)
        if (!presetn)
            match_flag <= 1'b0;
        else if (match)
            match_flag <= 1'b1;
        else if (wr && is_status && pwdata[0])
            match_flag <= 1'b0;                       // write 1 to clear

    // -- CTRL, CMP --
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin
            en <= 1'b0; auto_rl <= 1'b0; ie <= 1'b0;
            cmp <= 32'd0;
        end else if (wr) begin
            if (is_ctrl) {ie, auto_rl, en} <= pwdata[2:0];
            if (is_cmp)  cmp <= pwdata;
        end

    // -- Read data --
    always @(*) begin
        prdata = 32'd0;
        if (is_ctrl)   prdata = {29'd0, ie, auto_rl, en};
        if (is_count)  prdata = count;
        if (is_cmp)    prdata = cmp;
        if (is_status) prdata = {31'd0, match_flag};
    end

    assign irq = ie & match_flag;
endmodule
