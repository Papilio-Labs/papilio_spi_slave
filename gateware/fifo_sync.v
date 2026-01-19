// =============================================================================
// Synchronous FIFO with Block RAM Inference
// Part of papilio_hdl_blocks library
// =============================================================================
// 
// A parameterized synchronous FIFO designed for efficient block RAM usage on
// FPGAs. Features separate read and write interfaces with ready/valid handshaking
// compatible with the spi_slave module.
//
// Features:
// - Parameterized data width and depth
// - Block RAM inference for efficient resource usage
// - Ready/valid handshaking on both interfaces
// - Full/empty flags
// - Nearly-full/nearly-empty flags with programmable thresholds
// - Optional count output
//
// Parameters:
// - DATA_WIDTH: Width of each FIFO entry (default: 8)
// - DEPTH: Number of entries in FIFO (default: 256, must be power of 2)
// - ALMOST_FULL_THRESHOLD: Entries remaining before almost_full asserts
// - ALMOST_EMPTY_THRESHOLD: Entries remaining before almost_empty asserts
//
// =============================================================================

module fifo_sync #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 256,
    parameter ALMOST_FULL_THRESHOLD = 4,
    parameter ALMOST_EMPTY_THRESHOLD = 4,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    input wire clk,
    input wire rst_n,
    
    // Write Interface
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_valid,
    output wire wr_ready,
    
    // Read Interface
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire rd_valid,
    input wire rd_ready,
    
    // Status Flags
    output wire full,
    output wire empty,
    output wire almost_full,
    output wire almost_empty,
    output wire [ADDR_WIDTH:0] count
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    
    // Memory array - should infer block RAM
    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];
    
    // Read and write pointers
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;
    
    // Internal registered outputs
    reg [DATA_WIDTH-1:0] rd_data_reg;
    reg rd_valid_reg;
    
    // =========================================================================
    // Pointer Management
    // =========================================================================
    
    // Calculate next pointers
    wire [ADDR_WIDTH:0] wr_ptr_next = wr_ptr + 1'b1;
    wire [ADDR_WIDTH:0] rd_ptr_next = rd_ptr + 1'b1;
    
    // FIFO count (entries currently stored)
    wire [ADDR_WIDTH:0] fifo_count = wr_ptr - rd_ptr;
    
    // =========================================================================
    // Status Flags
    // =========================================================================
    
    assign empty = (wr_ptr == rd_ptr);
    assign full = (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]) && 
                  (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]);
    
    assign almost_empty = (fifo_count <= ALMOST_EMPTY_THRESHOLD);
    assign almost_full = (fifo_count >= (DEPTH - ALMOST_FULL_THRESHOLD));
    
    assign count = fifo_count;
    
    // =========================================================================
    // Write Interface Logic
    // =========================================================================
    
    assign wr_ready = !full;
    
    wire wr_enable = wr_valid && wr_ready;
    
    // Separate memory write for block RAM inference
    always @(posedge clk) begin
        if (wr_enable) begin
            memory[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end
    
    // Pointer update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end else if (wr_enable) begin
            wr_ptr <= wr_ptr_next;
        end
    end
    
    // =========================================================================
    // Read Interface Logic
    // =========================================================================
    
    assign rd_valid = rd_valid_reg;
    assign rd_data = rd_data_reg;
    
    wire rd_enable = rd_ready && rd_valid;
    wire rd_fetch = !empty && (!rd_valid || rd_enable);
    
    // Synchronous read for block RAM inference
    always @(posedge clk) begin
        if (rd_fetch) begin
            rd_data_reg <= memory[rd_ptr[ADDR_WIDTH-1:0]];
        end
    end
    
    // Control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= {(ADDR_WIDTH+1){1'b0}};
            rd_valid_reg <= 1'b0;
        end else begin
            // Handle data consumption
            if (rd_enable) begin
                rd_valid_reg <= 1'b0;
            end
            
            // Fetch new data if available and needed
            if (rd_fetch) begin
                rd_valid_reg <= 1'b1;
                rd_ptr <= rd_ptr_next;
            end
        end
    end

endmodule
