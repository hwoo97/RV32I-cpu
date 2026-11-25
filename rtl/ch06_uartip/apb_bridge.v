`timescale 1ns/1ps
`include "mcu_memmap.vh"

// APB3 bridge: core data request -> APB3 master (03_chapters/ch14a_mcu/design.md sec. 4)
//  - Phases: IDLE --(req)--> SETUP (PSEL=1, PENABLE=0) --> ACCESS (PSEL=1, PENABLE=1) --(PREADY)--> done
//    SETUP is the first cycle of a request seen in IDLE, so the FSM only needs IDLE and ACCESS states.
//  - The single-cycle core holds the whole request (address, write, data) until ready, so PADDR, PWRITE
//    and PWDATA are driven straight from the request without registers (a pipelined core needs latches).
//  - One APB transfer takes at least 2 cycles; a slave adds wait cycles with PREADY = 0 in ACCESS.
//  - Slots: PSEL[n] for slave n, n = address[MM_APB_SLOT_MSB:MM_APB_SLOT_LSB] (16 slots of 4 KB).
//    Slave responses come in as flat vectors; slot n uses PRDATA[32n+31:32n], PREADY[n], PSLVERR[n].
//    Slots without a slave must be tied to PREADY = 1, PSLVERR = 1, PRDATA = 0 by the MCU top.
module apb_bridge #(
    parameter SW    = `MM_APB_SLOT_MSB - `MM_APB_SLOT_LSB + 1,   // slot field width (4)
    parameter NSLOT = 1 << SW                                   // number of slots (16)
) (
    input         clk,
    input         rst_n,
    // request from bus_mux (held stable by the core until ready)
    input         req,
    input         write,
    input  [31:0] addr,
    input  [31:0] wdata,
    output [31:0] rdata,
    output        ready,             // transfer completes this cycle (ACCESS and PREADY)
    output        err,               // PSLVERR of the completing transfer
    // APB3 master
    output [31:0] paddr,
    output        pwrite,
    output [31:0] pwdata,
    output        penable,
    output [NSLOT-1:0]    psel,
    input  [NSLOT*32-1:0] prdata,
    input  [NSLOT-1:0]    pready,
    input  [NSLOT-1:0]    pslverr
);
    localparam IDLE   = 1'b0,
               ACCESS = 1'b1;
    reg state;

    wire [SW-1:0] slot = addr[`MM_APB_SLOT_MSB:`MM_APB_SLOT_LSB];
    wire          slv_ready = pready[slot];

    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            state <= IDLE;
        else case (state)
            IDLE:    if (req)       state <= ACCESS;     // this cycle was SETUP
            ACCESS:  if (slv_ready) state <= IDLE;       // transfer done
            default:                state <= IDLE;
        endcase

    wire active = (state == ACCESS) | req;              // SETUP or ACCESS

    assign penable = (state == ACCESS);
    assign psel    = active ? ({{(NSLOT-1){1'b0}}, 1'b1} << slot) : {NSLOT{1'b0}};
    assign paddr   = addr;
    assign pwrite  = write;
    assign pwdata  = wdata;

    assign ready = (state == ACCESS) & slv_ready;
    assign err   = (state == ACCESS) & pslverr[slot];
    assign rdata = prdata[slot*32 +: 32];
endmodule
