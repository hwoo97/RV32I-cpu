`timescale 1ns/1ps
`include "mcu_memmap.vh"
// TOHOST monitor - testbench only (03_chapters/ch14a_mcu/design.md sec. 5.4)
// Watches the DMEM write port of mcu_top (ram_*). The MCU RTL has nothing for simulation:
// the program writes the TOHOST words at the end of DMEM with normal stores, like any other data.
//  TOHOST + 0x0  FINISH  sw: 1 = PASS, (n << 1) | 1 = test n failed (riscv-tests tohost rule) -> done = 1
//  TOHOST + 0x4  PUTC    sb/sh/sw: print the low byte as a character on the simulator console
//  - FINISH must be a full word store (wstrb = 1111); a partial store there sets bad_store
//  - The write is taken at the same clock edge as the DMEM write itself
module tohost_mon (
    input             clk,
    input             rst_n,
    input      [31:0] addr,
    input      [3:0]  wstrb,
    input      [31:0] wdata,
    output reg        done,
    output reg [31:0] result,
    output reg        bad_store
);
    wire hit    = `MM_TOHOST_HIT(addr) && (wstrb != 4'b0000);
    wire finish = hit && (addr[3:2] == 2'd0);
    wire putc   = hit && (addr[3:2] == 2'd1) && wstrb[0];

    initial begin
        done = 1'b0; result = 32'd0; bad_store = 1'b0;
    end

    always @(posedge clk) begin
        if (rst_n && !done) begin
            if (finish) begin
                if (wstrb == 4'b1111) begin
                    done   <= 1'b1;
                    result <= wdata;
                end else begin
                    bad_store <= 1'b1;
                end
            end
            if (putc) $write("%c", wdata[7:0]);
        end
    end
endmodule
