// =============================================================================
// SPI Slave with Integrated FIFOs
// Part of papilio_hdl_blocks library
// =============================================================================
//
// Combines the spi_slave module with synchronous FIFOs for both RX and TX
// directions, providing a DMA-ready interface for efficient data transfer.
//
// Features:
// - Automatic data flow between SPI and FIFOs
// - Separate RX and TX FIFOs for full-duplex operation
// - Configurable FIFO depths
// - Ready/valid interfaces for easy integration with DMA or Wishbone
// - Status flags for monitoring FIFO levels
//
// Use Cases:
// - High-speed SPI data acquisition
// - DMA-based SPI transfers
// - Buffered Wishbone-to-SPI bridge
// - Burst SPI transactions
//
// =============================================================================

module spi_slave_fifo #(
    parameter TRANSFER_WIDTH = 8,      // SPI transfer width (8, 16, or 32)
    parameter RX_FIFO_DEPTH = 256,     // RX FIFO depth (power of 2)
    parameter TX_FIFO_DEPTH = 256      // TX FIFO depth (power of 2)
) (
    // System Interface
    input wire clk,                    // System clock
    input wire rst_n,                  // Active-low reset
    
    // SPI Interface (connect to physical pins)
    input wire spi_sclk,               // SPI clock from master
    input wire spi_mosi,               // SPI MOSI from master
    output wire spi_miso,              // SPI MISO to master
    input wire spi_cs_n,               // SPI chip select (active low)
    
    // RX FIFO Interface (for reading received data)
    output wire [TRANSFER_WIDTH-1:0] rx_fifo_data,
    output wire rx_fifo_valid,
    input wire rx_fifo_ready,
    output wire rx_fifo_empty,
    output wire rx_fifo_almost_full,
    output wire [$clog2(RX_FIFO_DEPTH):0] rx_fifo_count,
    
    // TX FIFO Interface (for writing data to transmit)
    input wire [TRANSFER_WIDTH-1:0] tx_fifo_data,
    input wire tx_fifo_valid,
    output wire tx_fifo_ready,
    output wire tx_fifo_full,
    output wire tx_fifo_almost_empty,
    output wire [$clog2(TX_FIFO_DEPTH):0] tx_fifo_count
);

    // =========================================================================
    // SPI Slave Instance
    // =========================================================================
    
    wire [TRANSFER_WIDTH-1:0] spi_rx_data;
    wire spi_rx_valid;
    wire spi_rx_ready;
    
    wire [TRANSFER_WIDTH-1:0] spi_tx_data;
    wire spi_tx_valid;
    wire spi_tx_ready;
    
    spi_slave #(
        .TRANSFER_WIDTH(TRANSFER_WIDTH)
    ) spi_inst (
        .clk(clk),
        .rst(!rst_n),  // spi_slave uses active-high reset
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .rx_data(spi_rx_data),
        .rx_valid(spi_rx_valid),
        .rx_ready(spi_rx_ready),
        .tx_data(spi_tx_data),
        .tx_valid(spi_tx_valid),
        .tx_ready(spi_tx_ready)
    );
    
    // =========================================================================
    // RX FIFO Instance (SPI → Application)
    // =========================================================================
    
    wire rx_fifo_full;
    
    fifo_sync #(
        .DATA_WIDTH(TRANSFER_WIDTH),
        .DEPTH(RX_FIFO_DEPTH),
        .ALMOST_FULL_THRESHOLD(16),
        .ALMOST_EMPTY_THRESHOLD(4)
    ) rx_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        // Write side (from SPI)
        .wr_data(spi_rx_data),
        .wr_valid(spi_rx_valid),
        .wr_ready(spi_rx_ready),
        // Read side (to application)
        .rd_data(rx_fifo_data),
        .rd_valid(rx_fifo_valid),
        .rd_ready(rx_fifo_ready),
        // Status
        .full(rx_fifo_full),
        .empty(rx_fifo_empty),
        .almost_full(rx_fifo_almost_full),
        .almost_empty(),  // Not used
        .count(rx_fifo_count)
    );
    
    // =========================================================================
    // TX FIFO Instance (Application → SPI)
    // =========================================================================
    
    wire tx_fifo_empty;
    
    fifo_sync #(
        .DATA_WIDTH(TRANSFER_WIDTH),
        .DEPTH(TX_FIFO_DEPTH),
        .ALMOST_FULL_THRESHOLD(16),
        .ALMOST_EMPTY_THRESHOLD(4)
    ) tx_fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        // Write side (from application)
        .wr_data(tx_fifo_data),
        .wr_valid(tx_fifo_valid),
        .wr_ready(tx_fifo_ready),
        // Read side (to SPI)
        .rd_data(spi_tx_data),
        .rd_valid(spi_tx_valid),
        .rd_ready(spi_tx_ready),
        // Status
        .full(tx_fifo_full),
        .empty(tx_fifo_empty),
        .almost_full(),  // Not used
        .almost_empty(tx_fifo_almost_empty),
        .count(tx_fifo_count)
    );

endmodule
