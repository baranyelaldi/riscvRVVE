// Nexys A7 100T top-level wrapper for riscv_tcm_top.
//
// - Program loading: the BRAM is pre-loaded at synthesis time via $readmemh in
//   tcm_mem_ram.v (default program). A new program can be loaded at run time
//   over the UART with tools/load.py: uart_rx -> uart_loader -> TCM load port
//   (axi_t_*), with the CPU held in reset during the transfer.
// - Peripheral port (axi_i_*) is connected to a UART TX at 0x8000_0000,
//   matching the sim_putc convention used by assembly tests.
// - CPU stalls on UART writes when the transmitter is busy (no byte is dropped).
module nexys_top
#(
     // UART settings shared by TX and RX (clk_50 actually runs at 25 MHz, see clk_wiz_0)
     parameter UART_CLK_FREQ  = 25_000_000
    ,parameter UART_BAUD_RATE = 115_200
)
(
     input  clk       // 100 MHz, pin E3
    ,input  rst_n     // active-low CPU reset button, pin C2
    ,output uart_tx   // USB-UART TX to PC, pin D4
    ,input  uart_rx   // USB-UART RX from PC, pin C4
);

wire clk_50;
wire locked;

clk_wiz_0 u_clk
(
     .clk_in1  (clk)      // 100 MHz from pin E3

    ,.clk_out1 (clk_50)   // 50 MHz to CPU
    ,.locked   (locked)   // high when clock is stable
);

// -----------------------------------------------------------------------
// Resets
//   rst_board : button or clock not locked - resets everything incl. loader
//   rst_int   : core + memory/peripheral interfaces (also pulsed by loader)
//   rst_cpu   : CPU only (also held by the loader during a transfer)
// -----------------------------------------------------------------------
wire loader_sys_rst;
wire loader_cpu_hold;

wire rst_board = (~rst_n) | (~locked);
wire rst_int   = rst_board | loader_sys_rst;
wire rst_cpu   = rst_int   | loader_cpu_hold;

// -----------------------------------------------------------------------
// Wires from riscv_tcm_top peripheral master port
// -----------------------------------------------------------------------
wire        axi_i_awvalid;
wire [31:0] axi_i_awaddr;
wire        axi_i_wvalid;
wire [31:0] axi_i_wdata;
wire        axi_i_bready;   // CPU signals it can accept a write response

// -----------------------------------------------------------------------
// AXI4-Lite slave handshake state machine
//
// States:
//   IDLE : waiting for the CPU to present both awvalid and wvalid,
//          and for the UART to be ready to accept a new byte.
//   ACC  : awready + wready asserted for one cycle (handshake cycle).
//          UART valid pulse issued in this same cycle.
//   RESP : bvalid held until CPU asserts bready.
// -----------------------------------------------------------------------
localparam AXI_IDLE = 2'd0;
localparam AXI_ACC  = 2'd1;
localparam AXI_RESP = 2'd2;

reg [1:0]  axi_state_q;
reg        axi_awready_q;
reg        axi_wready_q;
reg        axi_bvalid_q;

wire       uart_ready;
reg        uart_valid_q;
reg [7:0]  uart_data_q;

always @(posedge clk_50)
begin
    if (rst_int)
    begin
        axi_state_q  <= AXI_IDLE;
        axi_awready_q <= 1'b0;
        axi_wready_q  <= 1'b0;
        axi_bvalid_q  <= 1'b0;
        uart_valid_q  <= 1'b0;
        uart_data_q   <= 8'h00;
    end
    else
    begin
        uart_valid_q <= 1'b0;   // default: one-cycle pulse only

        case (axi_state_q)

        // Wait for CPU to present a full write transaction and UART to be free.
        // Stalling here (not asserting ready) backpressures the CPU naturally.
        AXI_IDLE:
        begin
            if (axi_i_awvalid && axi_i_wvalid && uart_ready)
            begin
                axi_awready_q <= 1'b1;
                axi_wready_q  <= 1'b1;
                uart_data_q   <= axi_i_wdata[7:0];
                uart_valid_q  <= 1'b1;
                axi_state_q   <= AXI_ACC;
            end
        end

        // Handshake cycle - ready signals are high, UART has been kicked.
        // Drop readys and raise bvalid for the response phase.
        AXI_ACC:
        begin
            axi_awready_q <= 1'b0;
            axi_wready_q  <= 1'b0;
            axi_bvalid_q  <= 1'b1;
            axi_state_q   <= AXI_RESP;
        end

        // Hold bvalid until the CPU accepts the response.
        AXI_RESP:
        begin
            if (axi_i_bready)
            begin
                axi_bvalid_q <= 1'b0;
                axi_state_q  <= AXI_IDLE;
            end
        end

        default: axi_state_q <= AXI_IDLE;

        endcase
    end
end

