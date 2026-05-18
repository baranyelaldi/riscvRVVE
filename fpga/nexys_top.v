// Nexys A7 100T top-level wrapper for riscv_tcm_top.
//
// - TCM load port (axi_t_*) is tied off — program is pre-loaded into BRAM
//   at synthesis time via $readmemh in tcm_mem_ram.v.
// - Peripheral port (axi_i_*) is connected to a UART TX at 0x8000_0000,
//   matching the sim_putc convention used by assembly tests.
// - CPU stalls on UART writes when the transmitter is busy (no byte is dropped).
module nexys_top
(
     input  clk       // 100 MHz, pin E3
    ,input  rst_n     // active-low CPU reset button, pin C2
    ,output uart_tx   // USB-UART TX to PC, pin D4
);

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

always @(posedge clk)
begin
    if (~rst_n)
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

        // Handshake cycle — ready signals are high, UART has been kicked.
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
riscv_tcm_top u_core
(
     .clk_i     (clk)
    ,.rst_i     (~rst_n)
    ,.rst_cpu_i (~rst_n)

    // TCM load port — tied off, BRAM is pre-initialised at synthesis
    ,.axi_t_awvalid_i (1'b0)
    ,.axi_t_awaddr_i  (32'b0)
    ,.axi_t_awid_i    (4'b0)
    ,.axi_t_awlen_i   (8'b0)
    ,.axi_t_awburst_i (2'b0)
    ,.axi_t_wvalid_i  (1'b0)
    ,.axi_t_wdata_i   (32'b0)
    ,.axi_t_wstrb_i   (4'b0)
    ,.axi_t_wlast_i   (1'b0)
    ,.axi_t_bready_i  (1'b1)
    ,.axi_t_arvalid_i (1'b0)
    ,.axi_t_araddr_i  (32'b0)
    ,.axi_t_arid_i    (4'b0)
    ,.axi_t_arlen_i   (8'b0)
    ,.axi_t_arburst_i (2'b0)
    ,.axi_t_rready_i  (1'b1)

    // Peripheral AXI4-Lite master port — connected to UART handshake above
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
     .CLK_FREQ  (100_000_000)
    ,.BAUD_RATE (115_200)
)
u_uart
(
     .clk_i   (clk)
    ,.rst_i   (~rst_n)
    ,.data_i  (uart_data_q)
    ,.valid_i (uart_valid_q)
    ,.ready_o (uart_ready)
    ,.tx_o    (uart_tx)
);

endmodule
