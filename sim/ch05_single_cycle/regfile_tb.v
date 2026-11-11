`timescale 1ns/1ps
// Self-checking testbench for regfile
// Checks
//  1) write distinct values to all 31 registers and read them on both read ports
//  2) writing x0 still reads 0
//  3) no write when reg_we = 0
//  4) old value during the write cycle, new value after the clock edge (single-cycle CPU behavior)
//  5) 2000 random writes/reads compared with a shadow table in the testbench
module regfile_tb;
    reg         clk = 0;
    reg         reg_we = 0;
    reg  [4:0]  rs1_addr = 0, rs2_addr = 0, rd_addr = 0;
    reg  [31:0] rd_data = 0;
    wire [31:0] rs1_data, rs2_data;

    reg  [31:0] shadow [0:31];   // record of values written so far (x0 always 0)
    integer     i, errors = 0;

    regfile dut (
        .clk      (clk),
        .reg_we   (reg_we),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (rd_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    always #5 clk = ~clk;

    task check(input [31:0] actual, input [31:0] expected, input [8*24:1] what);
        if (actual !== expected) begin
            if (errors < 10)
                $display("FAIL: %0s = %h (expected %h) at %0t", what, actual, expected, $time);
            errors = errors + 1;
        end
    endtask

    // change inputs on the falling clock edge; the write happens on the next rising edge
    task write_reg(input [4:0] addr, input [31:0] data, input we);
        begin
            @(negedge clk);
            rd_addr = addr; rd_data = data; reg_we = we;
            @(posedge clk); #1;
            reg_we = 0;
            if (we && addr != 0) shadow[addr] = data;
        end
    endtask

    task read_check(input [4:0] a1, input [4:0] a2);
        begin
            rs1_addr = a1; rs2_addr = a2; #1;
            check(rs1_data, shadow[a1], "rs1_data");
            check(rs2_data, shadow[a2], "rs2_data");
        end
    endtask

    initial begin
        for (i = 0; i < 32; i = i + 1) shadow[i] = 32'd0;

        // 1) write distinct values to all registers -> read on both ports
        for (i = 1; i < 32; i = i + 1) write_reg(i, 32'h1000_0000 * (i % 16) + i * 32'h0101_0101, 1);
        for (i = 0; i < 32; i = i + 1) read_check(i, 31 - i);

        // 2) write x0 -> must read 0
        write_reg(0, 32'hdead_beef, 1);
        read_check(0, 0);

        // 3) no write when reg_we = 0
        write_reg(5, 32'hffff_ffff, 0);
        read_check(5, 5);

        // 4) old value during the write cycle, new value after the edge
        @(negedge clk);
        rd_addr = 7; rd_data = 32'h1234_5678; reg_we = 1;
        rs1_addr = 7; rs2_addr = 7; #1;
        check(rs1_data, shadow[7], "rs1_data before edge");
        @(posedge clk); #1;
        reg_we = 0; shadow[7] = 32'h1234_5678;
        check(rs1_data, 32'h1234_5678, "rs1_data after edge");

        // 5) random writes/reads
        for (i = 0; i < 2000; i = i + 1) begin
            write_reg($random, $random, $random);
            read_check($random, $random);
        end

        if (errors == 0) $display("PASS: regfile");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #200000 $display("FAIL: timeout");
        $finish;
    end
endmodule
