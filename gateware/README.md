# Papilio SPI Slave - Gateware Modules

Hardware Description Language (Verilog) modules for SPI slave implementations.

## Core Modules

### spi_slave.v

Protocol engine providing the fundamental SPI slave functionality.

**Features:**
- Dual-register clock domain crossing (CDC) for metastability protection
- Parameterized transfer width: 8, 16, or 32 bits
- SPI Mode 0 implementation (CPOL=0, CPHA=0), compatible with Mode 1 masters
- Ready/valid handshaking interface for flow control
- Full-duplex operation with separate RX/TX paths
- CS-delimited transaction framing
- Maximum validated speed: 4 MHz (with 27 MHz system clock)

**Interface:**

```verilog
module spi_slave #(
    parameter TRANSFER_WIDTH = 8  // 8, 16, or 32 bits
)(
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
```

**Timing Requirements:**
- TX data must be loaded BEFORE CS goes active (during CS high time)
- Minimum system clock: 27 MHz for 4 MHz SPI operation
- Provides 6.75 system clock cycles per SPI edge at maximum speed
- Sample MOSI on rising edge, shift MISO on falling edge

### spi_slave_fifo.v

Enhanced SPI slave with integrated FIFO buffers for high-throughput applications.

**Features:**
- Integrates spi_slave with RX and TX FIFOs
- Configurable FIFO depths (default 256 entries each)
- Automatic data flow without manual handshaking
- DMA-ready interface with status flags
- Independent RX/TX buffering for full-duplex streaming
- FIFO count outputs for monitoring

**Interface:**

```verilog
module spi_slave_fifo #(
    parameter TRANSFER_WIDTH = 8,      // 8, 16, or 32 bits
    parameter RX_FIFO_DEPTH = 256,     // RX FIFO depth (power of 2)
    parameter TX_FIFO_DEPTH = 256      // TX FIFO depth (power of 2)
)(
    input wire clk,
    input wire rst_n,           // Active-low reset
    
    // SPI Interface
    input wire spi_sclk,
    input wire spi_mosi,
    output wire spi_miso,
    input wire spi_cs_n,
    
    // RX FIFO Interface (receive from SPI)
    output wire [TRANSFER_WIDTH-1:0] rx_fifo_data,
    output wire rx_fifo_valid,
    input wire rx_fifo_ready,
    output wire rx_fifo_empty,
    output wire rx_fifo_almost_full,
    output wire [$clog2(RX_FIFO_DEPTH):0] rx_fifo_count,
    
    // TX FIFO Interface (transmit to SPI)
    input wire [TRANSFER_WIDTH-1:0] tx_fifo_data,
    input wire tx_fifo_valid,
    output wire tx_fifo_ready,
    output wire tx_fifo_full,
    output wire tx_fifo_almost_empty,
    output wire [$clog2(TX_FIFO_DEPTH):0] tx_fifo_count
);
```

**Use Cases:**
- Logic analyzer data capture
- High-speed data streaming
- Burst transfer buffering
- DMA-based SPI transfers

### fifo_sync.v

Reusable synchronous FIFO primitive used by spi_slave_fifo.

**Features:**
- Parameterized data width and depth
- Block RAM inference for efficient resource usage
- Ready/valid handshaking on both read and write interfaces
- Full/empty/almost_full/almost_empty status flags
- Programmable threshold for almost flags
- Count output for fill level monitoring

**Interface:**

```verilog
module fifo_sync #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 256,
    parameter ALMOST_FULL_THRESHOLD = DEPTH - 16,
    parameter ALMOST_EMPTY_THRESHOLD = 16
)(
    input wire clk,
    input wire rst_n,
    
    // Write interface
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire wr_valid,
    output wire wr_ready,
    
    // Read interface
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire rd_valid,
    input wire rd_ready,
    
    // Status flags
    output wire full,
    output wire empty,
    output wire almost_full,
    output wire almost_empty,
    output wire [$clog2(DEPTH):0] count
);
```

## Integration Modules

### spi_wb_bridge.v

SPI-to-Wishbone bridge for register access and peripheral control.

**Features:**
- Simple protocol: [CMD][ADDR_HI][ADDR_LO][DATA]
- 16-bit address space, 8-bit data width
- SPI Mode 0 (CPOL=0, CPHA=0)
- Built-in dual-register synchronization
- Wishbone state machine (IDLE → WAIT_ACK → DONE)
- Read and write support

**Interface:**

