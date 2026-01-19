// BRAM Interface Example - FPGA Top Module
// Demonstrates SPI slave with Block RAM (BRAM) memory access
//
// Protocol:
//   - 0xFF: Reset address to 0 (write mode)
//   - 0xFE: Enter read mode
//   - Other bytes: Write to current address (auto-increment) or read in read mode
//
// Hardware: Gowin FPGA with 256-byte BRAM
// Test: ESP32 writes data, reads back, verifies

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
    localparam RX_FIFO_DEPTH = 256;
    localparam TX_FIFO_DEPTH = 256;
    localparam MEM_DEPTH = 256;      // 256 bytes of BRAM
    localparam ADDR_WIDTH = 8;       // 8-bit address for 256 bytes
    
    // SPI Slave signals
    wire [7:0] rx_fifo_data;
    wire rx_fifo_valid;
    wire rx_fifo_ready;
    wire [7:0] tx_fifo_data;
    wire tx_fifo_valid;
    wire tx_fifo_ready;
    
    // SPI Slave with FIFO
    spi_slave_fifo #(
        .TRANSFER_WIDTH(8),
        .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
        .TX_FIFO_DEPTH(TX_FIFO_DEPTH)
    ) spi_inst (
        .clk(clk),
        .rst_n(!rst),
        
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs_n(spi_cs_n),
        
        .rx_fifo_data(rx_fifo_data),
        .rx_fifo_valid(rx_fifo_valid),
        .rx_fifo_ready(rx_fifo_ready),
        
        .tx_fifo_data(tx_fifo_data),
        .tx_fifo_valid(tx_fifo_valid),
        .tx_fifo_ready(tx_fifo_ready)
    );
    
    // BRAM with auto-increment protocol
    reg [7:0] memory [0:MEM_DEPTH-1];
    reg [ADDR_WIDTH-1:0] address;
    reg read_mode;
    
    // Initialize memory
    integer init_i;
    initial begin
        for (init_i = 0; init_i < MEM_DEPTH; init_i = init_i + 1) begin
            memory[init_i] = 0;
        end
    end
    
    // Address and mode control
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            address <= 0;
            read_mode <= 0;
        end else if (rx_fifo_valid && rx_fifo_ready) begin
            if (rx_fifo_data == 8'hFF) begin
                // 0xFF: Reset address to 0 (enter write mode)
                address <= 0;
                read_mode <= 0;
            end else if (rx_fifo_data == 8'hFE) begin
                // 0xFE: Enter read mode, reset address
                read_mode <= 1;
                address <= 0;
            end else begin
                // Normal data: increment address after access
                address <= address + 1;
            end
        end
    end
    
    // BRAM write (synchronous for proper inference)
    always @(posedge clk) begin
        if (rx_fifo_valid && rx_fifo_ready && 
            rx_fifo_data != 8'hFF && rx_fifo_data != 8'hFE && !read_mode) begin
            memory[address] <= rx_fifo_data;
        end
    end
    
    // BRAM read (synchronous, 1-cycle latency for BRAM primitive inference)
    reg [7:0] read_data_reg;
    always @(posedge clk) begin
        read_data_reg <= memory[address];
    end
    
    // Connect FIFO interface
    assign tx_fifo_data = read_data_reg;
    assign tx_fifo_valid = 1'b1;      // Always have data ready
    assign rx_fifo_ready = 1'b1;      // Always ready to accept
    
endmodule
