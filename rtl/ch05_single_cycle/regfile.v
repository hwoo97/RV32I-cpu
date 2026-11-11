`timescale 1ns/1ps

// Register file - 32 x 32-bit registers (x0 .. x31)
//  - 2 read ports: asynchronous (value appears as soon as the address changes, combinational)
//  - 1 write port: synchronous (writes rd_data to rd_addr on clk rising edge when reg_we = 1)
//  - x0 is always 0: reads return 0, writes are ignored -> only x1..x31 (31 entries) are stored
//  - No reset: RISC-V does not define initial register values (startup code clears them)
module regfile (
    input         clk,
    input         reg_we,     // from control unit
    input  [4:0]  rs1_addr,   // inst[19:15]
    input  [4:0]  rs2_addr,   // inst[24:20]
    input  [4:0]  rd_addr,    // inst[11:7]
    input  [31:0] rd_data,    // top-level wb_data
    output [31:0] rs1_data,
    output [31:0] rs2_data
);
    reg [31:0] regs [1:31];

    // Write: once per cycle, on the rising clock edge
    always @(posedge clk)
        if (reg_we && rd_addr != 5'd0)
            regs[rd_addr] <= rd_data;

    // Read: 0 for x0, otherwise the stored value (a value written this cycle is visible from the next cycle)
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];
endmodule
