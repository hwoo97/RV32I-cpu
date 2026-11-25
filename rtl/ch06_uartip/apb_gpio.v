`timescale 1ns/1ps

// GPIO - APB3 slave (03_chapters/ch14a_mcu/design.md sec. 5.1)
//  Registers (32-bit, word access only; offsets from the GPIO base 0x4000_0000)
//    0x00 DATA_OUT  R/W  output value, one bit per pin
//    0x04 DATA_IN   R    input pin value after a 2-flop synchronizer (2 clock delay)
//    0x08 DIR       R/W  1 = output, 0 = input (reset 0 = all inputs)
//  - Only the low GPIO_W bits exist; upper bits read 0 and ignore writes
//  - No wait states: PREADY = 1 always
//  - PSLVERR = 1 for an unknown offset or a write to the read-only DATA_IN (the register is not changed)
//  - Pin side: gpio_out / gpio_oe go to a tri-state buffer at the chip or FPGA top
//    (pin = gpio_oe ? gpio_out : 'z), and the pin value comes back on gpio_in
module apb_gpio #(
    parameter GPIO_W = 16                 // number of pins (1..32)
) (
    input                   pclk,
    input                   presetn,       // reset when 0 (asynchronous)
    // APB3 slave
    input                   psel,
    input                   penable,
    input                   pwrite,
    input      [11:0]       paddr,         // offset inside the 4 KB slot
    input      [31:0]       pwdata,
    output reg [31:0]       prdata,
    output                  pready,
    output                  pslverr,
    // pins
    input      [GPIO_W-1:0] gpio_in,
    output     [GPIO_W-1:0] gpio_out,
    output     [GPIO_W-1:0] gpio_oe
);
    localparam OFS_DATA_OUT = 12'h000,
               OFS_DATA_IN  = 12'h004,
               OFS_DIR      = 12'h008;

    reg [GPIO_W-1:0] data_out, dir;
    reg [GPIO_W-1:0] in_meta, in_sync;   // 2-flop synchronizer for asynchronous pin inputs

    // -- Address decode of this access --
    wire access   = psel & penable;                    // ACCESS phase (transfer completes: PREADY = 1)
    wire is_out   = (paddr == OFS_DATA_OUT);
    wire is_in    = (paddr == OFS_DATA_IN);
    wire is_dir   = (paddr == OFS_DIR);
    wire known    = is_out | is_in | is_dir;
    wire bad      = ~known | (pwrite & is_in);         // unknown offset or write to read-only

    assign pready  = 1'b1;
    assign pslverr = access & bad;

    // -- Register writes (at the end of the ACCESS cycle) --
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin
            data_out <= {GPIO_W{1'b0}};
            dir      <= {GPIO_W{1'b0}};
        end else if (access && pwrite) begin
            if (is_out) data_out <= pwdata[GPIO_W-1:0];
            if (is_dir) dir      <= pwdata[GPIO_W-1:0];
        end

    // -- Input synchronizer (pins may change at any time) --
    always @(posedge pclk or negedge presetn)
        if (!presetn) begin
            in_meta <= {GPIO_W{1'b0}};
            in_sync <= {GPIO_W{1'b0}};
        end else begin
            in_meta <= gpio_in;
            in_sync <= in_meta;
        end

    // -- Read data (combinational, valid in the ACCESS cycle) --
    always @(*) begin
        prdata = 32'd0;
        if (is_out) prdata[GPIO_W-1:0] = data_out;
        if (is_in)  prdata[GPIO_W-1:0] = in_sync;
        if (is_dir) prdata[GPIO_W-1:0] = dir;
    end

    assign gpio_out = data_out;
    assign gpio_oe  = dir;
endmodule
