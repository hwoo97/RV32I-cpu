`timescale 1ns/1ps
`include "mcu_memmap.vh"

// MCU + memories - top level for simulation and FPGA (03_chapters/ch14a_mcu/design.md sec. 1)
//  - rv32i_mcu (no memories) + mcu_imem (16 KB, 2 read ports) + mcu_dmem (16 KB)
//  - The program image (IMEM_INIT, or loaded by the testbench into u_imem.mem) holds code, constants
//    and the initial values of .data; the startup code copies .data into DMEM
//  - GPIO pins stay split into in / out / oe here; the board top adds the tri-state buffers
//  - The external APB slot (apbx_*) is passed through for the simulation-only SIMCTL slave;
//    on the board tie apbx_pready = 1, apbx_pslverr = 1, apbx_prdata = 0
module mcu_top #(
    parameter IMEM_INIT = "",
    parameter DMEM_INIT = "",
    parameter GPIO_W    = 16,
    parameter [15:0] UART_DIV_RESET = 16'd433
) (
    input               clk,
    input               rst_n,
    input  [GPIO_W-1:0] gpio_in,
    output [GPIO_W-1:0] gpio_out,
    output [GPIO_W-1:0] gpio_oe,
    input               uart_rx,
    output              uart_tx,
    output              timer_irq,
    output              apbx_psel,
    output              apbx_penable,
    output              apbx_pwrite,
    output [11:0]       apbx_paddr,
    output [31:0]       apbx_pwdata,
    input  [31:0]       apbx_prdata,
    input               apbx_pready,
    input               apbx_pslverr,
    output [31:0]       dbg_pc,
    output              trap,
    output              bus_err
);
    wire [31:0] imem_addr, imem_rdata, irom_addr, irom_rdata;
    wire [31:0] ram_addr, ram_wdata, ram_rdata;
    wire [3:0]  ram_wstrb;

    rv32i_mcu #(.GPIO_W(GPIO_W), .UART_DIV_RESET(UART_DIV_RESET)) u_mcu (
        .clk          (clk),
        .rst_n        (rst_n),
        .imem_addr    (imem_addr),
        .imem_rdata   (imem_rdata),
        .irom_addr    (irom_addr),
        .irom_rdata   (irom_rdata),
        .ram_addr     (ram_addr),
        .ram_wstrb    (ram_wstrb),
        .ram_wdata    (ram_wdata),
        .ram_rdata    (ram_rdata),
        .gpio_in      (gpio_in),
        .gpio_out     (gpio_out),
        .gpio_oe      (gpio_oe),
        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx),
        .timer_irq    (timer_irq),
        .apbx_psel    (apbx_psel),
        .apbx_penable (apbx_penable),
        .apbx_pwrite  (apbx_pwrite),
        .apbx_paddr   (apbx_paddr),
        .apbx_pwdata  (apbx_pwdata),
        .apbx_prdata  (apbx_prdata),
        .apbx_pready  (apbx_pready),
        .apbx_pslverr (apbx_pslverr),
        .dbg_pc       (dbg_pc),
        .trap         (trap),
        .bus_err      (bus_err)
    );

    mcu_imem #(.AW(`MM_IMEM_AW), .INIT_FILE(IMEM_INIT)) u_imem (
        .addr_a  (imem_addr),
        .rdata_a (imem_rdata),
        .addr_b  (irom_addr),
        .rdata_b (irom_rdata)
    );

    mcu_dmem #(.AW(`MM_DMEM_AW), .INIT_FILE(DMEM_INIT)) u_dmem (
        .clk   (clk),
        .addr  (ram_addr),
        .wstrb (ram_wstrb),
        .wdata (ram_wdata),
        .rdata (ram_rdata)
    );
endmodule
