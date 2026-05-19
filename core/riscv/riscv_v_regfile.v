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
module riscv_v_regfile
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter VLEN = 128,
     parameter SUPPORT_REGFILE_XILINX = 0
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input              clk_i
    ,input              rst_i
    ,input  [  4:0]     rd0_i
    ,input  [VLEN-1:0]  rd0_value_i
    ,input              rd0_we_i
    ,input  [  4:0]     ra0_i
    ,input  [  4:0]     rb0_i
    ,input  [  4:0]     ra1_i // 3rd read port

    // Outputs
    ,output [VLEN-1:0]  ra0_value_o
    ,output [VLEN-1:0]  rb0_value_o
    ,output [VLEN-1:0]  ra1_value_o
);

//-----------------------------------------------------------------
// Xilinx specific register file (single issue)
//-----------------------------------------------------------------
generate
if (SUPPORT_REGFILE_XILINX)
begin: REGFILE_XILINX_SINGLE

    riscv_xilinx_2r1w
    u_reg
    (
        // Inputs
         .clk_i(clk_i)
        ,.rst_i(rst_i)
        ,.rd0_i(rd0_i)
        ,.rd0_value_i(rd0_value_i)
        ,.ra_i(ra0_i)
        ,.rb_i(rb0_i)

        // Outputs
        ,.ra_value_o(ra0_value_o)
        ,.rb_value_o(rb0_value_o)
    );
    // TODO: 3rd read port unsupported in Xilinx mode for now — vmacc won't synthesize correctly here.
    // Fix by adding a second xilinx_2r1w instance (writes mirrored) when we need FPGA.
    assign ra1_value_o = {VLEN{1'b0}};
end
//-----------------------------------------------------------------
// Flop based register file
//-----------------------------------------------------------------
else
begin: REGFILE
    reg [VLEN-1:0] vregs_q [0:31];
    
    integer i;
    always @ (posedge clk_i )
    if (rst_i)
    begin
        for (i=0; i<32; i=i+1) vregs_q[i] <= {VLEN{1'b0}};
    end
    else if (rd0_we_i)
    begin
        vregs_q[rd0_i] <= rd0_value_i;
    end

    assign ra0_value_o = vregs_q[ra0_i];
    assign rb0_value_o = vregs_q[rb0_i];
    assign ra1_value_o = vregs_q[ra1_i];

//    //-------------------------------------------------------------
//    // get_register: Read register file
//    //-------------------------------------------------------------
//    `ifdef verilator
//    function [VLEN-1:0] get_v_register; /*verilator public*/
//        input [4:0] r;
//        get_v_register = vregs_q[r];
//    endfunction
//    `endif

end
endgenerate

endmodule
