// 8N1 UART receiver.
// valid_o pulses for one cycle when a byte with a correct stop bit has been
// received; data_o holds that byte until the next one arrives.
// Receives LSB first (standard UART bit order).
module uart_rx
#(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)
(
     input            clk_i
    ,input            rst_i
    ,input            rx_i      // asynchronous serial input (idle high)
    ,output reg [7:0] data_o
    ,output reg       valid_o   // one-cycle pulse per received byte
    ,output reg       error_o   // one-cycle pulse on a framing error (stop bit low)
);

localparam DIVISOR      = CLK_FREQ / BAUD_RATE;  // 217 at 25 MHz / 115200
localparam HALF_DIVISOR = DIVISOR / 2;

localparam STATE_IDLE  = 2'd0;
localparam STATE_START = 2'd1;
localparam STATE_DATA  = 2'd2;
localparam STATE_STOP  = 2'd3;

// -----------------------------------------------------------------------
// Synchronise the asynchronous input (2 flops, reset to idle-high)
// -----------------------------------------------------------------------
(* ASYNC_REG = "TRUE" *) reg rx_meta_q;
(* ASYNC_REG = "TRUE" *) reg rx_sync_q;

always @(posedge clk_i)
begin
    if (rst_i)
    begin
        rx_meta_q <= 1'b1;
        rx_sync_q <= 1'b1;
    end
    else
    begin
        rx_meta_q <= rx_i;
        rx_sync_q <= rx_meta_q;
    end
end

// -----------------------------------------------------------------------
// Receive state machine - every bit is sampled in the middle of its period
// -----------------------------------------------------------------------
reg [1:0]  state_q;
reg [19:0] baud_cnt_q;
reg [2:0]  bit_cnt_q;
reg [7:0]  shift_q;

always @(posedge clk_i)
begin
    if (rst_i)
    begin
        state_q    <= STATE_IDLE;
        baud_cnt_q <= 20'd0;
        bit_cnt_q  <= 3'd0;
        shift_q    <= 8'h00;
        data_o     <= 8'h00;
        valid_o    <= 1'b0;
        error_o    <= 1'b0;
    end
    else
    begin
        valid_o <= 1'b0;   // default: one-cycle pulses only
        error_o <= 1'b0;

        case (state_q)

        // Wait for the falling edge of a start bit
        STATE_IDLE:
        begin
            baud_cnt_q <= 20'd0;
            if (!rx_sync_q)
                state_q <= STATE_START;
        end

        // Move to the middle of the start bit and confirm it is still low
        // (rejects glitches shorter than half a bit)
        STATE_START:
        begin
            if (baud_cnt_q == HALF_DIVISOR - 1)
            begin
                baud_cnt_q <= 20'd0;
                bit_cnt_q  <= 3'd0;
                state_q    <= rx_sync_q ? STATE_IDLE : STATE_DATA;
            end
            else
                baud_cnt_q <= baud_cnt_q + 20'd1;
        end

        // Sample 8 data bits, one full bit period apart, LSB first
        STATE_DATA:
        begin
            if (baud_cnt_q == DIVISOR - 1)
            begin
                baud_cnt_q <= 20'd0;
                shift_q    <= {rx_sync_q, shift_q[7:1]};
                if (bit_cnt_q == 3'd7)
                    state_q <= STATE_STOP;
                else
                    bit_cnt_q <= bit_cnt_q + 3'd1;
            end
            else
                baud_cnt_q <= baud_cnt_q + 20'd1;
        end

        // Sample the stop bit: high -> byte is valid, low -> framing error
        STATE_STOP:
        begin
            if (baud_cnt_q == DIVISOR - 1)
            begin
                baud_cnt_q <= 20'd0;
                state_q    <= STATE_IDLE;
                if (rx_sync_q)
                begin
                    data_o  <= shift_q;
                    valid_o <= 1'b1;
                end
                else
                    error_o <= 1'b1;
            end
            else
                baud_cnt_q <= baud_cnt_q + 20'd1;
        end

        default: state_q <= STATE_IDLE;

        endcase
    end
end

endmodule
