`timescale 1ns/1ps
// SIMCTL - simulation-only APB3 slave in slot 15 (0x4000_F000) (03_chapters/ch14a_mcu/design.md sec. 5.4)
//  0x00 FINISH  W  end of test: 1 = PASS, (n << 1) | 1 = test n failed (riscv-tests tohost rule) -> done = 1
//  0x04 PUTC    W  print the low 8 bits as a character on the simulator console
//  - Optional wait states: +SIMWAIT=<percent> makes PREADY random (exercises the core stall)
//  - PSLVERR for other offsets and for reads; PRDATA = 0
module apb_simctl (
    input             pclk,
    input             presetn,
    input             psel,
    input             penable,
    input             pwrite,
    input      [11:0] paddr,
    input      [31:0] pwdata,
    output     [31:0] prdata,
    output reg        pready,
    output            pslverr,
    output reg        done,
    output reg [31:0] result
);
    integer waitpct, seed, r;
    initial begin
        if (!$value$plusargs("SIMWAIT=%d", waitpct)) waitpct = 0;
        seed = 5;
        pready = 1'b1; done = 1'b0; result = 32'd0;
    end

    wire good   = pwrite && (paddr == 12'h000 || paddr == 12'h004);
    wire access = psel && penable;

    assign prdata  = 32'd0;
    assign pslverr = access && !good;

    always @(posedge pclk) begin
        r = $random(seed); if (r < 0) r = -r;
        pready <= (waitpct == 0) ? 1'b1 : ((r % 100) >= waitpct);
        if (access && pready && good) begin
            if (paddr == 12'h000) begin done <= 1'b1; result <= pwdata; end
            else                  $write("%c", pwdata[7:0]);
        end
    end
endmodule
