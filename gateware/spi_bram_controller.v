// SPI BRAM Controller with Auto-Increment Protocol
//
// Provides memory interface for SPI slave with auto-incrementing address.
// Designed for use with spi_slave or spi_slave_fifo modules.
//
// Protocol:
//   - Each data byte written advances address by 1
//   - Special commands:
//     * 0xFF: Reset address to 0 without writing
//     * 0xFE: Switch to READ mode (stop writing)
//   - Normal operation: write bytes sequentially, read them back
//
// Features:
//   - Configurable memory depth and data width
//   - Auto-increment addressing
//   - Read/write mode switching
//   - BRAM-inferred storage (synchronous read for efficient resource usage)
//
// Integration:
//   Connect rx_data/valid/ready to SPI slave's RX FIFO interface
//   Connect tx_data/valid/ready to SPI slave's TX FIFO interface
//
// Author: Generated for Papilio SPI Slave Library
// Date: January 4, 2026

module spi_bram_controller #(
    parameter DATA_WIDTH = 8,       // Data width (8, 16, or 32)
    parameter MEM_DEPTH = 256,      // Memory depth (number of entries)
    parameter ADDR_WIDTH = $clog2(MEM_DEPTH)
)(
    input wire clk,
    input wire rst,
    
    // Interface from SPI slave (RX path)
    input wire [DATA_WIDTH-1:0] rx_data,
    input wire rx_valid,
    output wire rx_ready,
    
    // Interface to SPI slave (TX path)
    output wire [DATA_WIDTH-1:0] tx_data,
    output wire tx_valid,
    input wire tx_ready
);

    // =========================================================================
    // Block RAM - Should infer to BRAM primitives
    // =========================================================================
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    
    // Initialize memory for simulation (synthesis tools will ignore this)
    integer init_i;
    initial begin
        for (init_i = 0; init_i < MEM_DEPTH; init_i = init_i + 1) begin
            memory[init_i] = 0;
        end
    end
    
    // =========================================================================
    // Address and Mode Control
    // =========================================================================
    reg [ADDR_WIDTH-1:0] address;
    reg read_mode;  // 1 = read only, 0 = write
    
    always @(posedge clk) begin
        if (rst) begin
            address <= 0;
            read_mode <= 0;
        end else if (rx_valid && rx_ready) begin
            if (rx_data == 8'hFF) begin
                // 0xFF: Reset address without writing
                address <= 0;
            end else if (rx_data == 8'hFE) begin
                // 0xFE: Enter read mode (don't increment for command byte)
                read_mode <= 1;
            end else begin
                // Normal data byte: increment address AFTER write
                // (write happens in same cycle, uses current address)
                address <= address + 1;
            end
        end
    end
    
    // =========================================================================
    // BRAM Write Logic (synchronous for proper inference)
    // =========================================================================
    // Write uses CURRENT address before increment
    always @(posedge clk) begin
        // Write happens when rx_valid and rx_ready and not in read mode
        // Don't write command bytes (0xFF, 0xFE)
        if (rx_valid && rx_ready && rx_data != 8'hFF && rx_data != 8'hFE && !read_mode) begin
            memory[address] <= rx_data;
        end
    end
    
    // =========================================================================
    // BRAM Read Logic (SYNCHRONOUS for proper BRAM inference)
    // =========================================================================
    // Synchronous read allows synthesis to use actual BRAM primitives
    // instead of LUTs, preventing resource exhaustion
    reg [DATA_WIDTH-1:0] read_data_reg;
    always @(posedge clk) begin
        read_data_reg <= memory[address];
    end
    
    // =========================================================================
    // Output Assignments
    // =========================================================================
    assign tx_data = read_data_reg;
    assign tx_valid = 1'b1;      // Always have data to send
    assign rx_ready = 1'b1;      // Always ready to accept data

endmodule
