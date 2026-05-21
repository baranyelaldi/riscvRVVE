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

module riscv_v_csr
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
    parameter VLEN             = 128
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           opcode_valid_i
    ,input  [ 31:0]  opcode_opcode_i
    ,input  [  4:0]  opcode_rd_idx_i
    ,input  [  4:0]  opcode_rs1_idx_i
    ,input  [ 31:0]  opcode_rs1_value_i
    ,input  [ 31:0]  csr_vl_current_i

    // Outputs
    ,output          csr_vl_we_o
    ,output [ 31:0]  csr_vl_wdata_o
    ,output          csr_vtype_we_o
    ,output [ 31:0]  csr_vtype_wdata_o

    ,output [ 31:0]  writeback_scalar_value_o
    ,output          writeback_scalar_we_o
    ,output [  4:0]  writeback_scalar_rd_o
);

//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "riscv_defs.v"

wire is_vsetivli = opcode_opcode_i[31];
wire [10:0] vtypei = is_vsetivli ? {1'b0, opcode_opcode_i[29:20]} : opcode_opcode_i[30:20];

wire [2:0] req_vsew  = vtypei[5:3];
wire [2:0] req_vlmul = vtypei[2:0];

// Validate scope: SEW ∈ {e8, e16, e32}, LMUL = m1 (000)
wire vsew_valid  = (req_vsew == 3'b000) || (req_vsew == 3'b001) || (req_vsew == 3'b010);
wire vlmul_valid = (req_vlmul == 3'b000);
wire vtype_valid = vsew_valid && vlmul_valid;

// Compute VLMAX = VLEN / SEW (for LMUL=1)
reg [31:0] vlmax;
always @* begin
    case (req_vsew)
        3'b000: vlmax = VLEN / 8;    // = 16 for VLEN=128
        3'b001: vlmax = VLEN / 16;   // = 8
        3'b010: vlmax = VLEN / 32;   // = 4
        default: vlmax = 0;           // invalid
    endcase
end

wire rs1_is_zero  = (opcode_rs1_idx_i == 5'd0);
wire rd_is_zero   = (opcode_rd_idx_i == 5'd0);

// For vsetivli, AVL is uimm — never has the rs1=x0 special meaning
wire avl_use_vlmax = ~is_vsetivli && rs1_is_zero && ~rd_is_zero;
wire vl_keep       = ~is_vsetivli && rs1_is_zero &&  rd_is_zero;

wire [31:0] avl = is_vsetivli
                ? {27'b0, opcode_opcode_i[19:15]}
                : opcode_rs1_value_i;

reg [31:0] new_vl;
always @* begin
    if (!vtype_valid)       new_vl = 32'd0;
    else if (vl_keep)       new_vl = csr_vl_current_i;
    else if (avl_use_vlmax) new_vl = vlmax;
    else                    new_vl = (avl < vlmax) ? avl : vlmax;
end

wire [31:0] new_vtype = vtype_valid
                      ? {24'b0, vtypei[7:0]}
                      : (32'h80000000 | {24'b0, vtypei[7:0]});       // bit 31 = vill

reg        wb_valid_q;
reg [31:0] wb_vl_q;
reg [31:0] wb_vtype_q;
reg [ 4:0] wb_rd_q;

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        wb_valid_q <= 1'b0;
        wb_vl_q    <= 32'b0;
        wb_vtype_q <= 32'b0;
        wb_rd_q    <= 5'b0;
    end else begin
        wb_valid_q <= opcode_valid_i;
        if (opcode_valid_i) begin
            wb_vl_q    <= new_vl;
            wb_vtype_q <= new_vtype;
            wb_rd_q    <= opcode_rd_idx_i;
        end
    end
end

assign csr_vl_we_o        = opcode_valid_i;
assign csr_vl_wdata_o     = new_vl;
assign csr_vtype_we_o     = opcode_valid_i;
assign csr_vtype_wdata_o  = new_vtype;
assign writeback_scalar_value_o = wb_vl_q;
assign writeback_scalar_we_o    = wb_valid_q;
assign writeback_scalar_rd_o    = wb_rd_q;

endmodule
