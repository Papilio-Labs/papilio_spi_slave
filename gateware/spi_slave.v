// Generic SPI Slave Module with Variable Width Support
// 
// A protocol-agnostic SPI slave providing solid communication for any application.
// Supports 8, 16, or 32-bit transfers with ready/valid handshaking interface.
//
// Features:
// - Dual-register synchronization for clock domain crossing (industry standard)
// - Parameterized transfer width (8/16/32 bits)
// - SPI Mode 0 implementation (CPOL=0, CPHA=0)
// - Compatible with SPI Mode 1 master (due to full-duplex timing)
// - Separate RX and TX data paths
// - Ready/valid handshaking for external logic integration
// - CS-delimited transaction framing
//
// Interface:
// - RX: rx_data, rx_valid (strobed when word complete), rx_ready (backpressure)
// - TX: tx_data, tx_valid (load next word), tx_ready (module ready for data)
//
// Timing:
// - Sample MOSI on rising edge of SCLK (after synchronization)
// - Shift MISO on falling edge of SCLK to ensure stable data for master sampling
// - TX data must be loaded BEFORE CS goes active (during CS high time)
// - Maximum validated speed: 4MHz SPI clock with 27MHz system clock
// - Speed limit due to synchronization latency (~6.75 system cycles per SPI cycle at 4MHz)
//
// Note: Due to SPI full-duplex nature, works best with Mode 1 masters.
// Mode 1 masters shift on rising edge and sample on falling edge, which
// aligns perfectly with this slave's timing.
//
// Author: Generated for Papilio RetroCade Wishbone Bus Project
// Date: 2025-12-31