```verilog
module spi_wb_bridge (
    input wire clk,
    input wire rst,
    
    // SPI Interface
    input wire spi_sclk,
    input wire spi_mosi,
    output wire spi_miso,
    input wire spi_cs_n,
    
    // Wishbone Master Interface
    output reg [15:0] wb_adr_o,
    output reg [7:0] wb_dat_o,
    input wire [7:0] wb_dat_i,
    output reg wb_we_o,
    output reg wb_stb_o,
    output reg wb_cyc_o,
    input wire wb_ack_i
);
```

**Protocol Commands:**
- `0x01`: Write - [CMD][ADDR_HI][ADDR_LO][DATA]
- `0x02`: Read - [CMD][ADDR_HI][ADDR_LO][DUMMY] → Returns data on next transaction

### spi_bram_controller.v

Memory interface with auto-incrementing address for sequential access.

**Features:**
- Auto-increment addressing
- Read/write mode switching
- Special command bytes (0xFF reset, 0xFE read mode)
- BRAM-inferred storage (synchronous read)
- Configurable memory depth and data width

**Interface:**

```verilog
module spi_bram_controller #(
    parameter DATA_WIDTH = 8,
    parameter MEM_DEPTH = 256,
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
```

**Protocol:**
- Normal bytes: Write to memory, auto-increment address
- `0xFF`: Reset address to 0 without writing
- `0xFE`: Switch to read mode (stop writing)

## Resource Utilization

Typical FPGA resource usage (Gowin GW1NSR-LV4C):

| Module | LUTs | FFs | BRAM |
|--------|------|-----|------|
| spi_slave (8-bit) | ~100 | ~50 | 0 |
| spi_slave (32-bit) | ~150 | ~100 | 0 |
| fifo_sync (256x8) | ~50 | ~30 | 1 (2KB) |
| spi_slave_fifo (8-bit) | ~200 | ~150 | 2 (4KB) |
| spi_wb_bridge | ~150 | ~80 | 0 |
| spi_bram_controller | ~100 | ~40 | varies |

## Timing Analysis

### Clock Domain Crossing

All SPI signals are asynchronous to the system clock and must be synchronized:
- **Method**: Dual-register synchronization (industry standard)
- **Latency**: 2 system clock cycles
- **Metastability resolution**: Sufficient for proper operation

### Speed Limits

Maximum validated SPI clock speeds:

| System Clock | Max SPI Clock | Cycles per SPI Edge | Status |
|--------------|---------------|---------------------|--------|
| 27 MHz | 4 MHz | 6.75 | ✅ Validated |
| 27 MHz | 8 MHz | 3.375 | ❌ Fails (timing violation) |

**Recommendation**: Use 4 MHz maximum for production, 2 MHz for extra margin.

### Setup/Hold Requirements

- **TX data setup**: Must be loaded during CS high (before transaction starts)
- **CS pulse width**: Minimum 1 SPI clock cycle
- **Inter-transaction gap**: Minimum 2 system clock cycles for proper state reset

## Integration Examples

### Simple Loopback

```verilog
wire [7:0] rx_data, tx_data;
wire rx_valid, rx_ready, tx_valid, tx_ready;

spi_slave #(.TRANSFER_WIDTH(8)) spi (
    .clk(sys_clk), .rst(reset),
    .spi_sclk(sck), .spi_mosi(mosi), .spi_miso(miso), .spi_cs_n(cs_n),
    .rx_data(rx_data), .rx_valid(rx_valid), .rx_ready(rx_ready),
    .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready)
);

// Loopback: RX → TX
assign tx_data = rx_data;
assign tx_valid = rx_valid;
assign rx_ready = tx_ready;
```

### FIFO-Buffered Application

```verilog
spi_slave_fifo #(
    .TRANSFER_WIDTH(8),
    .RX_FIFO_DEPTH(256),
    .TX_FIFO_DEPTH(256)
) spi_fifo (
    .clk(sys_clk), .rst_n(!reset),
    .spi_sclk(sck), .spi_mosi(mosi), .spi_miso(miso), .spi_cs_n(cs_n),
    .rx_fifo_data(app_rx_data),
    .rx_fifo_valid(app_rx_valid),
    .rx_fifo_ready(app_rx_ready),
    // ... other connections
);

// Application reads from RX FIFO when data available
always @(posedge sys_clk) begin
    if (app_rx_valid && app_rx_ready) begin
        // Process received data
        process_data(app_rx_data);
    end
end
```

## See Also

- [API Reference](../docs/API_REFERENCE.md) - Complete interface documentation
- [Timing Specifications](../docs/TIMING_SPECS.md) - Detailed timing analysis
- [Integration Guide](../docs/INTEGRATION_GUIDE.md) - Usage patterns and best practices
- [Examples](../examples/) - Complete working examples
