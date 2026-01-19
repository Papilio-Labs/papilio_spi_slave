// Burst Transfer FPGA Top - Simple loopback with FIFO buffering
// Demonstrates high-throughput data transfers at 8/16/32-bit widths
//
// To change bit width, modify TRANSFER_WIDTH parameter below
// Valid values: 8, 16, or 32
//
// For video/audio applications:
//   - 16-bit: Common for audio samples (PCM), RGB565 pixels
//   - 32-bit: 24-bit RGB + alpha, floating point audio, high-res data

module top (
    input wire clk,
    
    // SPI slave interface
    input  wire spi_sclk,
    input  wire spi_mosi,
    output wire spi_miso,
    input  wire spi_cs_n
);

    // =========================================================================
    // Configuration - Change this to test different bit widths
    // =========================================================================
    localparam TRANSFER_WIDTH = 32;  // 8, 16, or 32 bits
    
    // =========================================================================
    // Reset generation
    // =========================================================================
    reg [3:0] reset_counter = 4'b0000;
    reg rst = 1'b1;
    
    always @(posedge clk) begin
        if (reset_counter != 4'b1111) begin
            reset_counter <= reset_counter + 1;
            rst <= 1'b1;
        end else begin
            rst <= 1'b0;
        end
    end
    
    wire rst_n = !rst;  // Active-low reset for spi_slave_fifo
    
    // =========================================================================
    // SPI Slave FIFO Instantiation
    // =========================================================================
    wire [TRANSFER_WIDTH-1:0] rx_fifo_data;
    wire                      rx_fifo_valid;
    wire                      rx_fifo_ready;
    wire [TRANSFER_WIDTH-1:0] tx_fifo_data;
    wire                      tx_fifo_valid;
    wire                      tx_fifo_ready;
    
    // SPI slave with FIFO interface
    spi_slave_fifo #(
        .TRANSFER_WIDTH(TRANSFER_WIDTH),
        .RX_FIFO_DEPTH(256),
        .TX_FIFO_DEPTH(256)
    ) spi_inst (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .rx_fifo_data(rx_fifo_data),
        .rx_fifo_valid(rx_fifo_valid),
        .rx_fifo_ready(rx_fifo_ready),
        .rx_fifo_empty(),
        .rx_fifo_almost_full(),
        .rx_fifo_count(),
        .tx_fifo_data(tx_fifo_data),
        .tx_fifo_valid(tx_fifo_valid),
        .tx_fifo_ready(tx_fifo_ready),
        .tx_fifo_full(),
        .tx_fifo_almost_empty(),
        .tx_fifo_count()
    );
    
    // =========================================================================
    // Loopback Logic - Works for any bit width
    // =========================================================================
    reg [TRANSFER_WIDTH-1:0] loopback_reg;
    
    always @(posedge clk) begin
        if (rst) begin
            loopback_reg <= {TRANSFER_WIDTH{1'b0}};
        end else if (rx_fifo_valid && rx_fifo_ready) begin
            loopback_reg <= rx_fifo_data;
        end
    end
    
    assign tx_fifo_data = loopback_reg;
    assign tx_fifo_valid = 1'b1;
    assign rx_fifo_ready = 1'b1;
    
endmodule















