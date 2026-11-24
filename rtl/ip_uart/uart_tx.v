`timescale 1ns/1ps

// UART transmitter - UART IP (design.md sec. 4)
//  Frame: start (0), data 5..8 bits LSB first, optional parity, stop 1 or 2 bits (1).
//  One bit = 16 ticks. A frame starts on a tick, so every bit is exactly 16 ticks long.
//  The frame format (dbits, pen, peven, stop2) is captured when the frame starts.
//  Back to back: at the end of the stop bit the next byte starts at once if the FIFO has one.
//  en = 0 lets the current frame finish, then no new frame starts.
//  txd is registered (one clock after the state) so the output pin has no glitches.
module uart_tx (
    input            clk,
    input            rst_n,
    input            tick,
    input            en,
    input            fifo_empty,
    input      [7:0] fifo_data,
    output reg       fifo_rd,           // 1-clock pulse: take fifo_data
    input      [1:0] dbits,             // 0 = 5 bits ... 3 = 8 bits
    input            pen,               // parity enable
    input            peven,             // 1 = even parity, 0 = odd
    input            stop2,             // 1 = two stop bits
    output reg       txd,
    output           busy
);
    localparam S_IDLE = 3'd0, S_START = 3'd1, S_DATA = 3'd2, S_PAR = 3'd3, S_STOP = 3'd4;

    reg [2:0] state;
    reg [3:0] tcnt;                     // tick count inside the bit
    reg [2:0] bitn;                     // data bit index / stop bit index
    reg [7:0] shift;
    reg       par;                      // XOR of the data bits sent so far
    reg [1:0] f_dbits;                  // frame format captured at the start
    reg       f_pen, f_peven, f_stop2;

    wire bit_end = tick & (tcnt == 4'd15);
    wire start_ok = en & ~fifo_empty;

    assign busy = (state != S_IDLE);

    // value of the line for the current state
    reg txd_c;
    always @(*) begin
        case (state)
            S_START: txd_c = 1'b0;
            S_DATA:  txd_c = shift[0];
            S_PAR:   txd_c = f_peven ? par : ~par;
            default: txd_c = 1'b1;      // idle and stop
        endcase
    end

    always @(posedge clk or negedge rst_n)
        if (!rst_n) txd <= 1'b1;
        else        txd <= txd_c;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state   <= S_IDLE;
            tcnt    <= 4'd0;
            bitn    <= 3'd0;
            shift   <= 8'd0;
            par     <= 1'b0;
            f_dbits <= 2'd3;
            f_pen   <= 1'b0;
            f_peven <= 1'b0;
            f_stop2 <= 1'b0;
            fifo_rd <= 1'b0;
        end else begin
            fifo_rd <= 1'b0;
            if (tick) tcnt <= tcnt + 4'd1;          // wraps 15 -> 0 at every bit end
            case (state)
                S_IDLE:
                    if (tick && start_ok) begin
                        // load the next byte; the start bit begins at this tick and lasts
                        // until the 16th tick after it (bit_end at tcnt = 15)
                        shift   <= fifo_data;
                        fifo_rd <= 1'b1;
                        f_dbits <= dbits;
                        f_pen   <= pen;
                        f_peven <= peven;
                        f_stop2 <= stop2;
                        par     <= 1'b0;
                        bitn    <= 3'd0;
                        tcnt    <= 4'd0;
                        state   <= S_START;
                    end else if (tick) begin
                        tcnt    <= 4'd0;
                    end
                S_START:
                    if (bit_end) state <= S_DATA;
                S_DATA:
                    if (bit_end) begin
                        par   <= par ^ shift[0];
                        shift <= {1'b0, shift[7:1]};
                        if (bitn == {1'b1, f_dbits}) begin          // last data bit: index 4 + dbits
                            bitn  <= 3'd0;
                            state <= f_pen ? S_PAR : S_STOP;
                        end else begin
                            bitn  <= bitn + 3'd1;
                        end
                    end
                S_PAR:
                    if (bit_end) state <= S_STOP;
                S_STOP:
                    if (bit_end) begin
                        if (f_stop2 && bitn == 3'd0) begin
                            bitn <= 3'd1;                           // second stop bit
                        end else if (start_ok) begin
                            // next byte right away (the next tick is tick 0 of its start bit)
                            shift   <= fifo_data;
                            fifo_rd <= 1'b1;
                            f_dbits <= dbits;
                            f_pen   <= pen;
                            f_peven <= peven;
                            f_stop2 <= stop2;
                            par     <= 1'b0;
                            bitn    <= 3'd0;
                            state   <= S_START;
                        end else begin
                            bitn  <= 3'd0;
                            state <= S_IDLE;
                        end
                    end
                default: state <= S_IDLE;
            endcase
        end
endmodule
