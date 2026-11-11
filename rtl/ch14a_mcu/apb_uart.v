`timescale 1ns/1ps

// UART - APB3 slave, 8N1 (8 data bits LSB first, no parity, 1 stop bit) (03_chapters/ch14a_mcu/design.md sec. 5.3)
//  Registers (32-bit, word access only; offsets from the UART base 0x4000_2000)
//    0x00 TXDATA   W   send the low 8 bits; ignored while TX_FULL = 1
//    0x04 RXDATA   R   last received byte; reading clears RX_VALID
//    0x08 STATUS   R   bit0 TX_FULL     : cannot take a new byte (transmit buffer occupied)
//                      bit1 RX_VALID    : a received byte is waiting in RXDATA
//                      bit2 RX_OVERRUN  : a byte arrived while RX_VALID was 1 (the new byte replaced it)
//                      bit3 TX_IDLE     : nothing to send and the line is idle
//                      bit4 RX_FRAME    : a byte was dropped because its stop bit was 0
//                      reading STATUS clears RX_OVERRUN and RX_FRAME
//    0x0C BAUDDIV  R/W clocks per bit - 1 (16 bits), e.g. 50 MHz / 115200 -> 433. Minimum 3
//  Buffers: transmit holding register (1 byte) + shift register, receive buffer (1 byte).
//    TX_FULL / RX_VALID keep the same meaning if FIFOs are added later (design.md sec. 9 improvement 1).
//  Receive: 2-flop synchronizer, start bit confirmed at half a bit, then each bit sampled in its middle.
//  PSLVERR = 1 for an unknown offset, a write to RXDATA/STATUS or a read of TXDATA (nothing changes, reads 0).
//  No wait states: PREADY = 1.
module apb_uart #(
    parameter [15:0] DIV_RESET = 16'd433      // BAUDDIV after reset
) (
    input             pclk,
    input             presetn,                 // reset when 0 (asynchronous)
    // APB3 slave
    input             psel,
    input             penable,
    input             pwrite,
    input      [11:0] paddr,                   // offset inside the 4 KB slot
    input      [31:0] pwdata,
    output reg [31:0] prdata,
    output            pready,
    output            pslverr,
    // serial line
    input             uart_rx,
    output            uart_tx
);
    localparam OFS_TXDATA  = 12'h000,
               OFS_RXDATA  = 12'h004,
               OFS_STATUS  = 12'h008,
               OFS_BAUDDIV = 12'h00C;

    // -- APB decode --
    wire access     = psel & penable;
    wire is_txdata  = (paddr == OFS_TXDATA);
    wire is_rxdata  = (paddr == OFS_RXDATA);
    wire is_status  = (paddr == OFS_STATUS);
    wire is_bauddiv = (paddr == OFS_BAUDDIV);
    wire ok_write   = is_txdata | is_bauddiv;
    wire ok_read    = is_rxdata | is_status | is_bauddiv;
    wire good       = pwrite ? ok_write : ok_read;
    wire wr         = access &  pwrite & good;
    wire rd         = access & ~pwrite & good;

    assign pready  = 1'b1;
    assign pslverr = access & ~good;

    reg [15:0] div;
    always @(posedge pclk or negedge presetn)
        if (!presetn)               div <= DIV_RESET;
        else if (wr && is_bauddiv)  div <= pwdata[15:0];

    // ================= Transmit =================
    reg [7:0]  thr;          // holding register
    reg        thr_full;
    reg [9:0]  tsr;          // shift register: {stop, data[7:0], start}
    reg        tbusy;
    reg [3:0]  tbit;         // bit index 0..9
    reg [15:0] tcnt;         // clocks inside the current bit

    always @(posedge pclk or negedge presetn)
        if (!presetn) begin
            thr <= 8'd0; thr_full <= 1'b0;
            tsr <= 10'h3FF; tbusy <= 1'b0; tbit <= 4'd0; tcnt <= 16'd0;
        end else begin
            // software write into the holding register (ignored when full)
            if (wr && is_txdata && !thr_full) begin
                thr      <= pwdata[7:0];
                thr_full <= 1'b1;
            end
            // shifter: load a new frame when idle, otherwise send bit by bit
            if (!tbusy) begin
                if (thr_full) begin
                    tsr      <= {1'b1, thr, 1'b0};
                    tbusy    <= 1'b1;
                    tbit     <= 4'd0;
                    tcnt     <= 16'd0;
                    thr_full <= 1'b0;          // a write in this cycle was ignored (thr_full was 1)
                end
            end else if (tcnt == div) begin
                tcnt <= 16'd0;
                if (tbit == 4'd9)
                    tbusy <= 1'b0;             // stop bit done
                else begin
                    tbit <= tbit + 4'd1;
                    tsr  <= {1'b1, tsr[9:1]};
                end
            end else
                tcnt <= tcnt + 16'd1;
        end

    assign uart_tx = tbusy ? tsr[0] : 1'b1;
    wire tx_full = thr_full;
    wire tx_idle = ~thr_full & ~tbusy;

    // ================= Receive =================
    reg rx_meta, rx_sync;    // synchronizer (line idles high)
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin rx_meta <= 1'b1; rx_sync <= 1'b1; end
        else          begin rx_meta <= uart_rx; rx_sync <= rx_meta; end

    localparam R_IDLE = 2'd0, R_START = 2'd1, R_DATA = 2'd2, R_STOP = 2'd3;
    reg [1:0]  rstate;
    reg [15:0] rcnt;
    reg [2:0]  rbit;
    reg [7:0]  rsr, rbr;     // shift register, receive buffer
    reg        rx_valid, rx_overrun, rx_frame;

    wire rd_rxdata = rd & is_rxdata;
    wire rd_status = rd & is_status;
    wire got_byte  = (rstate == R_STOP) && (rcnt == div) &&  rx_sync;
    wire bad_frame = (rstate == R_STOP) && (rcnt == div) && !rx_sync;

    always @(posedge pclk or negedge presetn)
        if (!presetn) begin
            rstate <= R_IDLE; rcnt <= 16'd0; rbit <= 3'd0; rsr <= 8'd0;
        end else case (rstate)
            R_IDLE:  if (!rx_sync) begin rstate <= R_START; rcnt <= 16'd0; end
            R_START: if (rcnt == (div >> 1)) begin                 // middle of the start bit
                         rcnt   <= 16'd0;
                         rbit   <= 3'd0;
                         rstate <= rx_sync ? R_IDLE : R_DATA;      // high again = glitch, not a start bit
                     end else rcnt <= rcnt + 16'd1;
            R_DATA:  if (rcnt == div) begin                        // middle of a data bit
                         rcnt <= 16'd0;
                         rsr  <= {rx_sync, rsr[7:1]};              // LSB first
                         if (rbit == 3'd7) rstate <= R_STOP;
                         else              rbit   <= rbit + 3'd1;
                     end else rcnt <= rcnt + 16'd1;
            R_STOP:  if (rcnt == div) begin                        // middle of the stop bit
                         rcnt   <= 16'd0;
                         rstate <= R_IDLE;
                     end else rcnt <= rcnt + 16'd1;
        endcase

    // receive buffer and flags (a new event wins over a clear by a read in the same cycle)
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin
            rbr <= 8'd0; rx_valid <= 1'b0; rx_overrun <= 1'b0; rx_frame <= 1'b0;
        end else begin
            if (got_byte) begin
                rbr      <= rsr;
                rx_valid <= 1'b1;
                if (rx_valid && !rd_rxdata) rx_overrun <= 1'b1;    // previous byte was never read
                else if (rd_status)         rx_overrun <= 1'b0;
            end else begin
                if (rd_rxdata) rx_valid   <= 1'b0;
                if (rd_status) rx_overrun <= 1'b0;
            end
            if (bad_frame)      rx_frame <= 1'b1;
            else if (rd_status) rx_frame <= 1'b0;
        end

    // -- Read data --
    always @(*) begin
        prdata = 32'd0;
        if (is_rxdata)  prdata = {24'd0, rbr};
        if (is_status)  prdata = {27'd0, rx_frame, tx_idle, rx_overrun, rx_valid, tx_full};
        if (is_bauddiv) prdata = {16'd0, div};
        if (pwrite || !good) prdata = 32'd0;
    end
endmodule
