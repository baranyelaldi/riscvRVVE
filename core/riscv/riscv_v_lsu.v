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

module riscv_v_lsu
//-----------------------------------------------------------------
// Params
//-----------------------------------------------------------------
#(
     parameter MEM_CACHE_ADDR_MIN = 32'h80000000
    ,parameter MEM_CACHE_ADDR_MAX = 32'h8fffffff
    ,parameter VLEN = 128
    ,parameter ELEN = 32
)
//-----------------------------------------------------------------
// Ports
//-----------------------------------------------------------------
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           opcode_valid_i
    ,input  [  4:0]  opcode_vd_idx_i
    ,input           is_store_i
    ,input  [ 31:0]  base_addr_i
    ,input  [VLEN-1:0]  store_data_i
    ,input  [ 31:0]  mem_data_rd_i
    ,input           mem_accept_i
    ,input           mem_ack_i
    ,input           mem_error_i

    // Outputs
    ,output [ 31:0]  mem_addr_o
    ,output [ 31:0]  mem_data_wr_o
    ,output          mem_rd_o
    ,output [  3:0]  mem_wr_o
    ,output          mem_cacheable_o
    ,output [ 10:0]  mem_req_tag_o
    ,output          busy_o
    ,output            writeback_valid_o
    ,output [  4:0]    writeback_vd_idx_o
    ,output [VLEN-1:0] writeback_value_o
);

//-----------------------------------------------------------------
// Includes
//-----------------------------------------------------------------
`include "riscv_defs.v"
//-----------------------------------------------------------------
// Registers
//-----------------------------------------------------------------
localparam STATE_IDLE  = 3'd0;
localparam STATE_REQ   = 3'd1;
localparam STATE_WAIT  = 3'd2;
localparam STATE_DONE  = 3'd3;
localparam STATE_ERROR = 3'd4;
localparam BEATS = VLEN / 32; // 32 is hardcoded for bus, not for ELEN
localparam [$clog2(BEATS):0] LAST_BEAT = ($clog2(BEATS)+1)'(BEATS - 1);


reg [     2:0] state_q;
reg [    31:0] addr_q;
reg [VLEN-1:0] buffer_q;
reg [     4:0] vd_idx_q;
reg            is_load_q;
reg [$clog2(BEATS):0] beat_q;

wire last_beat_w;
assign last_beat_w = (beat_q == LAST_BEAT);

//-----------------------------------------------------------------
// Next State
//-----------------------------------------------------------------
reg [2:0] next_state_r;

always @* begin
    next_state_r = state_q;
    case(state_q)
        STATE_IDLE: begin
            if (opcode_valid_i) next_state_r = STATE_REQ;
        end
        STATE_REQ: begin
            if (mem_accept_i) next_state_r = STATE_WAIT;
        end
        STATE_WAIT: begin
            if (mem_ack_i) begin
                if (mem_error_i)
                    next_state_r = STATE_ERROR;
                else if (last_beat_w)
                    next_state_r = STATE_DONE;
                else
                    next_state_r = STATE_REQ;
            end
        end
        STATE_DONE: begin
            next_state_r = STATE_IDLE;
        end
        STATE_ERROR: begin
            next_state_r = STATE_IDLE;
        end
        default:
            next_state_r = STATE_IDLE;
    endcase
end

//-----------------------------------------------------------------
// Sequential Logic
//-----------------------------------------------------------------
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        state_q <= STATE_IDLE;
        addr_q <= 32'b0;
        vd_idx_q <= 0;
        is_load_q <= 1'b0;
        beat_q <= {$clog2(BEATS)+1{1'b0}};
        buffer_q <= {VLEN{1'b0}};
    end
    else begin
        state_q <= next_state_r;

        case (state_q)
            STATE_IDLE: begin
                if (opcode_valid_i) begin
                    addr_q <= base_addr_i;
                    vd_idx_q <= opcode_vd_idx_i;
                    is_load_q <= !is_store_i;
                    beat_q <= {$clog2(BEATS)+1{1'b0}};
                    buffer_q <= is_store_i ? store_data_i : {VLEN{1'b0}};
                end
            end 

            STATE_WAIT: begin
                if (mem_ack_i && !mem_error_i) begin
                    if (is_load_q) begin
                        buffer_q[beat_q*32 +: 32] <= mem_data_rd_i;
                    end
                    beat_q <= beat_q + 1'b1;
                    addr_q <= addr_q + 32'd4;
                end
            end

            STATE_DONE: begin
                beat_q <= {$clog2(BEATS)+1{1'b0}};
            end

            STATE_ERROR: begin
                beat_q <= {$clog2(BEATS)+1{1'b0}};
            end
            
            STATE_REQ: begin
            end

            default: ;
        endcase
    end
end

assign mem_addr_o    = {addr_q[31:2], 2'b00};
assign mem_data_wr_o = buffer_q[beat_q*32 +: 32];
assign mem_rd_o      = (state_q == STATE_REQ) &&  is_load_q;
assign mem_wr_o      = (state_q == STATE_REQ && !is_load_q) ? 4'b1111 : 4'b0;
/* verilator lint_off UNSIGNED */
/* verilator lint_off CMPCONST */
assign mem_cacheable_o = (addr_q >= MEM_CACHE_ADDR_MIN && addr_q <= MEM_CACHE_ADDR_MAX);
/* verilator lint_on  CMPCONST */
/* verilator lint_on  UNSIGNED */
assign mem_req_tag_o   = 11'b0;

assign busy_o = (state_q != STATE_IDLE);

assign writeback_valid_o  = (state_q == STATE_DONE) && is_load_q;
assign writeback_vd_idx_o = vd_idx_q;
assign writeback_value_o  = buffer_q;

endmodule