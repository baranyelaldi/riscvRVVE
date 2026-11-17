// UART program loader for the 64KB TCM.
//
// Protocol (sent by tools/load.py):
//   "RVLD"            4-byte sync marker (0x52 0x56 0x4C 0x44)
//   65536 bytes       full TCM image, word 0 first, each word little-endian
//
// Sequence:
//   1. IDLE  : watch the RX byte stream for "RVLD".
//   2. RESET : pulse sys_rst_o for a few cycles so no half-finished CPU bus
//              access (e.g. a UART write) survives the load.
//   3. LOAD  : hold the CPU in reset (cpu_hold_o) and write every received word
//              to the TCM through its AXI slave port, one single-beat write per
//              word (awlen=0). The UART delivers a byte every ~2000 cycles, so a
//              write always completes before the next byte arrives.
//   4. Done  : release the CPU, which boots from the reset vector (0x2000).
//
// If no byte arrives for TIMEOUT_CYCLES during the load, the transfer is
// abandoned and the loader returns to IDLE (the CPU is released).
module uart_loader
#(
     parameter WORDS          = 16384          // 64KB TCM
    ,parameter TIMEOUT_CYCLES = 2_500_000      // 100 ms at 25 MHz
)
(
     input            clk_i
    ,input            rst_i

    // Received bytes (from uart_rx)
    ,input  [7:0]     rx_data_i
    ,input            rx_valid_i

    // Reset control
    ,output           sys_rst_o     // short pulse: reset core + memory interfaces
    ,output           cpu_hold_o    // hold the CPU in reset while loading

    // AXI4 write master -> TCM slave port (axi_t_*)
    ,output           axi_awvalid_o
    ,output [31:0]    axi_awaddr_o
    ,output           axi_wvalid_o
    ,output [31:0]    axi_wdata_o
    ,input            axi_awready_i
    ,input            axi_wready_i
    ,input            axi_bvalid_i
);

localparam STATE_IDLE   = 3'd0;
localparam STATE_RESET  = 3'd1;
localparam STATE_RECV   = 3'd2;
localparam STATE_WRITE  = 3'd3;
localparam STATE_RESP   = 3'd4;

localparam SYNC_WORD    = 32'h52564C44;   // "RVLD" in arrival order
localparam RESET_CYCLES = 4'd15;

reg [2:0]  state_q;
reg [31:0] sync_q;          // last 4 bytes seen while idle
reg [3:0]  rst_cnt_q;
reg [31:0] word_q;          // word being assembled (little-endian)
reg [1:0]  byte_cnt_q;
reg [13:0] word_idx_q;      // 0 .. WORDS-1
reg [31:0] timeout_q;
reg        aw_done_q;
reg        w_done_q;

wire last_word_w = (word_idx_q == WORDS - 1);

always @(posedge clk_i)
begin
    if (rst_i)
    begin
        state_q    <= STATE_IDLE;
        sync_q     <= 32'b0;
        rst_cnt_q  <= 4'd0;
        word_q     <= 32'b0;
        byte_cnt_q <= 2'd0;
        word_idx_q <= 14'd0;
        timeout_q  <= 32'd0;
        aw_done_q  <= 1'b0;
        w_done_q   <= 1'b0;
    end
    else
    begin
        case (state_q)

        // Look for the sync marker in the incoming byte stream
        STATE_IDLE:
        begin
            if (rx_valid_i)
            begin
                sync_q <= {sync_q[23:0], rx_data_i};
                if ({sync_q[23:0], rx_data_i} == SYNC_WORD)
                begin
                    sync_q    <= 32'b0;
                    rst_cnt_q <= 4'd0;
                    state_q   <= STATE_RESET;
                end
            end
        end

        // Reset the core and its memory interfaces before touching the TCM
        STATE_RESET:
        begin
            rst_cnt_q <= rst_cnt_q + 4'd1;
            if (rst_cnt_q == RESET_CYCLES)
            begin
                byte_cnt_q <= 2'd0;
                word_idx_q <= 14'd0;
                timeout_q  <= 32'd0;
                state_q    <= STATE_RECV;
            end
        end

        // Assemble 4 bytes into a word (first byte -> bits [7:0])
        STATE_RECV:
        begin
            if (rx_valid_i)
            begin
                timeout_q  <= 32'd0;
                word_q     <= {rx_data_i, word_q[31:8]};
                byte_cnt_q <= byte_cnt_q + 2'd1;
                if (byte_cnt_q == 2'd3)
                begin
                    aw_done_q <= 1'b0;
                    w_done_q  <= 1'b0;
                    state_q   <= STATE_WRITE;
                end
            end
            else if (timeout_q == TIMEOUT_CYCLES - 1)
                state_q   <= STATE_IDLE;     // transfer stalled - give up
            else
                timeout_q <= timeout_q + 32'd1;
        end

        // Single-beat write: hold address and data valid until both accepted
        STATE_WRITE:
        begin
            if (axi_awvalid_o && axi_awready_i)
                aw_done_q <= 1'b1;
            if (axi_wvalid_o && axi_wready_i)
                w_done_q  <= 1'b1;
            if ((aw_done_q || axi_awready_i) && (w_done_q || axi_wready_i))
                state_q <= STATE_RESP;
        end

        // Wait for the write response, then next word or finish
        STATE_RESP:
        begin
            if (axi_bvalid_i)
            begin
                if (last_word_w)
                    state_q    <= STATE_IDLE;  // done - CPU released
                else
                begin
                    word_idx_q <= word_idx_q + 14'd1;
                    state_q    <= STATE_RECV;
                end
            end
        end

        default: state_q <= STATE_IDLE;

        endcase
    end
end

assign sys_rst_o     = (state_q == STATE_RESET);
assign cpu_hold_o    = (state_q != STATE_IDLE);

assign axi_awvalid_o = (state_q == STATE_WRITE) && !aw_done_q;
assign axi_awaddr_o  = {16'b0, word_idx_q, 2'b00};
assign axi_wvalid_o  = (state_q == STATE_WRITE) && !w_done_q;
assign axi_wdata_o   = word_q;

endmodule
