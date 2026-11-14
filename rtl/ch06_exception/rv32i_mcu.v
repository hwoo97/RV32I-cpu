`timescale 1ns/1ps
`include "mcu_memmap.vh"

// RV32I MCU without memories, with traps and interrupts - ASIC synthesis target
// (03_chapters/ch14a_mcu/design.md sec. 1, 03_chapters/ch06_exception/design.md sec. 5)
//  rv32i_core (Zicsr, M-mode traps, stall) + bus_mux (address decoder) + apb_bridge + GPIO / TIMER / UART on APB3
//  - Reset: asserted asynchronously, released synchronously (2-flop reset synchronizer); everything
//    inside uses the synchronized reset, so the reset is released 2 clocks after rst_n goes high
//  - Interrupts: TIMER irq -> mip.MTIP, ext_irq pin (2-flop synchronizer) -> mip.MEIP
//  - Memory ports go out of this module; mcu_top (simulation / FPGA) attaches the memories:
//      imem_*  instruction fetch            -> IMEM read port A
//      irom_*  data-side IMEM read (r/o)    -> IMEM read port B
//      ram_*   data memory read / write     -> DMEM
//  - APB slots (addr[15:12]): 0 GPIO, 1 TIMER, 2 UART; every other slot has no slave:
//    PREADY = 1, PSLVERR = 1, PRDATA = 0 (so an access ends with bus_err instead of waiting forever)
//  - Nothing here is for simulation only: tests report their result by normal stores to the TOHOST
//    words at the end of DMEM, which the testbench watches on the ram_* port (design.md sec. 5.4)
//  - Decoder errors become exceptions: fetch_err -> instruction access fault, data_err -> load/store
//    access fault (unmapped data address, write to IMEM, sb/sh to a peripheral, PSLVERR)
//  - Observation outputs: trap (an exception is taken), irq_taken (an interrupt is taken),
//    bus_err (decoder error this cycle) - 1-cycle pulses for waveforms / LEDs, not needed by software
module rv32i_mcu #(
    parameter RESET_PC = `MM_IMEM_BASE,
    parameter GPIO_W   = 16,
    parameter [15:0] UART_DIV_RESET = 16'd433
) (
    input               clk,
    input               rst_n,                  // reset when 0 (asynchronous)
    // instruction fetch -> IMEM port A
    output [31:0]       imem_addr,
    input  [31:0]       imem_rdata,
    // data-side IMEM read -> IMEM port B
    output [31:0]       irom_addr,
    input  [31:0]       irom_rdata,
    // DMEM
    output [31:0]       ram_addr,
    output [3:0]        ram_wstrb,
    output [31:0]       ram_wdata,
    input  [31:0]       ram_rdata,
    // GPIO pins
    input  [GPIO_W-1:0] gpio_in,
    output [GPIO_W-1:0] gpio_out,
    output [GPIO_W-1:0] gpio_oe,
    // UART
    input               uart_rx,
    output              uart_tx,
    // interrupts
    input               ext_irq,                // external interrupt request (level, asynchronous)
    output              timer_irq,              // TIMER interrupt request (observation)
    // observation
    output [31:0]       dbg_pc,
    output              trap,                   // an exception is taken this cycle
    output              irq_taken,              // an interrupt is taken this cycle
    output              bus_err                 // fetch_err | data_err (from the decoder)
);
    localparam NSLOT = 16;

    // -- Reset synchronizer: async assert, sync release --
    reg [1:0] rst_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) rst_sync <= 2'b00;
        else        rst_sync <= {rst_sync[0], 1'b1};
    wire rst_n_s = rst_sync[1];

    // -- External interrupt synchronizer --
    reg [1:0] ext_sync;
    always @(posedge clk or negedge rst_n_s)
        if (!rst_n_s) ext_sync <= 2'b00;
        else          ext_sync <= {ext_sync[0], ext_irq};

    // -- core <-> decoder --
    wire        dmem_re, dmem_ready;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;

    // -- decoder <-> bridge --
    wire        apb_req, apb_write, apb_ready, apb_err;
    wire [31:0] apb_rdata;
    wire        data_err, fetch_err;

    // -- APB bus --
    wire [31:0]         paddr, pwdata;
    wire                pwrite, penable;
    wire [NSLOT-1:0]    psel;
    wire [NSLOT*32-1:0] prdata;
    wire [NSLOT-1:0]    pready, pslverr;

    rv32i_core #(.RESET_PC(RESET_PC)) u_core (
        .clk        (clk),
        .rst_n       (rst_n_s),
        .imem_addr   (imem_addr),
        .imem_rdata  (imem_rdata),
        .fetch_fault (fetch_err),
        .dmem_re     (dmem_re),
        .dmem_addr   (dmem_addr),
        .dmem_wstrb  (dmem_wstrb),
        .dmem_wdata  (dmem_wdata),
        .dmem_rdata  (dmem_rdata),
        .dmem_ready  (dmem_ready),
        .data_fault  (data_err),
        .irq_timer   (timer_irq),
        .irq_ext     (ext_sync[1]),
        .dbg_pc      (dbg_pc),
        .trap        (trap),
        .irq_taken   (irq_taken)
    );

    bus_mux u_bus_mux (
        .dmem_re    (dmem_re),
        .dmem_addr  (dmem_addr),
        .dmem_wstrb (dmem_wstrb),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_ready (dmem_ready),
        .imem_addr  (imem_addr),
        .data_err   (data_err),
        .fetch_err  (fetch_err),
        .irom_addr  (irom_addr),
        .irom_rdata (irom_rdata),
        .ram_addr   (ram_addr),
        .ram_wstrb  (ram_wstrb),
        .ram_wdata  (ram_wdata),
        .ram_rdata  (ram_rdata),
        .apb_req    (apb_req),
        .apb_write  (apb_write),
        .apb_rdata  (apb_rdata),
        .apb_ready  (apb_ready),
        .apb_err    (apb_err)
    );

    apb_bridge u_apb_bridge (
        .clk     (clk),
        .rst_n   (rst_n_s),
        .req     (apb_req),
        .write   (apb_write),
        .addr    (dmem_addr),
        .wdata   (dmem_wdata),
        .rdata   (apb_rdata),
        .ready   (apb_ready),
        .err     (apb_err),
        .paddr   (paddr),
        .pwrite  (pwrite),
        .pwdata  (pwdata),
        .penable (penable),
        .psel    (psel),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );

    // -- slot 0: GPIO --
    apb_gpio #(.GPIO_W(GPIO_W)) u_gpio (
        .pclk     (clk),
        .presetn  (rst_n_s),
        .psel     (psel[`MM_GPIO_SLOT]),
        .penable  (penable),
        .pwrite   (pwrite),
        .paddr    (paddr[11:0]),
        .pwdata   (pwdata),
        .prdata   (prdata[32*`MM_GPIO_SLOT +: 32]),
        .pready   (pready[`MM_GPIO_SLOT]),
        .pslverr  (pslverr[`MM_GPIO_SLOT]),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_oe  (gpio_oe)
    );

    // -- slot 1: TIMER --
    apb_timer u_timer (
        .pclk    (clk),
        .presetn (rst_n_s),
        .psel    (psel[`MM_TIMER_SLOT]),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr[11:0]),
        .pwdata  (pwdata),
        .prdata  (prdata[32*`MM_TIMER_SLOT +: 32]),
        .pready  (pready[`MM_TIMER_SLOT]),
        .pslverr (pslverr[`MM_TIMER_SLOT]),
        .irq     (timer_irq)
    );

    // -- slot 2: UART --
    apb_uart #(.DIV_RESET(UART_DIV_RESET)) u_uart (
        .pclk    (clk),
        .presetn (rst_n_s),
        .psel    (psel[`MM_UART_SLOT]),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr[11:0]),
        .pwdata  (pwdata),
        .prdata  (prdata[32*`MM_UART_SLOT +: 32]),
        .pready  (pready[`MM_UART_SLOT]),
        .pslverr (pslverr[`MM_UART_SLOT]),
        .uart_rx (uart_rx),
        .uart_tx (uart_tx)
    );

    // -- empty slots: answer at once with an error --
    genvar s;
    generate
        for (s = 0; s < NSLOT; s = s + 1) begin : g_empty
            if (s != `MM_GPIO_SLOT && s != `MM_TIMER_SLOT && s != `MM_UART_SLOT) begin : g_tie
                assign prdata[32*s +: 32] = 32'd0;
                assign pready[s]          = 1'b1;
                assign pslverr[s]         = 1'b1;
            end
        end
    endgenerate

    assign bus_err = fetch_err | data_err;
endmodule
