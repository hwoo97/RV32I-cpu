`timescale 1ns/1ps
`include "mcu_memmap.vh"

// Address decoder of the core data port (03_chapters/ch14a_mcu/design.md sec. 1, 2, 2.2)
//  - Routes one load/store of rv32i_core to IMEM (read only), DMEM or the APB bridge
//  - IMEM and DMEM answer in the same cycle (dmem_ready = 1); APB answers when the bridge says ready
//  - Combinational only (no clock)
//  - Errors (bus_err sources, connected to traps in ch6):
//      data_err : unmapped address, write to IMEM, APB write that is not a full word (sb/sh),
//                 or PSLVERR from the APB slave (reported in the completing cycle)
//      fetch_err: instruction fetch address outside IMEM
//  - Addresses come from the generated mcu_memmap.vh (fw/common/memmap.txt)
module bus_mux (
    // core data port
    input             dmem_re,
    input      [31:0] dmem_addr,
    input      [3:0]  dmem_wstrb,
    input      [31:0] dmem_wdata,
    output reg [31:0] dmem_rdata,
    output            dmem_ready,
    // instruction fetch address (only checked here)
    input      [31:0] imem_addr,
    // errors
    output            data_err,
    output            fetch_err,
    // IMEM data-side read port (read only)
    output     [31:0] irom_addr,
    input      [31:0] irom_rdata,
    // DMEM
    output     [31:0] ram_addr,
    output     [3:0]  ram_wstrb,
    output     [31:0] ram_wdata,
    input      [31:0] ram_rdata,
    // APB bridge (request side)
    output            apb_req,          // start / keep an APB transfer
    output            apb_write,
    input      [31:0] apb_rdata,
    input             apb_ready,        // transfer completes this cycle
    input             apb_err           // PSLVERR of the completing transfer
);
    wire write   = |dmem_wstrb;
    wire request = dmem_re | write;

    wire hit_imem = `MM_IMEM_HIT(dmem_addr);
    wire hit_dmem = `MM_DMEM_HIT(dmem_addr);
    wire hit_apb  = `MM_APB_HIT(dmem_addr);

    // APB takes full-word writes only (APB3 has no byte strobes); reads of any size are fine
    // (the core's lsu picks the byte/halfword out of the returned word)
    wire apb_ok  = dmem_re | (dmem_wstrb == 4'b1111);

    // -- Request to each target --
    assign irom_addr = dmem_addr;
    assign ram_addr  = dmem_addr;
    assign ram_wdata = dmem_wdata;
    assign ram_wstrb = hit_dmem ? dmem_wstrb : 4'b0000;

    assign apb_req   = request & hit_apb & apb_ok;
    assign apb_write = write;

    // -- Response --
    always @(*) begin
        if (hit_imem)      dmem_rdata = irom_rdata;
        else if (hit_dmem) dmem_rdata = ram_rdata;
        else if (hit_apb)  dmem_rdata = apb_rdata;
        else               dmem_rdata = 32'd0;      // unmapped: read 0
    end

    // Only a real APB transfer waits; everything else (including errors) completes at once
    assign dmem_ready = apb_req ? apb_ready : 1'b1;

    // -- Errors --
    wire bad_target = request & ~(hit_imem | hit_dmem | hit_apb);   // unmapped
    wire bad_imem   = write & hit_imem;                              // IMEM is read only
    wire bad_apb    = request & hit_apb & ~apb_ok;                   // sb/sh to a peripheral
    assign data_err  = bad_target | bad_imem | bad_apb | (apb_req & apb_ready & apb_err);
    assign fetch_err = ~`MM_IMEM_HIT(imem_addr);
endmodule