module spi_slave #(
    parameter TRANSFER_WIDTH = 8  // 8, 16, or 32 bits per transfer
)(
    // System clock and reset
    input wire clk,           // System clock (e.g., 27MHz)
    input wire rst,           // Active-high reset
    
    // SPI Interface (asynchronous to clk)
    input wire spi_sclk,      // SPI clock from master
    input wire spi_mosi,      // Master Out, Slave In
    output wire spi_miso,     // Master In, Slave Out
    input wire spi_cs_n,      // Chip select (active low)
    
    // Receive Interface (system clock domain)
    output reg [TRANSFER_WIDTH-1:0] rx_data,  // Received data word
    output reg rx_valid,                       // Pulse when rx_data valid
    input wire rx_ready,                       // Backpressure from application
    
    // Transmit Interface (system clock domain)
    input wire [TRANSFER_WIDTH-1:0] tx_data,  // Data to transmit
    input wire tx_valid,                       // Load tx_data when high
    output reg tx_ready                        // Module ready for new tx_data
);

    // =========================================================================
    // Parameter Validation
    // =========================================================================
    initial begin
        if (TRANSFER_WIDTH != 8 && TRANSFER_WIDTH != 16 && TRANSFER_WIDTH != 32) begin
            $error("TRANSFER_WIDTH must be 8, 16, or 32");
            $finish;
        end
    end
    
    // =========================================================================
    // Synchronize SPI signals to system clock (dual register for metastability)
    // Two stages is industry standard and sufficient for metastability resolution
    // For edge detection, we use a third register but keep the sync path short
    // =========================================================================
    reg spi_cs_n_d1, spi_cs_n_d2;
    reg spi_sclk_d1, spi_sclk_d2, spi_sclk_d3;
    reg spi_mosi_d1, spi_mosi_d2;
    
    always @(posedge clk) begin
        // First stage - may go metastable
        spi_cs_n_d1 <= spi_cs_n;
        spi_sclk_d1 <= spi_sclk;
        spi_mosi_d1 <= spi_mosi;
        
        // Second stage - metastability resolved
        spi_cs_n_d2 <= spi_cs_n_d1;
        spi_sclk_d2 <= spi_sclk_d1;
        spi_mosi_d2 <= spi_mosi_d1;
        
        // Third stage - for edge detection only
        spi_sclk_d3 <= spi_sclk_d2;
    end
    
    // Derived control signals
    wire spi_cs_active = !spi_cs_n_d2;
    wire spi_sclk_posedge = spi_sclk_d2 && !spi_sclk_d3;  // Rising edge detect
    wire spi_sclk_negedge = !spi_sclk_d2 && spi_sclk_d3;  // Falling edge detect
    
    // =========================================================================
    // Receive Path - Shift register and bit counter
    // =========================================================================
    reg [TRANSFER_WIDTH-1:0] rx_shift;  // Shift register for incoming bits
    reg [$clog2(TRANSFER_WIDTH):0] rx_bit_count;  // Bit counter (0 to TRANSFER_WIDTH)
    
    always @(posedge clk) begin
        if (rst) begin
            rx_shift <= 0;
            rx_bit_count <= 0;
            rx_data <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 0;  // Default: clear strobe
            
            if (!spi_cs_active) begin
                // CS inactive - reset for next transaction
                rx_bit_count <= 0;
                rx_shift <= 0;
            end else if (spi_sclk_posedge) begin
                // Sample MOSI on rising edge of SCLK
                rx_shift <= {rx_shift[TRANSFER_WIDTH-2:0], spi_mosi_d2};
                rx_bit_count <= rx_bit_count + 1;
                
                // Check if word is complete
                if (rx_bit_count == TRANSFER_WIDTH - 1) begin
                    // Word complete - output to application
                    rx_data <= {rx_shift[TRANSFER_WIDTH-2:0], spi_mosi_d2};
                    rx_valid <= rx_ready;  // Only assert valid if application ready
                    rx_bit_count <= 0;     // Reset for next word
                end
            end
        end
    end
    
    // =========================================================================
    // Transmit Path - Shift register and control
    // =========================================================================
    reg [TRANSFER_WIDTH-1:0] tx_shift;  // Shift register for outgoing bits
    reg [$clog2(TRANSFER_WIDTH):0] tx_bit_count;  // Bit counter
    reg tx_data_loaded;                 // Flag: tx_shift loaded with data
    reg first_bit_sent;                 // Flag: skip first falling edge after load
    
    // MISO output - drive MSB of shift register
    assign spi_miso = tx_shift[TRANSFER_WIDTH-1];
    
    always @(posedge clk) begin
        if (rst) begin
            tx_shift <= {TRANSFER_WIDTH{1'b1}};  // Default to all 1's
            tx_bit_count <= 0;
            tx_data_loaded <= 0;
            first_bit_sent <= 0;
            tx_ready <= 1;  // Ready for data initially
        end else begin
            if (!spi_cs_active) begin
                // CS inactive - prepare for next transaction
                // Reset ready flag so new data can be loaded
                if (!tx_ready) begin
                    tx_ready <= 1;
                end
                
                // Load new data if available
                if (tx_valid && tx_ready) begin
                    tx_shift <= tx_data;
                    tx_data_loaded <= 1;
                    tx_ready <= 0;
                end else if (!tx_data_loaded) begin
                    // No new data, preload with all 1's (idle state)
                    tx_shift <= {TRANSFER_WIDTH{1'b1}};
                end
                tx_bit_count <= 0;
                first_bit_sent <= 0;
            end else begin
                // CS active - transaction in progress
                // Shift out on falling edge of SCLK
                if (spi_sclk_negedge && tx_data_loaded) begin
                    if (!first_bit_sent) begin
                        // Skip first falling edge - MSB already output
                        first_bit_sent <= 1;
                    end else begin
                        // Shift left, new bit on LSB doesn't matter
                        tx_shift <= {tx_shift[TRANSFER_WIDTH-2:0], 1'b0};
                        tx_bit_count <= tx_bit_count + 1;
                        
                        // Check if word transmission complete
                        if (tx_bit_count == TRANSFER_WIDTH - 1) begin
                            tx_data_loaded <= 0;
                            tx_ready <= 1;  // Ready for next word
                            tx_bit_count <= 0;
                        end
                    end
                end
            end
        end
    end

endmodule
