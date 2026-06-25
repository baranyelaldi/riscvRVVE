// 8N1 UART transmitter.
// Stalls the sender via ready_o — valid_i must be held until ready_o is high.
// Transmits LSB first (standard UART bit order).
module uart_tx
#(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)
(
     input            clk_i
    ,input            rst_i
    ,input  [7:0]     data_i
    ,input            valid_i
    ,output           ready_o
    ,output reg       tx_o
);

localparam DIVISOR = CLK_FREQ / BAUD_RATE;  // 868 at 100 MHz / 115200

localparam STATE_IDLE  = 2'd0;
localparam STATE_START = 2'd1;
localparam STATE_DATA  = 2'd2;
localparam STATE_STOP  = 2'd3;

reg [1:0]  state_q;
reg [19:0] baud_cnt_q;
reg [2:0]  bit_cnt_q;
reg [7:0]  shift_q;

assign ready_o = (state_q == STATE_IDLE);

always @(posedge clk_i)
begin
    if (rst_i)
    begin
        state_q    <= STATE_IDLE;
        baud_cnt_q <= 20'd0;
        bit_cnt_q  <= 3'd0;
        shift_q    <= 8'h00;
        tx_o       <= 1'b1;
    end
    else
    begin
        case (state_q)

        STATE_IDLE:
        begin
            tx_o <= 1'b1;
            if (valid_i)
            begin
                shift_q    <= data_i;
                baud_cnt_q <= 20'd0;
                state_q    <= STATE_START;
            end
        end

        // Drive start bit (logic 0) for one full baud period
        STATE_START:
        begin
            tx_o <= 1'b0;
            if (baud_cnt_q == DIVISOR - 1)
            begin
                baud_cnt_q <= 20'd0;
                bit_cnt_q  <= 3'd0;
                state_q    <= STATE_DATA;
            end
            else
                baud_cnt_q <= baud_cnt_q + 20'd1;
        end

        // Shift out 8 data bits, LSB first
        STATE_DATA:
        begin
            tx_o <= shift_q[0];
            if (baud_cnt_q == DIVISOR - 1)
            begin
                baud_cnt_q <= 20'd0;
                shift_q    <= {1'b0, shift_q[7:1]};
                if (bit_cnt_q == 3'd7)
                    state_q <= STATE_STOP;
                else
                    bit_cnt_q <= bit_cnt_q + 3'd1;
            end
            else
                baud_cnt_q <= baud_cnt_q + 20'd1;
        end

        // Drive stop bit (logic 1) for one full baud period
        STATE_STOP:
        begin
            tx_o <= 1'b1;
            if (baud_cnt_q == DIVISOR - 1)
            begin
                baud_cnt_q <= 20'd0;
                state_q    <= STATE_IDLE;
            end
            else
                baud_cnt_q <= baud_cnt_q + 20'd1;
        end

        default: state_q <= STATE_IDLE;

        endcase
    end
end

endmodule
