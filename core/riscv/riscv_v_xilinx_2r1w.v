//-----------------------------------------------------------------
//                         RISC-V Core
//                            V1.0.1
//                     Ultra-Embedded.com
//                     Copyright 2014-2019
//
//                   admin@ultra-embedded.com
//
//                       License: BSD
//-----------------------------------------------------------------
//
// Copyright (c) 2014-2019, Ultra-Embedded.com
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//   - Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer
//     in the documentation and/or other materials provided with the
//     distribution.
//   - Neither the name of the author nor the names of its contributors
//     may be used to endorse or promote products derived from this
//     software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//-----------------------------------------------------------------
// Module - Xilinx vector register file (2 async read, 1 write port)
// Uses RAM16X1D LUT-RAMs, same scheme as riscv_xilinx_2r1w but
// parametrised to VLEN bits wide.  Registers are split into two
// banks of 16 (0-15 / 16-31) addressed by rd0_i[3:0]; rd0_i[4]
// selects the bank.  All 32 vector registers (including v0) are
// writable — v0 has no hardwired-zero special case in RVV.
//-----------------------------------------------------------------
module riscv_v_xilinx_2r1w
#(
    parameter VLEN = 128
)
(
    // Inputs
     input              clk_i
    ,input              rst_i
    ,input  [  4:0]     rd0_i
    ,input  [VLEN-1:0]  rd0_value_i
    ,input              rd0_we_i
    ,input  [  4:0]     ra_i
    ,input  [  4:0]     rb_i

    // Outputs
    ,output [VLEN-1:0]  ra_value_o
    ,output [VLEN-1:0]  rb_value_o
);

//-----------------------------------------------------------------
// Registers / Wires
//-----------------------------------------------------------------
wire [VLEN-1:0] rs1_0_15_w;
wire [VLEN-1:0] rs1_16_31_w;
wire [VLEN-1:0] rs2_0_15_w;
wire [VLEN-1:0] rs2_16_31_w;
wire            write_banka_w;
wire            write_bankb_w;

assign write_banka_w = (rd0_we_i & (~rd0_i[4]));
assign write_bankb_w = (rd0_we_i &   rd0_i[4]);

//-----------------------------------------------------------------
// Register File (using RAM16X1D)
//-----------------------------------------------------------------
genvar i;

// Registers 0-15
generate
for (i = 0; i < VLEN; i = i+1)
begin : reg_loop1
    RAM16X1D reg_bit1a(
        .WCLK(clk_i), .WE(write_banka_w),
        .A0(rd0_i[0]), .A1(rd0_i[1]), .A2(rd0_i[2]), .A3(rd0_i[3]),
        .D(rd0_value_i[i]),
        .DPRA0(ra_i[0]), .DPRA1(ra_i[1]), .DPRA2(ra_i[2]), .DPRA3(ra_i[3]),
        .DPO(rs1_0_15_w[i]), .SPO(/* open */)
    );
    RAM16X1D reg_bit2a(
        .WCLK(clk_i), .WE(write_banka_w),
        .A0(rd0_i[0]), .A1(rd0_i[1]), .A2(rd0_i[2]), .A3(rd0_i[3]),
        .D(rd0_value_i[i]),
        .DPRA0(rb_i[0]), .DPRA1(rb_i[1]), .DPRA2(rb_i[2]), .DPRA3(rb_i[3]),
        .DPO(rs2_0_15_w[i]), .SPO(/* open */)
    );
end
endgenerate

// Registers 16-31
generate
for (i = 0; i < VLEN; i = i+1)
begin : reg_loop2
    RAM16X1D reg_bit1b(
        .WCLK(clk_i), .WE(write_bankb_w),
        .A0(rd0_i[0]), .A1(rd0_i[1]), .A2(rd0_i[2]), .A3(rd0_i[3]),
        .D(rd0_value_i[i]),
        .DPRA0(ra_i[0]), .DPRA1(ra_i[1]), .DPRA2(ra_i[2]), .DPRA3(ra_i[3]),
        .DPO(rs1_16_31_w[i]), .SPO(/* open */)
    );
    RAM16X1D reg_bit2b(
        .WCLK(clk_i), .WE(write_bankb_w),
        .A0(rd0_i[0]), .A1(rd0_i[1]), .A2(rd0_i[2]), .A3(rd0_i[3]),
        .D(rd0_value_i[i]),
        .DPRA0(rb_i[0]), .DPRA1(rb_i[1]), .DPRA2(rb_i[2]), .DPRA3(rb_i[3]),
        .DPO(rs2_16_31_w[i]), .SPO(/* open */)
    );
end
endgenerate

//-----------------------------------------------------------------
// Read mux (async)
//-----------------------------------------------------------------
reg [VLEN-1:0] ra_value_r;
reg [VLEN-1:0] rb_value_r;

always @ *
begin
    ra_value_r = (ra_i[4] == 1'b0) ? rs1_0_15_w : rs1_16_31_w;
    rb_value_r = (rb_i[4] == 1'b0) ? rs2_0_15_w : rs2_16_31_w;
end

assign ra_value_o = ra_value_r;
assign rb_value_o = rb_value_r;

// RAM16X1D Verilator model is defined in riscv_xilinx_2r1w.v — do not
// duplicate it here.

endmodule
