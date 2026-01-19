// Loopback Test - FPGA Top Module
// Simple loopback: RX data is immediately echoed to TX
// Part of Papilio SPI Slave Library

module top (
    input wire clk,           // 27MHz system clock
    
    // SPI Interface
    input wire spi_sclk,
    input wire spi_mosi,
    output wire spi_miso,
    input wire spi_cs_n
);

    // Reset generation
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
    
    // Configuration
    localparam TRANSFER_WIDTH = 8;  // 8, 16, or 32 bits
    localparam RX_FIFO_DEPTH = 256;
    localparam TX_FIFO_DEPTH = 256;
    
    // SPI Slave signals
    wire [TRANSFER_WIDTH-1:0] rx_data, tx_data;
    wire rx_valid, rx_ready, tx_valid, tx_ready;
    
    // Instantiate SPI slave with FIFO
    spi_slave_fifo #(
        .TRANSFER_WIDTH(TRANSFER_WIDTH),
        .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
        .TX_FIFO_DEPTH(TX_FIFO_DEPTH)
    ) spi_inst (
        .clk(clk),
        .rst_n(!rst),  // spi_slave_fifo uses active-low reset
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        .rx_fifo_data(rx_data),
        .rx_fifo_valid(rx_valid),
        .rx_fifo_ready(rx_ready),
        .rx_fifo_empty(),
        .rx_fifo_almost_full(),
        .rx_fifo_count(),
        .tx_fifo_data(tx_data),
        .tx_fifo_valid(tx_valid),
        .tx_fifo_ready(tx_ready),
        .tx_fifo_full(),
        .tx_fifo_almost_empty(),
        .tx_fifo_count()
    );
    
    // Simple loopback with register
    reg [TRANSFER_WIDTH-1:0] loopback_reg;
    
    always @(posedge clk) begin
        if (rst) begin
            loopback_reg <= 0;
        end else if (rx_valid && rx_ready) begin
            loopback_reg <= rx_data;
        end
    end
    
    assign tx_data = loopback_reg;
    assign tx_valid = 1'b1;
    assign rx_ready = 1'b1;

endmodule
