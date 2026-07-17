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
    ,input           is_strided_i
    ,input  [ 31:0]  stride_i
    ,input  [ 31:0]  vl_i
    ,input  [  2:0]  sew_i


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
localparam STATE_IDLE   = 3'd0;
localparam STATE_ACTIVE = 3'd1;
localparam STATE_DONE   = 3'd3;
localparam STATE_ERROR  = 3'd4;
localparam BEATS = VLEN / 32; // 32 is hardcoded for bus, not for ELEN


reg [     2:0] state_q;
reg [    31:0] addr_q;
reg [VLEN-1:0] buffer_q;
reg [     4:0] vd_idx_q;
reg            is_load_q;
reg [$clog2(BEATS):0] req_beat_q;   // beats requested (accepted by the bus)
reg [$clog2(BEATS):0] resp_beat_q;  // beats acknowledged (data returned)
reg            err_seen_q;
reg [    31:0] stride_q;
reg            is_strided_q;
reg [    31:0] vl_q;
reg [     2:0] sew_q;

//-----------------------------------------------------------------
// SEW-driven byte count and last-beat byte enables
//-----------------------------------------------------------------
// bytes_per_elem: 1 (e8), 2 (e16), 4 (e32). Drives byte_count.
reg [2:0] bytes_per_elem;
always @* begin
    case (sew_q)
        `SEW_E8:  bytes_per_elem = 3'd1;
        `SEW_E16: bytes_per_elem = 3'd2;
        default:  bytes_per_elem = 3'd4;
    endcase
end

// Total bytes to transfer this instruction
wire [31:0] byte_count_w = vl_q * {29'b0, bytes_per_elem};

// Beats needed: ceil(byte_count / 4)
wire [31:0] beats_needed_w = (byte_count_w + 32'd3) >> 2;

// Bytes that go into the LAST beat (range: 1..4)
wire [31:0] last_beat_bytes_w = byte_count_w - ((beats_needed_w - 32'd1) << 2);

// Byte-enable mask for the last beat. Other beats use 4'b1111.
reg [3:0] last_beat_enables_r;
always @* begin
    case (last_beat_bytes_w[2:0])
        3'd1:    last_beat_enables_r = 4'b0001;
        3'd2:    last_beat_enables_r = 4'b0011;
        3'd3:    last_beat_enables_r = 4'b0111;
        default: last_beat_enables_r = 4'b1111;  // 4 bytes = full word
    endcase
end

//-----------------------------------------------------------------
// Request / response progress
//-----------------------------------------------------------------
// Beats are pipelined: a new request is issued every cycle the bus
// accepts, without waiting for the previous beat's ack. Acks return
// in order (dport contract), so a single response counter steers the
// returning data into the right buffer slot.
wire [$clog2(BEATS):0] beats_needed_trunc_w = beats_needed_w[$clog2(BEATS):0];
wire req_pending_w = (req_beat_q  != beats_needed_trunc_w);
wire req_last_w    = (req_beat_q  == beats_needed_trunc_w - 1'b1);
wire resp_last_w   = (resp_beat_q == beats_needed_trunc_w - 1'b1);
wire req_active_w  = (state_q == STATE_ACTIVE) && req_pending_w;

//-----------------------------------------------------------------
// Next State
//-----------------------------------------------------------------
reg [2:0] next_state_r;

always @* begin
    next_state_r = state_q;
    case(state_q)
        STATE_IDLE: begin
            if (opcode_valid_i) begin
                if (vl_i == 32'b0) next_state_r = STATE_DONE;
                else next_state_r = STATE_ACTIVE;
            end
        end
        STATE_ACTIVE: begin
            // Leave only on the final ack: every issued beat has returned,
            // so no response can arrive once busy_o drops (the core steers
            // accept/ack by busy_o — see riscv_core.v dport mux).
            if (mem_ack_i && resp_last_w) begin
                if (mem_error_i || err_seen_q)
                    next_state_r = STATE_ERROR;
                else
                    next_state_r = STATE_DONE;
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
        state_q      <= STATE_IDLE;
        addr_q       <= 32'b0;
        vd_idx_q     <= 0;
        is_load_q    <= 1'b0;
        req_beat_q   <= {$clog2(BEATS)+1{1'b0}};
        resp_beat_q  <= {$clog2(BEATS)+1{1'b0}};
        err_seen_q   <= 1'b0;
        buffer_q     <= {VLEN{1'b0}};
        stride_q     <= 32'b0;
        is_strided_q <= 1'b0;
        vl_q         <= 32'b0;
        sew_q        <= `SEW_E32;
    end
    else begin
        state_q <= next_state_r;

        case (state_q)
            STATE_IDLE: begin
                if (opcode_valid_i) begin
                    addr_q       <= base_addr_i;
                    vd_idx_q     <= opcode_vd_idx_i;
                    is_load_q    <= !is_store_i;
                    req_beat_q   <= {$clog2(BEATS)+1{1'b0}};
                    resp_beat_q  <= {$clog2(BEATS)+1{1'b0}};
                    err_seen_q   <= 1'b0;
                    buffer_q     <= is_store_i ? store_data_i : {VLEN{1'b0}};
                    stride_q     <= stride_i;
                    is_strided_q <= is_strided_i;
                    vl_q         <= vl_i;
                    sew_q        <= sew_i;
                end
            end

            STATE_ACTIVE: begin
                // Request side: advance address on every accepted beat
                if (req_pending_w && mem_accept_i) begin
                    req_beat_q <= req_beat_q + 1'b1;
                    addr_q     <= addr_q + (is_strided_q ? stride_q : 32'd4);
                end
                // Response side: capture returning beats in request order.
                // On error, keep draining acks (busy_o must stay high while
                // responses are outstanding) and suppress the writeback later.
                if (mem_ack_i) begin
                    if (mem_error_i)
                        err_seen_q <= 1'b1;
                    else if (is_load_q) begin
                        // Per-byte gated write — on the last beat, only enabled
                        // bytes update; tail bytes stay 0 from IDLE reset.
                        if (!resp_last_w || last_beat_enables_r[0])
                            buffer_q[resp_beat_q*32 +  0 +: 8] <= mem_data_rd_i[ 7: 0];
                        if (!resp_last_w || last_beat_enables_r[1])
                            buffer_q[resp_beat_q*32 +  8 +: 8] <= mem_data_rd_i[15: 8];
                        if (!resp_last_w || last_beat_enables_r[2])
                            buffer_q[resp_beat_q*32 + 16 +: 8] <= mem_data_rd_i[23:16];
                        if (!resp_last_w || last_beat_enables_r[3])
                            buffer_q[resp_beat_q*32 + 24 +: 8] <= mem_data_rd_i[31:24];
                    end
                    resp_beat_q <= resp_beat_q + 1'b1;
                end
            end

            STATE_DONE: begin
            end

            STATE_ERROR: begin
            end

            default: ;
        endcase
    end
end

assign mem_addr_o    = {addr_q[31:2], 2'b00};
assign mem_data_wr_o = buffer_q[req_beat_q*32 +: 32];
assign mem_rd_o      = req_active_w &&  is_load_q;
// Byte enables: full 4'b1111 except on the last beat (partial last beat)
assign mem_wr_o      = (req_active_w && !is_load_q)
                       ? (req_last_w ? last_beat_enables_r : 4'b1111)
                       : 4'b0;
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