// -----------------------------------------------------------------------
// riscv_tcm_top instance
// -----------------------------------------------------------------------
wire        axi_t_awvalid;
wire [31:0] axi_t_awaddr;
wire        axi_t_wvalid;
wire [31:0] axi_t_wdata;
wire        axi_t_awready;
wire        axi_t_wready;
wire        axi_t_bvalid;

riscv_tcm_top u_core
(
     .clk_i     (clk_50)
    ,.rst_i     (rst_int)
    ,.rst_cpu_i (rst_cpu)

    // TCM load port - single-beat writes from the UART loader (no reads)
    ,.axi_t_awvalid_i (axi_t_awvalid)
    ,.axi_t_awaddr_i  (axi_t_awaddr)
    ,.axi_t_awid_i    (4'b0)
    ,.axi_t_awlen_i   (8'b0)        // 1 beat per burst
    ,.axi_t_awburst_i (2'b01)       // INCR
    ,.axi_t_wvalid_i  (axi_t_wvalid)
    ,.axi_t_wdata_i   (axi_t_wdata)
    ,.axi_t_wstrb_i   (4'b1111)
    ,.axi_t_wlast_i   (1'b1)
    ,.axi_t_bready_i  (1'b1)
    ,.axi_t_awready_o (axi_t_awready)
    ,.axi_t_wready_o  (axi_t_wready)
    ,.axi_t_bvalid_o  (axi_t_bvalid)
    ,.axi_t_arvalid_i (1'b0)
    ,.axi_t_araddr_i  (32'b0)
    ,.axi_t_arid_i    (4'b0)
    ,.axi_t_arlen_i   (8'b0)
    ,.axi_t_arburst_i (2'b0)
    ,.axi_t_rready_i  (1'b1)

    // Peripheral AXI4-Lite master port - connected to UART handshake above
    ,.axi_i_awready_i (axi_awready_q)
    ,.axi_i_wready_i  (axi_wready_q)
    ,.axi_i_bvalid_i  (axi_bvalid_q)
    ,.axi_i_bresp_i   (2'b00)
    ,.axi_i_arready_i (1'b0)        // reads not supported
    ,.axi_i_rvalid_i  (1'b0)
    ,.axi_i_rdata_i   (32'b0)
    ,.axi_i_rresp_i   (2'b00)

    ,.axi_i_awvalid_o (axi_i_awvalid)
    ,.axi_i_awaddr_o  (axi_i_awaddr)
    ,.axi_i_wvalid_o  (axi_i_wvalid)
    ,.axi_i_wdata_o   (axi_i_wdata)
    ,.axi_i_bready_o  (axi_i_bready)

    ,.intr_i(32'b0)
);

// -----------------------------------------------------------------------
// UART TX instance
// -----------------------------------------------------------------------
uart_tx
#(
     .CLK_FREQ  (UART_CLK_FREQ)
    ,.BAUD_RATE (UART_BAUD_RATE)
)
u_uart
(
     .clk_i   (clk_50)
    ,.rst_i   (rst_int)
    ,.data_i  (uart_data_q)
    ,.valid_i (uart_valid_q)
    ,.ready_o (uart_ready)
    ,.tx_o    (uart_tx)
);

// -----------------------------------------------------------------------
// UART RX instance
// -----------------------------------------------------------------------
wire [7:0] uart_rx_data;
wire       uart_rx_valid;   // one-cycle pulse per received byte
wire       uart_rx_error;   // one-cycle pulse on a framing error

uart_rx
#(
     .CLK_FREQ  (UART_CLK_FREQ)
    ,.BAUD_RATE (UART_BAUD_RATE)
)
u_uart_rx
(
     .clk_i   (clk_50)
    ,.rst_i   (rst_board)
    ,.rx_i    (uart_rx)
    ,.data_o  (uart_rx_data)
    ,.valid_o (uart_rx_valid)
    ,.error_o (uart_rx_error)
);

// -----------------------------------------------------------------------
// UART program loader -> TCM load port
// -----------------------------------------------------------------------
uart_loader
#(
     .TIMEOUT_CYCLES (UART_CLK_FREQ / 10)   // 100 ms without a byte aborts a load
)
u_loader
(
     .clk_i         (clk_50)
    ,.rst_i         (rst_board)
    ,.rx_data_i     (uart_rx_data)
    ,.rx_valid_i    (uart_rx_valid)
    ,.sys_rst_o     (loader_sys_rst)
    ,.cpu_hold_o    (loader_cpu_hold)
    ,.axi_awvalid_o (axi_t_awvalid)
    ,.axi_awaddr_o  (axi_t_awaddr)
    ,.axi_wvalid_o  (axi_t_wvalid)
    ,.axi_wdata_o   (axi_t_wdata)
    ,.axi_awready_i (axi_t_awready)
    ,.axi_wready_i  (axi_t_wready)
    ,.axi_bvalid_i  (axi_t_bvalid)
);

endmodule
