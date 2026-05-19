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
     input  [  3:0]     alu_v_func_i
    ,input  [VLEN-1:0]  v_operand_vs1_i
    ,input  [VLEN-1:0]  v_operand_vs2_i
    ,input  [VLEN-1:0]  v_operand_vd_i

    // Outputs
    ,output [VLEN-1:0]  v_result_o
);

//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "riscv_defs.v"

localparam LANES = VLEN / ELEN;

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
            for (i=0; i<LANES; i=i+1)
            result_r[(i+1)*ELEN-1 -: ELEN] = v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN] + v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN];
       end
       //----------------------------------------------
       // VSUB: vd[i] = vs2[i] - vs1[i]
       //----------------------------------------------
       `ALU_V_SUB:
       begin
            for (i=0; i<LANES; i=i+1)
            result_r[(i+1)*ELEN-1 -: ELEN] = v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN] - v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN];
       end
       //----------------------------------------------
       // VRSUB: vd[i] = vs1[i] - vs2[i]
       //----------------------------------------------
       `ALU_V_RSUB:
       begin
            for (i=0; i<LANES; i=i+1)
            result_r[(i+1)*ELEN-1 -: ELEN] = v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN] - v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN];
       end
       //----------------------------------------------
       // VMINU: vd[i] = (vs1[i] < vs2[i]) ? vs1[i] : vs2[i] - unsigned
       //----------------------------------------------
       `ALU_V_MINU:
       begin
            for (i=0; i<LANES; i=i+1) begin
                result_r[(i+1)*ELEN-1 -: ELEN] = ((v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN] < v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN])
                ? v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN] : v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN]);
            end
       end
       //----------------------------------------------
       // VMAXU: vd[i] = (vs1[i] > vs2[i]) ? vs1[i] : vs2[i] - unsigned
       //----------------------------------------------
       `ALU_V_MAXU:
       begin
            for (i=0; i<LANES; i=i+1) begin
                result_r[(i+1)*ELEN-1 -: ELEN] = ((v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN] > v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN])
                ? v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN] : v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN]);
            end
       end
       //----------------------------------------------
       // VMUL: vd[i] = (signed)vs1[i] * (signed)vs2[i] - low ELEN bits
       //----------------------------------------------
       `ALU_V_MUL:
       begin
            for (i=0; i<LANES; i=i+1)
            result_r[(i+1)*ELEN-1 -: ELEN] = $signed(v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN]) * $signed(v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN]);
       end
       //----------------------------------------------
       // VMVX: vd[i] = vs1
       //----------------------------------------------
       `ALU_V_MV_X:
       begin
            result_r = v_operand_vs1_i;
       end
       //----------------------------------------------
       // VREDSUM: vd[0] = vs1[0] + sum vs2[i]
       //----------------------------------------------
       `ALU_V_REDSUM:
       begin
            sum_r = v_operand_vs1_i[ELEN-1:0];
            for (i=0; i<LANES; i=i+1)
            sum_r = sum_r + v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN];
            result_r = {{(VLEN-ELEN){1'b0}}, sum_r};
       end
       //----------------------------------------------
       // VMVXS:
       //----------------------------------------------
       `ALU_V_MV_X_S: 
       begin
          result_r = {{(VLEN-ELEN){1'b0}}, v_operand_vs2_i[ELEN-1:0]};
       end
       `ALU_V_MACC: 
       begin
          for (i=0; i<LANES; i=i+1) begin
               result_r[(i+1)*ELEN-1 -: ELEN] =
                    v_operand_vd_i[(i+1)*ELEN-1 -: ELEN] +
                    (v_operand_vs1_i[(i+1)*ELEN-1 -: ELEN] *
                    v_operand_vs2_i[(i+1)*ELEN-1 -: ELEN]);
          end
       end

       default  :
            result_r = {VLEN{1'b0}};
    endcase
end

assign v_result_o = result_r;

endmodule
