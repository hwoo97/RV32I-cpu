// APB3 master tasks for peripheral testbenches (include inside a testbench module)
// The including module must declare:
//   reg         clk, psel, penable, pwrite;
//   reg  [31:0] paddr, pwdata;
//   wire [31:0] prdata;
//   wire        pready, pslverr;
// Timing (same as apb_bridge): inputs change at the falling edge,
//   cycle 1 = SETUP (psel=1, penable=0), cycle 2.. = ACCESS (penable=1) until pready = 1,
//   the transfer completes at the rising edge of the cycle where pready = 1.
// apb_cycles holds the number of cycles of the last transfer (2 = no wait state).
integer apb_cycles;

task apb_xfer(input wr, input [31:0] a, input [31:0] d, output [31:0] rd, output err);
    begin
        @(negedge clk);
        psel = 1'b1; penable = 1'b0; pwrite = wr; paddr = a; pwdata = d;     // SETUP
        @(negedge clk);
        penable = 1'b1;                                                     // ACCESS
        apb_cycles = 2;
        #1;
        while (!pready) begin
            @(negedge clk); #1;
            apb_cycles = apb_cycles + 1;
            if (apb_cycles > 100) begin
                $display("FAIL: apb_xfer: no PREADY at addr %h", a);
                $finish;
            end
        end
        rd = prdata; err = pslverr;                                         // sampled in the last ACCESS cycle
        @(posedge clk); #1;
        psel = 1'b0; penable = 1'b0;                                        // back to IDLE
    end
endtask

task apb_write(input [31:0] a, input [31:0] d, output err);
    reg [31:0] dummy;
    begin
        apb_xfer(1'b1, a, d, dummy, err);
    end
endtask

task apb_read(input [31:0] a, output [31:0] d, output err);
    begin
        apb_xfer(1'b0, a, 32'd0, d, err);
    end
endtask
