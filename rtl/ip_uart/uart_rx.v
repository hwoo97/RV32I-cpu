`timescale 1ns/1ps

// UART receiver - UART IP (design.md sec. 5)
//  - rxd is asynchronous: 2-flop synchronizer (reset to 1 = idle line).
//  - Idle: the first tick that sees 0 is sample 0 of the start bit. Each bit has 16 samples (ticks);
//    the bit value is the majority of samples 7, 8, 9 (middle of the bit).
//  - Start bit majority 1 -> noise, back to idle (start_ok is not raised).
//  - Parity checked when enabled (perr), the first stop bit must be 1 (ferr). A second stop bit is
//    not checked, so a sender with longer stop bits is still received.
//  - At the middle of the stop bit the byte is pushed ({ferr, perr, data}) and the receiver goes
//    back to idle, so the next start bit can be seen even if the sender is a little faster.
//  - The frame format is captured at the start bit. en = 0: no new frame starts.
module uart_rx (
    input            clk,
    input            rst_n,
    input            tick,
    input            en,
    input            rxd,               // asynchronous serial input
    input      [1:0] dbits,             // 0 = 5 bits ... 3 = 8 bits
    input            pen,
    input            peven,
    output reg       push,              // 1-clock pulse: pdata is a received byte
    output reg [9:0] pdata,             // {ferr, perr, data[7:0]}, unused high data bits are 0
    output reg       start_ok,          // 1-clock pulse: a start bit was confirmed (RX activity)
    output           busy
);
    localparam S_IDLE = 3'd0, S_START = 3'd1, S_DATA = 3'd2, S_PAR = 3'd3, S_STOP = 3'd4;

    // -- synchronizer --
    reg rx_m, rx_s;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            rx_m <= 1'b1;
            rx_s <= 1'b1;
        end else begin
            rx_m <= rxd;
            rx_s <= rx_m;
        end

    reg [2:0] state;
    reg [3:0] tcnt;
    reg [2:0] bitn;
    reg [7:0] shift;                    // bits enter at the top (LSB first on the line)
    reg       par;                      // XOR of the received data bits
    reg       perr;
    reg       s7, s8;                   // samples 7 and 8 of the current bit
    reg [1:0] f_dbits;
    reg       f_pen, f_peven;

    assign busy = (state != S_IDLE);

    wire maj     = (s7 & s8) | (s7 & rx_s) | (s8 & rx_s);  // at sample 9
    wire sample9 = tick & (tcnt == 4'd9);
    wire bit_end = tick & (tcnt == 4'd15);

    // data aligned to bit 0 after the last data bit was shifted in (5..8 bits)
    reg [7:0] data_al;
    always @(*) begin
        case (f_dbits)
            2'd0:    data_al = {3'b000, shift[7:3]};
            2'd1:    data_al = {2'b00,  shift[7:2]};
            2'd2:    data_al = {1'b0,   shift[7:1]};
            default: data_al = shift;
        endcase
    end

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            state    <= S_IDLE;
            tcnt     <= 4'd0;
            bitn     <= 3'd0;
            shift    <= 8'd0;
            par      <= 1'b0;
            perr     <= 1'b0;
            s7       <= 1'b1;
            s8       <= 1'b1;
            f_dbits  <= 2'd3;
            f_pen    <= 1'b0;
            f_peven  <= 1'b0;
            push     <= 1'b0;
            pdata    <= 10'd0;
            start_ok <= 1'b0;
        end else begin
            push     <= 1'b0;
            start_ok <= 1'b0;
            if (tick) begin
                tcnt <= tcnt + 4'd1;                    // wraps 15 -> 0 at every bit end
                if (tcnt == 4'd7) s7 <= rx_s;
                if (tcnt == 4'd8) s8 <= rx_s;
            end
            case (state)
                S_IDLE:
                    if (tick && en && !rx_s) begin
                        // this tick is sample 0 of the start bit
                        f_dbits <= dbits;
                        f_pen   <= pen;
                        f_peven <= peven;
                        par     <= 1'b0;
                        perr    <= 1'b0;
                        bitn    <= 3'd0;
                        tcnt    <= 4'd1;
                        state   <= S_START;
                    end else if (tick) begin
                        tcnt    <= 4'd0;
                    end
                S_START:
                    if (sample9) begin
                        if (maj) state <= S_IDLE;           // glitch, not a start bit
                        else     start_ok <= 1'b1;
                    end else if (bit_end) begin
                        state <= S_DATA;
                    end
                S_DATA:
                    if (sample9) begin
                        shift <= {maj, shift[7:1]};
                        par   <= par ^ maj;
                    end else if (bit_end) begin
                        if (bitn == {1'b1, f_dbits}) begin  // last data bit: index 4 + dbits
                            bitn  <= 3'd0;
                            state <= f_pen ? S_PAR : S_STOP;
                        end else begin
                            bitn  <= bitn + 3'd1;
                        end
                    end
                S_PAR:
                    if (sample9) begin
                        // even parity: parity bit = XOR of data; odd: its inverse
                        perr <= (maj != (f_peven ? par : ~par));
                    end else if (bit_end) begin
                        state <= S_STOP;
                    end
                S_STOP:
                    if (sample9) begin
                        push  <= 1'b1;
                        pdata <= {~maj, perr, data_al};
                        state <= S_IDLE;
                    end
                default: state <= S_IDLE;
            endcase
        end
endmodule
