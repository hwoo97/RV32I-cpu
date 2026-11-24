`timescale 1ns/1ps

// UART IP top - APB3 slave with TX/RX FIFOs, 5..8 data bits, parity, 1/2 stop bits, interrupts,
// 16x oversampling with majority vote, loopback (03_chapters/ip_uart/design.md)
//  One clock (pclk) for the bus and the serial logic; the baud rate comes from a tick enable.
//  Loopback: the transmitter output goes into the receiver, the uart_tx pin stays idle (1)
//  and the uart_rx pin is ignored.
module uart_top #(
    parameter [15:0] DIV_RESET = 16'd108,  // 200 MHz -> 114,679 baud
    parameter        FIFO_AW   = 4         // FIFO depth = 2**FIFO_AW (16)
) (
    input         pclk,
    input         presetn,              // asynchronous reset, active low
    // APB3 slave
    input         psel,
    input         penable,
    input         pwrite,
    input  [11:0] paddr,
    input  [31:0] pwdata,
    output [31:0] prdata,
    output        pready,
    output        pslverr,
    // interrupt and serial line
    output        irq,
    input         uart_rx,
    output        uart_tx
);
    wire        tx_en, rx_en, pen, peven, stop2, loopback;
    wire [1:0]  dbits;
    wire [15:0] div;
    wire        tick;

    wire        tx_wr, tx_clr, tx_full, tx_empty, tx_busy, tx_rd;
    wire [7:0]  tx_wdata, tx_rdata;
    wire [FIFO_AW:0] tx_count;
    wire        rx_rd, rx_clr, rx_full, rx_empty, rx_push, rx_start;
    wire [9:0]  rx_rdata, rx_pdata;
    wire [FIFO_AW:0] rx_count;
    wire        txd;

    uart_regs #(.DIV_RESET(DIV_RESET)) u_regs (
        .clk(pclk), .rst_n(presetn),
        .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
        .prdata(prdata), .pready(pready), .pslverr(pslverr), .irq(irq),
        .tx_en(tx_en), .rx_en(rx_en), .dbits(dbits), .pen(pen), .peven(peven), .stop2(stop2),
        .loopback(loopback), .div(div),
        .tx_wr(tx_wr), .tx_wdata(tx_wdata), .tx_clr(tx_clr), .tx_count(tx_count[4:0]),
        .tx_full(tx_full), .tx_empty(tx_empty), .tx_busy(tx_busy),
        .rx_rd(rx_rd), .rx_rdata(rx_rdata), .rx_clr(rx_clr), .rx_count(rx_count[4:0]),
        .rx_full(rx_full), .rx_empty(rx_empty), .rx_push(rx_push), .rx_pdata(rx_pdata),
        .rx_start(rx_start), .tick(tick)
    );

    uart_baud u_baud (.clk(pclk), .rst_n(presetn), .div(div), .tick(tick));

    uart_fifo #(.W(8), .AW(FIFO_AW)) u_txf (
        .clk(pclk), .rst_n(presetn), .clr(tx_clr),
        .wr(tx_wr), .wdata(tx_wdata), .rd(tx_rd), .rdata(tx_rdata),
        .count(tx_count), .full(tx_full), .empty(tx_empty)
    );

    uart_tx u_tx (
        .clk(pclk), .rst_n(presetn), .tick(tick), .en(tx_en),
        .fifo_empty(tx_empty), .fifo_data(tx_rdata), .fifo_rd(tx_rd),
        .dbits(dbits), .pen(pen), .peven(peven), .stop2(stop2),
        .txd(txd), .busy(tx_busy)
    );

    uart_rx u_rx (
        .clk(pclk), .rst_n(presetn), .tick(tick), .en(rx_en),
        .rxd(loopback ? txd : uart_rx),
        .dbits(dbits), .pen(pen), .peven(peven),
        .push(rx_push), .pdata(rx_pdata), .start_ok(rx_start), .busy()
    );

    uart_fifo #(.W(10), .AW(FIFO_AW)) u_rxf (
        .clk(pclk), .rst_n(presetn), .clr(rx_clr),
        .wr(rx_push), .wdata(rx_pdata), .rd(rx_rd), .rdata(rx_rdata),
        .count(rx_count), .full(rx_full), .empty(rx_empty)
    );

    assign uart_tx = loopback ? 1'b1 : txd;
endmodule
