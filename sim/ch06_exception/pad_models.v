`timescale 1ns/1ps
// Simple functional pad models for simulating rv32i_chip on this PC (xsim) - written for this project
//  - Same ports and logic as the giolib045 pads used by rv32i_chip (no delays):
//      PADDI : PAD -> Y              PADDO : A -> PAD
//      PADDB : PAD = OEN ? Z : A (OEN = 0 drives), Y = PAD
//  - Power pads: pad_power.v
//  - The school server uses the PDK models instead ($GPDK045_DIR/.../giolib045_v3.5/vlog/pads_SS_s1vg.v
//    + pad_power.v, see sim/ch06_exception/run_chip_tests.sh); the PDK files are never copied into the repo
module PADDI (input PAD, output Y);
    assign Y = PAD;
endmodule

module PADDO (input A, output PAD);
    assign PAD = A;
endmodule

module PADDB (input A, input OEN, inout PAD, output Y);
    assign PAD = OEN ? 1'bz : A;
    assign Y   = PAD;
endmodule
