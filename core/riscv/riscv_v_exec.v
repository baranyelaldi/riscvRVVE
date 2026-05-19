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

module riscv_v_exec
#(
    parameter VLEN = 128,
    parameter ELEN = 32
)
(
    // Inputs
     input              clk_i
    ,input              rst_i
    ,input              opcode_valid_i
    ,input              opcode_invalid_i
    ,input  [  4:0]     opcode_vd_idx_i
    ,input  [VLEN-1:0]  v_operand_vs1_i
    ,input  [VLEN-1:0]  v_operand_vs2_i
    ,input  [VLEN-1:0]  v_operand_vd_i
    ,input  [ 3:0]      alu_v_func_i
    ,input              v_to_scalar_i

    // Outputs
    ,output             writeback_valid_o
    ,output [     4:0]  writeback_vd_idx_o
    ,output [VLEN-1:0]  writeback_value_o
    ,output [31:0]      v_exec_scalar_value_o
    ,output             v_exec_scalar_we_o
    ,output [4:0]       v_exec_scalar_rd_o
);



//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "riscv_defs.v"
//-------------------------------------------------------------
// V-ALU
//-------------------------------------------------------------
wire [VLEN-1:0] v_result_w;

riscv_v_alu
#(
    .VLEN(VLEN),
    .ELEN(ELEN)
)
u_v_alu
(
    .alu_v_func_i(alu_v_func_i),
    .v_operand_vs1_i(v_operand_vs1_i),
    .v_operand_vs2_i(v_operand_vs2_i),
    .v_operand_vd_i(v_operand_vd_i),
    .v_result_o(v_result_w)
);

//-------------------------------------------------------------
// Writeback
//-------------------------------------------------------------
reg               writeback_valid_q;
reg [     4:0]    writeback_vd_idx_q;
reg [VLEN-1:0]    writeback_value_q;
reg               v_to_scalar_q;

always @ (posedge clk_i)
if (rst_i) begin
    writeback_valid_q  <= 1'b0;
    writeback_vd_idx_q <= 5'b0;
    writeback_value_q  <= {VLEN{1'b0}};
    v_to_scalar_q      <= 1'b0;
end
else begin
    writeback_valid_q <= opcode_valid_i;
    if (opcode_valid_i) begin
        writeback_vd_idx_q <= opcode_vd_idx_i;
        writeback_value_q  <= v_result_w;
        v_to_scalar_q      <= v_to_scalar_i;
    end
end

assign writeback_valid_o = writeback_valid_q & ~v_to_scalar_q;
assign writeback_vd_idx_o = writeback_vd_idx_q;
assign writeback_value_o  = writeback_value_q;

assign v_exec_scalar_value_o = writeback_value_q[31:0];
assign v_exec_scalar_we_o    = writeback_valid_q & v_to_scalar_q;
assign v_exec_scalar_rd_o    = writeback_vd_idx_q;

endmodule
