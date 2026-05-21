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
module riscv_v_alu
#(
    parameter VLEN = 128,
    parameter ELEN = 32
)
(
    // Inputs
     input  [  5:0]     alu_v_func_i
    ,input  [VLEN-1:0]  v_operand_vs1_i
    ,input  [VLEN-1:0]  v_operand_vs2_i
    ,input  [VLEN-1:0]  v_operand_vd_i
    ,input  [ 31:0]     vl_i
    ,input  [  2:0]     sew_i

    // Outputs
    ,output [VLEN-1:0]  v_result_o
);

//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "riscv_defs.v"

// Lane counts per SEW. With VLEN=128: e8=16, e16=8, e32=4.
localparam LANES_E8  = VLEN / 8;
localparam LANES_E16 = VLEN / 16;
localparam LANES_E32 = VLEN / 32;
localparam LANES     = LANES_E32;  // retained for mask logical/reduction iteration bound

//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
reg [VLEN-1:0]      result_r;
reg [ELEN-1:0]      sum_r;
integer i;

//-----------------------------------------------------------------
// ALU
//-----------------------------------------------------------------
always @*
begin
    result_r = {VLEN{1'b0}};
    sum_r    = {ELEN{1'b0}};

    case (alu_v_func_i)
       //----------------------------------------------
       // VADD: vd[i] = vs2[i] + vs1[i]
       //----------------------------------------------
       `ALU_V_ADD:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vs2_i[(i+1)*8-1 -: 8] +
                            v_operand_vs1_i[(i+1)*8-1 -: 8];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vs2_i[(i+1)*16-1 -: 16] +
                            v_operand_vs1_i[(i+1)*16-1 -: 16];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vs2_i[(i+1)*32-1 -: 32] +
                            v_operand_vs1_i[(i+1)*32-1 -: 32];
                end
            endcase
       end
       //----------------------------------------------
       // VSUB: vd[i] = vs2[i] - vs1[i]
       //----------------------------------------------
       `ALU_V_SUB:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vs2_i[(i+1)*8-1 -: 8] -
                            v_operand_vs1_i[(i+1)*8-1 -: 8];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vs2_i[(i+1)*16-1 -: 16] -
                            v_operand_vs1_i[(i+1)*16-1 -: 16];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vs2_i[(i+1)*32-1 -: 32] -
                            v_operand_vs1_i[(i+1)*32-1 -: 32];
                end
            endcase
       end
       //----------------------------------------------
       // VRSUB: vd[i] = vs1[i] - vs2[i]
       //----------------------------------------------
       `ALU_V_RSUB:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vs1_i[(i+1)*8-1 -: 8] -
                            v_operand_vs2_i[(i+1)*8-1 -: 8];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vs1_i[(i+1)*16-1 -: 16] -
                            v_operand_vs2_i[(i+1)*16-1 -: 16];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vs1_i[(i+1)*32-1 -: 32] -
                            v_operand_vs2_i[(i+1)*32-1 -: 32];
                end
            endcase
       end
       //----------------------------------------------
       // VMINU: vd[i] = min(vs1[i], vs2[i]) unsigned
       //----------------------------------------------
       `ALU_V_MINU:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            (v_operand_vs1_i[(i+1)*8-1 -: 8] < v_operand_vs2_i[(i+1)*8-1 -: 8])
                            ? v_operand_vs1_i[(i+1)*8-1 -: 8]
                            : v_operand_vs2_i[(i+1)*8-1 -: 8];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            (v_operand_vs1_i[(i+1)*16-1 -: 16] < v_operand_vs2_i[(i+1)*16-1 -: 16])
                            ? v_operand_vs1_i[(i+1)*16-1 -: 16]
                            : v_operand_vs2_i[(i+1)*16-1 -: 16];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            (v_operand_vs1_i[(i+1)*32-1 -: 32] < v_operand_vs2_i[(i+1)*32-1 -: 32])
                            ? v_operand_vs1_i[(i+1)*32-1 -: 32]
                            : v_operand_vs2_i[(i+1)*32-1 -: 32];
                end
            endcase
       end
       //----------------------------------------------
       // VMAXU: vd[i] = max(vs1[i], vs2[i]) unsigned
       //----------------------------------------------
       `ALU_V_MAXU:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            (v_operand_vs1_i[(i+1)*8-1 -: 8] > v_operand_vs2_i[(i+1)*8-1 -: 8])
                            ? v_operand_vs1_i[(i+1)*8-1 -: 8]
                            : v_operand_vs2_i[(i+1)*8-1 -: 8];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            (v_operand_vs1_i[(i+1)*16-1 -: 16] > v_operand_vs2_i[(i+1)*16-1 -: 16])
                            ? v_operand_vs1_i[(i+1)*16-1 -: 16]
                            : v_operand_vs2_i[(i+1)*16-1 -: 16];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            (v_operand_vs1_i[(i+1)*32-1 -: 32] > v_operand_vs2_i[(i+1)*32-1 -: 32])
                            ? v_operand_vs1_i[(i+1)*32-1 -: 32]
                            : v_operand_vs2_i[(i+1)*32-1 -: 32];
                end
            endcase
       end
       //----------------------------------------------
       // VMUL: vd[i] = (signed)vs1[i] * (signed)vs2[i], low SEW bits only
       //----------------------------------------------
       `ALU_V_MUL:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            $signed(v_operand_vs2_i[(i+1)*8-1 -: 8]) *
                            $signed(v_operand_vs1_i[(i+1)*8-1 -: 8]);
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            $signed(v_operand_vs2_i[(i+1)*16-1 -: 16]) *
                            $signed(v_operand_vs1_i[(i+1)*16-1 -: 16]);
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            $signed(v_operand_vs2_i[(i+1)*32-1 -: 32]) *
                            $signed(v_operand_vs1_i[(i+1)*32-1 -: 32]);
                end
            endcase
       end
       //----------------------------------------------
       // VMACC: vd[i] = vd[i] + vs1[i] * vs2[i]
       //----------------------------------------------
       `ALU_V_MACC:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vd_i[(i+1)*8-1 -: 8] +
                            (v_operand_vs1_i[(i+1)*8-1 -: 8] *
                             v_operand_vs2_i[(i+1)*8-1 -: 8]);
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vd_i[(i+1)*16-1 -: 16] +
                            (v_operand_vs1_i[(i+1)*16-1 -: 16] *
                             v_operand_vs2_i[(i+1)*16-1 -: 16]);
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vd_i[(i+1)*32-1 -: 32] +
                            (v_operand_vs1_i[(i+1)*32-1 -: 32] *
                             v_operand_vs2_i[(i+1)*32-1 -: 32]);
                end
            endcase
       end
       //----------------------------------------------
       // VSLL: vd[i] = vs2[i] << vs1[i][SHIFT_BITS-1:0]
       //----------------------------------------------
       `ALU_V_SLL:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vs2_i[(i+1)*8-1 -: 8] <<
                            v_operand_vs1_i[i*8 +: 3];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vs2_i[(i+1)*16-1 -: 16] <<
                            v_operand_vs1_i[i*16 +: 4];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vs2_i[(i+1)*32-1 -: 32] <<
                            v_operand_vs1_i[i*32 +: 5];
                end
            endcase
       end
       //----------------------------------------------
       // VSRL: logical right shift
       //----------------------------------------------
       `ALU_V_SRL:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vs2_i[(i+1)*8-1 -: 8] >>
                            v_operand_vs1_i[i*8 +: 3];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vs2_i[(i+1)*16-1 -: 16] >>
                            v_operand_vs1_i[i*16 +: 4];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vs2_i[(i+1)*32-1 -: 32] >>
                            v_operand_vs1_i[i*32 +: 5];
                end
            endcase
       end
       //----------------------------------------------
       // VSRA: arithmetic right shift (sign-extend)
       //----------------------------------------------
       `ALU_V_SRA:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            $signed(v_operand_vs2_i[(i+1)*8-1 -: 8]) >>>
                            v_operand_vs1_i[i*8 +: 3];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            $signed(v_operand_vs2_i[(i+1)*16-1 -: 16]) >>>
                            v_operand_vs1_i[i*16 +: 4];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            $signed(v_operand_vs2_i[(i+1)*32-1 -: 32]) >>>
                            v_operand_vs1_i[i*32 +: 5];
                end
            endcase
       end
       //----------------------------------------------
       // VAND: per-lane bitwise AND. SEW determines which lanes are gated by vl.
       //----------------------------------------------
       `ALU_V_AND:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vs2_i[(i+1)*8-1 -: 8] &
                            v_operand_vs1_i[(i+1)*8-1 -: 8];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vs2_i[(i+1)*16-1 -: 16] &
                            v_operand_vs1_i[(i+1)*16-1 -: 16];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vs2_i[(i+1)*32-1 -: 32] &
                            v_operand_vs1_i[(i+1)*32-1 -: 32];
                end
            endcase
       end
       //----------------------------------------------
       // VOR
       //----------------------------------------------
       `ALU_V_OR:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vs2_i[(i+1)*8-1 -: 8] |
                            v_operand_vs1_i[(i+1)*8-1 -: 8];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vs2_i[(i+1)*16-1 -: 16] |
                            v_operand_vs1_i[(i+1)*16-1 -: 16];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vs2_i[(i+1)*32-1 -: 32] |
                            v_operand_vs1_i[(i+1)*32-1 -: 32];
                end
            endcase
       end
       //----------------------------------------------
       // VXOR
       //----------------------------------------------
       `ALU_V_XOR:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] =
                            v_operand_vs2_i[(i+1)*8-1 -: 8] ^
                            v_operand_vs1_i[(i+1)*8-1 -: 8];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] =
                            v_operand_vs2_i[(i+1)*16-1 -: 16] ^
                            v_operand_vs1_i[(i+1)*16-1 -: 16];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] =
                            v_operand_vs2_i[(i+1)*32-1 -: 32] ^
                            v_operand_vs1_i[(i+1)*32-1 -: 32];
                end
            endcase
       end
       //----------------------------------------------
       // VMVX: broadcast scalar rs1 to all active lanes
       //----------------------------------------------
       `ALU_V_MV_X:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] = v_operand_vs1_i[7:0];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] = v_operand_vs1_i[15:0];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] = v_operand_vs1_i[31:0];
                end
            endcase
       end
       //----------------------------------------------
       // VREDSUM: vd[0] = vs1[0] + sum vs2[0..vl-1]; result in low SEW bits
       //----------------------------------------------
       `ALU_V_REDSUM:
       begin
            case (sew_i)
                `SEW_E8: begin
                    sum_r = {24'b0, v_operand_vs1_i[7:0]};
                    for (i = 0; i < LANES_E8; i = i + 1) begin
                        if (i < vl_i)
                            sum_r = sum_r + {24'b0, v_operand_vs2_i[(i+1)*8-1 -: 8]};
                    end
                    result_r = {{(VLEN-8){1'b0}}, sum_r[7:0]};
                end
                `SEW_E16: begin
                    sum_r = {16'b0, v_operand_vs1_i[15:0]};
                    for (i = 0; i < LANES_E16; i = i + 1) begin
                        if (i < vl_i)
                            sum_r = sum_r + {16'b0, v_operand_vs2_i[(i+1)*16-1 -: 16]};
                    end
                    result_r = {{(VLEN-16){1'b0}}, sum_r[15:0]};
                end
                default: begin
                    sum_r = v_operand_vs1_i[31:0];
                    for (i = 0; i < LANES_E32; i = i + 1) begin
                        if (i < vl_i)
                            sum_r = sum_r + v_operand_vs2_i[(i+1)*32-1 -: 32];
                    end
                    result_r = {{(VLEN-32){1'b0}}, sum_r};
                end
            endcase
       end
       //----------------------------------------------
       // VMVXS: rd = sign-extended vs2[0] (SEW-wide)
       //----------------------------------------------
       `ALU_V_MV_X_S:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8:  result_r[31:0] = {{24{v_operand_vs2_i[7]}},  v_operand_vs2_i[7:0]};
                `SEW_E16: result_r[31:0] = {{16{v_operand_vs2_i[15]}}, v_operand_vs2_i[15:0]};
                default:  result_r[31:0] = v_operand_vs2_i[31:0];
            endcase
       end
       //----------------------------------------------
       // VMSEQ: mask bit i = (vs2[i] == vs1[i])
       //----------------------------------------------
       `ALU_V_MSEQ:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*8-1 -: 8] == v_operand_vs1_i[(i+1)*8-1 -: 8])
                        result_r[i] = 1'b1;
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*16-1 -: 16] == v_operand_vs1_i[(i+1)*16-1 -: 16])
                        result_r[i] = 1'b1;
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*32-1 -: 32] == v_operand_vs1_i[(i+1)*32-1 -: 32])
                        result_r[i] = 1'b1;
                end
            endcase
       end
       //----------------------------------------------
       // VMSNE
       //----------------------------------------------
       `ALU_V_MSNE:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*8-1 -: 8] != v_operand_vs1_i[(i+1)*8-1 -: 8])
                        result_r[i] = 1'b1;
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*16-1 -: 16] != v_operand_vs1_i[(i+1)*16-1 -: 16])
                        result_r[i] = 1'b1;
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*32-1 -: 32] != v_operand_vs1_i[(i+1)*32-1 -: 32])
                        result_r[i] = 1'b1;
                end
            endcase
       end
       //----------------------------------------------
       // VMSLTU (unsigned <)
       //----------------------------------------------
       `ALU_V_MSLTU:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*8-1 -: 8] < v_operand_vs1_i[(i+1)*8-1 -: 8])
                        result_r[i] = 1'b1;
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*16-1 -: 16] < v_operand_vs1_i[(i+1)*16-1 -: 16])
                        result_r[i] = 1'b1;
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*32-1 -: 32] < v_operand_vs1_i[(i+1)*32-1 -: 32])
                        result_r[i] = 1'b1;
                end
            endcase
       end
       //----------------------------------------------
       // VMSLT (signed <)
       //----------------------------------------------
       `ALU_V_MSLT:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*8-1 -: 8]) < $signed(v_operand_vs1_i[(i+1)*8-1 -: 8]))
                        result_r[i] = 1'b1;
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*16-1 -: 16]) < $signed(v_operand_vs1_i[(i+1)*16-1 -: 16]))
                        result_r[i] = 1'b1;
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*32-1 -: 32]) < $signed(v_operand_vs1_i[(i+1)*32-1 -: 32]))
                        result_r[i] = 1'b1;
                end
            endcase
       end
       //----------------------------------------------
       // VMSLEU (unsigned <=)
       //----------------------------------------------
       `ALU_V_MSLEU:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*8-1 -: 8] <= v_operand_vs1_i[(i+1)*8-1 -: 8])
                        result_r[i] = 1'b1;
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*16-1 -: 16] <= v_operand_vs1_i[(i+1)*16-1 -: 16])
                        result_r[i] = 1'b1;
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*32-1 -: 32] <= v_operand_vs1_i[(i+1)*32-1 -: 32])
                        result_r[i] = 1'b1;
                end
            endcase
       end
       //----------------------------------------------
       // VMSLE (signed <=)
       //----------------------------------------------
       `ALU_V_MSLE:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*8-1 -: 8]) <= $signed(v_operand_vs1_i[(i+1)*8-1 -: 8]))
                        result_r[i] = 1'b1;
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*16-1 -: 16]) <= $signed(v_operand_vs1_i[(i+1)*16-1 -: 16]))
                        result_r[i] = 1'b1;
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*32-1 -: 32]) <= $signed(v_operand_vs1_i[(i+1)*32-1 -: 32]))
                        result_r[i] = 1'b1;
                end
            endcase
       end
       //----------------------------------------------
       // VMSGTU (unsigned >)
       //----------------------------------------------
       `ALU_V_MSGTU:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*8-1 -: 8] > v_operand_vs1_i[(i+1)*8-1 -: 8])
                        result_r[i] = 1'b1;
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*16-1 -: 16] > v_operand_vs1_i[(i+1)*16-1 -: 16])
                        result_r[i] = 1'b1;
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i && v_operand_vs2_i[(i+1)*32-1 -: 32] > v_operand_vs1_i[(i+1)*32-1 -: 32])
                        result_r[i] = 1'b1;
                end
            endcase
       end
       //----------------------------------------------
       // VMSGT (signed >)
       //----------------------------------------------
       `ALU_V_MSGT:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*8-1 -: 8]) > $signed(v_operand_vs1_i[(i+1)*8-1 -: 8]))
                        result_r[i] = 1'b1;
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*16-1 -: 16]) > $signed(v_operand_vs1_i[(i+1)*16-1 -: 16]))
                        result_r[i] = 1'b1;
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i && $signed(v_operand_vs2_i[(i+1)*32-1 -: 32]) > $signed(v_operand_vs1_i[(i+1)*32-1 -: 32]))
                        result_r[i] = 1'b1;
                end
            endcase
       end
       //----------------------------------------------
       // Mask logicals: mask format is 1-bit-per-element regardless of SEW.
       // Iterate up to LANES_E8 (max possible lanes); gate by vl_i.
       //----------------------------------------------
       `ALU_V_MAND:
       begin
            result_r = {VLEN{1'b0}};
            for (i = 0; i < LANES_E8; i = i + 1) begin
                if (i < vl_i)
                    result_r[i] = v_operand_vs2_i[i] & v_operand_vs1_i[i];
            end
       end
       `ALU_V_MOR:
       begin
            result_r = {VLEN{1'b0}};
            for (i = 0; i < LANES_E8; i = i + 1) begin
                if (i < vl_i)
                    result_r[i] = v_operand_vs2_i[i] | v_operand_vs1_i[i];
            end
       end
       `ALU_V_MXOR:
       begin
            result_r = {VLEN{1'b0}};
            for (i = 0; i < LANES_E8; i = i + 1) begin
                if (i < vl_i)
                    result_r[i] = v_operand_vs2_i[i] ^ v_operand_vs1_i[i];
            end
       end
       `ALU_V_MNAND:
       begin
            result_r = {VLEN{1'b0}};
            for (i = 0; i < LANES_E8; i = i + 1) begin
                if (i < vl_i)
                    result_r[i] = ~(v_operand_vs2_i[i] & v_operand_vs1_i[i]);
            end
       end
       //----------------------------------------------
       // VCPOP: count 1-bits in first vl_i bits of vs2 (mask). SEW-independent.
       //----------------------------------------------
       `ALU_V_CPOP:
       begin
            result_r = {VLEN{1'b0}};
            for (i = 0; i < LANES_E8; i = i + 1) begin
                if (i < vl_i)
                    result_r[31:0] = result_r[31:0] + {31'b0, v_operand_vs2_i[i]};
            end
       end
       //----------------------------------------------
       // VFIRST: index of lowest set bit in first vl_i bits of vs2, or -1.
       //----------------------------------------------
       `ALU_V_FIRST:
       begin
            result_r = {VLEN{1'b0}};
            result_r[31:0] = 32'hFFFFFFFF;  // default: no match
            // Iterate high-to-low so the lowest set bit wins (last assignment)
            for (i = LANES_E8 - 1; i >= 0; i = i - 1) begin
                if (i < vl_i && v_operand_vs2_i[i])
                    result_r[31:0] = i[31:0];
            end
       end
       //----------------------------------------------
       // VMVSX: write SEW-wide rs1 to lane 0; other lanes zero
       //----------------------------------------------
       `ALU_V_MV_S_X:
       begin
            result_r = {VLEN{1'b0}};
            if (vl_i > 0) begin
                case (sew_i)
                    `SEW_E8:  result_r[7:0]  = v_operand_vs1_i[7:0];
                    `SEW_E16: result_r[15:0] = v_operand_vs1_i[15:0];
                    default:  result_r[31:0] = v_operand_vs1_i[31:0];
                endcase
            end
       end
       //----------------------------------------------
       // VID: vd[i] = i, written into SEW-wide slot
       //----------------------------------------------
       `ALU_V_VID:
       begin
            result_r = {VLEN{1'b0}};
            case (sew_i)
                `SEW_E8: for (i = 0; i < LANES_E8; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*8-1 -: 8] = i[7:0];
                end
                `SEW_E16: for (i = 0; i < LANES_E16; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*16-1 -: 16] = i[15:0];
                end
                default: for (i = 0; i < LANES_E32; i = i + 1) begin
                    if (i < vl_i)
                        result_r[(i+1)*32-1 -: 32] = i[31:0];
                end
            endcase
       end

       default:
            result_r = {VLEN{1'b0}};
    endcase
end

assign v_result_o = result_r;

endmodule