`timescale 1ns/1ps
`include "uart_defs.vh"

// UART IP registers, APB3 decode and interrupts (03_chapters/ip_uart/design.md sec. 3, 6)
//  - 32-bit word access, PREADY = 1. PSLVERR for an unknown offset (also paddr[1:0] != 0), a read of
//    TXDATA or a write of RXDATA / STATUS; nothing changes and the read data is 0.
//  - A RXDATA read takes the oldest byte out of the RX FIFO (if any). Empty -> bit 31 = 1, FIFO unchanged.
//  - ISR: level bits come straight from the state, sticky bits are set by events and cleared by
//    writing 1 (W1C). A set and a clear in the same clock -> the bit stays 1.
//  - RX timeout: RX FIFO not empty and 4 character times (in ticks) with no byte received, no
//    confirmed start bit and no RXDATA read.
//  - irq = |(ISR & IER), registered (one clock after the cause).
module uart_regs #(
    parameter [15:0] DIV_RESET = 16'd108       // 200 MHz / (16 * 109) = 114,679 baud (115,200 - 0.45 %)
) (
    input             clk,
    input             rst_n,
    // APB3 slave
    input             psel,
    input             penable,
    input             pwrite,
    input      [11:0] paddr,
    input      [31:0] pwdata,
    output reg [31:0] prdata,
    output            pready,
    output            pslverr,
    output reg        irq,
    // configuration
    output reg        tx_en,
    output reg        rx_en,
    output reg [1:0]  dbits,
    output reg        pen,
    output reg        peven,
    output reg        stop2,
    output reg        loopback,
    output reg [15:0] div,
    // TX FIFO / transmitter
    output            tx_wr,
    output     [7:0]  tx_wdata,
    output            tx_clr,
    input      [4:0]  tx_count,
    input             tx_full,
    input             tx_empty,
    input             tx_busy,
    // RX FIFO / receiver
    output            rx_rd,
    input      [9:0]  rx_rdata,
    output            rx_clr,
    input      [4:0]  rx_count,
    input             rx_full,
    input             rx_empty,
    input             rx_push,          // receiver delivers a byte this clock
    input      [9:0]  rx_pdata,         // {ferr, perr, data}
    input             rx_start,         // receiver confirmed a start bit
    input             tick
);
    // -- APB decode --
    wire access   = psel & penable;
    wire is_tx    = (paddr == `UART_OFS_TXDATA);
    wire is_rx    = (paddr == `UART_OFS_RXDATA);
    wire is_st    = (paddr == `UART_OFS_STATUS);
    wire is_ctrl  = (paddr == `UART_OFS_CTRL);
    wire is_baud  = (paddr == `UART_OFS_BAUD);
    wire is_thr   = (paddr == `UART_OFS_FIFO_THR);
    wire is_ier   = (paddr == `UART_OFS_IER);
    wire is_isr   = (paddr == `UART_OFS_ISR);
    wire is_rw    = is_ctrl | is_baud | is_thr | is_ier | is_isr;
    wire ok_write = is_tx | is_rw;
    wire ok_read  = is_rx | is_st | is_rw;
    wire good     = pwrite ? ok_write : ok_read;
    wire wr       = access &  pwrite & good;
    wire rd       = access & ~pwrite & good;

    assign pready  = 1'b1;
    assign pslverr = access & ~good;

    // -- configuration registers --
    reg [4:0] rx_thr;                   // RXTHR when rx_count >= rx_thr (and not empty)
    reg [4:0] tx_thr;                   // TXTHR when tx_count <= tx_thr
    reg [7:0] ier;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            tx_en    <= 1'b1;
            rx_en    <= 1'b1;
            dbits    <= 2'd3;           // 8N1
            pen      <= 1'b0;
            peven    <= 1'b0;
            stop2    <= 1'b0;
            loopback <= 1'b0;
            div      <= DIV_RESET;
            rx_thr   <= 5'd1;
            tx_thr   <= 5'd0;
            ier      <= 8'd0;
        end else if (wr) begin
            if (is_ctrl) begin
                tx_en    <= pwdata[0];
                rx_en    <= pwdata[1];
                dbits    <= pwdata[3:2];
                pen      <= pwdata[4];
                peven    <= pwdata[5];
                stop2    <= pwdata[6];
                loopback <= pwdata[7];
            end
            if (is_baud) div <= pwdata[15:0];
            if (is_thr) begin
                rx_thr <= pwdata[4:0];
                tx_thr <= pwdata[12:8];
            end
            if (is_ier) ier <= pwdata[7:0];
        end

    // -- FIFO access --
    assign tx_wr    = wr & is_tx;                   // ignored by the FIFO when full (TXOVR below)
    assign tx_wdata = pwdata[7:0];
    assign tx_clr   = wr & is_ctrl & pwdata[8];
    assign rx_clr   = wr & is_ctrl & pwdata[9];
    assign rx_rd    = rd & is_rx;                   // ignored by the FIFO when empty

    // -- RX timeout --
    // character = start + data (5..8) + parity (0/1) + stop (1/2) bits; 4 characters x 16 ticks
    //   = 1 + (5 + dbits) + pen + (1 + stop2) = 7 + dbits + pen + stop2  (7 .. 12)
    wire [3:0] char_bits = 4'd7 + {2'b00, dbits} + {3'b000, pen} + {3'b000, stop2};
    wire [9:0] to_limit  = {char_bits, 6'd0};
    reg  [9:0] to_cnt;
    reg        rxto;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            to_cnt <= 10'd0;
            rxto   <= 1'b0;
        end else if (rx_empty || rx_rd || rx_push || rx_start || rx_clr) begin
            to_cnt <= 10'd0;
            rxto   <= 1'b0;
        end else if (tick && !rxto) begin
            if (to_cnt == to_limit - 10'd1) rxto <= 1'b1;
            to_cnt <= to_cnt + 10'd1;
        end

    // -- interrupt status --
    wire lv_rxthr  = ~rx_empty & (rx_count >= rx_thr);
    wire lv_txthr  = (tx_count <= tx_thr);
    wire lv_txdone = tx_empty & ~tx_busy;

    reg st_rxovr, st_perr, st_ferr, st_txovr;
    wire w1c = wr & is_isr;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            st_rxovr <= 1'b0;
            st_perr  <= 1'b0;
            st_ferr  <= 1'b0;
            st_txovr <= 1'b0;
        end else begin
            if (rx_push & rx_full)            st_rxovr <= 1'b1;
            else if (w1c & pwdata[`UART_ISR_RXOVR]) st_rxovr <= 1'b0;
            if (rx_push & rx_pdata[8])        st_perr  <= 1'b1;
            else if (w1c & pwdata[`UART_ISR_PERR])  st_perr  <= 1'b0;
            if (rx_push & rx_pdata[9])        st_ferr  <= 1'b1;
            else if (w1c & pwdata[`UART_ISR_FERR])  st_ferr  <= 1'b0;
            if (tx_wr & tx_full)              st_txovr <= 1'b1;
            else if (w1c & pwdata[`UART_ISR_TXOVR]) st_txovr <= 1'b0;
        end

    wire [7:0] isr = {st_txovr, st_ferr, st_perr, st_rxovr, rxto, lv_txdone, lv_txthr, lv_rxthr};

    always @(posedge clk or negedge rst_n)
        if (!rst_n) irq <= 1'b0;
        else        irq <= |(isr & ier);

    // -- read data (valid in the ACCESS cycle) --
    always @(*) begin
        prdata = 32'd0;
        if (rd) begin
            if (is_rx)   prdata = rx_empty ? 32'h8000_0000 : {22'd0, rx_rdata};
            if (is_st)   prdata = {11'd0, rx_count, 3'd0, tx_count, 3'd0,
                                   tx_busy, rx_empty, rx_full, tx_empty, tx_full};
            if (is_ctrl) prdata = {24'd0, loopback, stop2, peven, pen, dbits, rx_en, tx_en};
            if (is_baud) prdata = {16'd0, div};
            if (is_thr)  prdata = {19'd0, tx_thr, 3'd0, rx_thr};
            if (is_ier)  prdata = {24'd0, ier};
            if (is_isr)  prdata = {24'd0, isr};
        end
    end
endmodule
