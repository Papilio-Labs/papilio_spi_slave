# papilio_spi_slave - AI Skill

This file provides machine-consumable details about the `papilio_spi_slave` library for AI assistants.

## Purpose
Production-ready SPI slave library for FPGA-to-microcontroller communication with variable bit-widths (8/16/32-bit), FIFO buffering, and DMA-ready streaming.

## Hardware Specifications
- **Maximum validated speed**: 4 MHz SPI clock
- **Minimum system clock**: 27 MHz (6.75 cycles per SPI edge)
- **FIFO depth**: 256 entries (RX/TX configurable)
- **Transfer widths**: 8, 16, or 32 bits (parameterized)
- **SPI modes**: Mode 0 (CPOL=0, CPHA=0), compatible with Mode 1 masters
- **CDC protection**: Dual-register synchronization for metastability

## Gateware Modules

### spi_slave.v
Core protocol engine with parameterized transfer width.

**Parameters:**
- `TRANSFER_WIDTH` (default 8): Transfer width in bits (8, 16, or 32)

**Ports:**
- `clk`, `rst`: System clock and active-high reset
- `spi_sclk`, `spi_cs_n`, `spi_mosi`, `spi_miso`: SPI interface signals
- `rx_data[WIDTH-1:0]`, `rx_valid`, `rx_ready`: Receive interface (ready/valid handshake)
- `tx_data[WIDTH-1:0]`, `tx_valid`, `tx_ready`: Transmit interface (ready/valid handshake)

**Timing:**
- TX data must be loaded BEFORE CS goes active
- Samples MOSI on rising edge, shifts MISO on falling edge

### spi_slave_fifo.v
Enhanced variant with integrated RX/TX FIFOs for high-throughput applications.

**Parameters:**
- `TRANSFER_WIDTH` (default 8): Transfer width (8, 16, or 32)
- `RX_FIFO_DEPTH` (default 256): RX FIFO depth (power of 2)
- `TX_FIFO_DEPTH` (default 256): TX FIFO depth (power of 2)

**Additional Ports:**
- `rx_fifo_empty`, `rx_fifo_almost_full`, `rx_fifo_count`: RX FIFO status
- `tx_fifo_full`, `tx_fifo_almost_empty`, `tx_fifo_count`: TX FIFO status

### Integration Modules
- `spi_wb_bridge.v`: SPI-to-Wishbone bridge for register/memory access
- `spi_bram_controller.v`: Memory interface with auto-increment addressing
- `fifo_sync.v`: Synchronous FIFO primitive used by spi_slave_fifo

## Firmware API

### Class: PapilioSPI

**Initialization:**
```cpp
bool begin(uint32_t speed = 1000000, uint8_t mode = SPI_MODE0);
void end();
```

**Data Transfer:**
```cpp
uint8_t transfer8(uint8_t data);
uint16_t transfer16(uint16_t data);
uint32_t transfer32(uint32_t data);
void transferBurst(uint8_t* txBuf, uint8_t* rxBuf, size_t len);
```

**FIFO Operations:**
```cpp
int rxAvailable();          // Number of bytes in RX FIFO
bool txReady();             // TX FIFO has space
uint8_t readFifo();         // Read from RX FIFO
void writeFifo(uint8_t data); // Write to TX FIFO
```

**Configuration:**
```cpp
void setBitWidth(uint8_t width);  // Set width (8/16/32)
void setSpeed(uint32_t hz);       // Set SPI clock speed
void setMode(uint8_t mode);       // Set SPI mode (0-3)
```

## Examples
Complete working examples in `examples/` directory:
- **loopback_test/**: Basic echo validation (8/16/32-bit)
- **burst_transfers/**: Multi-transfer sequences
- **bram_interface/**: 256-byte memory with auto-increment
- **speed_validation/**: 100 kHz - 4 MHz benchmarks
- **wishbone_bridge/**: Register read/write patterns
- **logic_analyzer/**: High-throughput FIFO streaming

## Testing

### Simulation
Location: `tests/sim/`
- Testbenches validate all bit widths and transfer patterns
- Use `papilio_dev_tools` simulation infrastructure

### Hardware Tests
Location: `tests/hw/`
- Automated regression tests validate:
  - All bit widths (8/16/32)
  - Speed ranges (100 kHz - 4 MHz)
  - Bit patterns (0x00, 0xFF, 0xAA, 0x55, etc.)
  - Burst transfers
  - BRAM operations

Run tests:
```powershell
cd tests
.\run_library_tests.ps1
```

## Pin Assignments

No fixed pin assignments - users configure in top-level constraints:
- `spi_sck`: SPI clock input (from master)
- `spi_cs_n`: Chip select (active low)
- `spi_mosi`: Master Out, Slave In
- `spi_miso`: Master In, Slave Out

## Common Operations

### Instantiate 8-bit Loopback
```verilog
spi_slave #(.TRANSFER_WIDTH(8)) spi_inst (
    .clk(sys_clk), .rst(reset),
    .spi_sclk(spi_sck), .spi_cs_n(spi_cs_n),
    .spi_mosi(spi_mosi), .spi_miso(spi_miso),
    .rx_data(rx_data), .rx_valid(rx_valid), .rx_ready(tx_ready),
    .tx_data(rx_data), .tx_valid(rx_valid), .tx_ready(tx_ready)
);
```

### Add FIFO Buffering
```verilog
spi_slave_fifo #(
    .TRANSFER_WIDTH(8),
    .RX_FIFO_DEPTH(256),
    .TX_FIFO_DEPTH(256)
) spi_fifo_inst (
    .clk(sys_clk), .rst_n(~reset),
    .spi_sclk(spi_sck), .spi_cs_n(spi_cs_n),
    .spi_mosi(spi_mosi), .spi_miso(spi_miso),
    // RX FIFO interface
    .rx_fifo_data(rx_data),
    .rx_fifo_valid(rx_valid),
    .rx_fifo_ready(rx_ready),
    .rx_fifo_count(rx_count),
    // TX FIFO interface
    .tx_fifo_data(tx_data),
    .tx_fifo_valid(tx_valid),
    .tx_fifo_ready(tx_ready),
    .tx_fifo_count(tx_count)
);
```

### ESP32 Basic Usage
```cpp
#include <PapilioSPI.h>
PapilioSPI spi;

void setup() {
    spi.begin(1000000, SPI_MODE0);  // 1 MHz, Mode 0
    uint8_t response = spi.transfer8(0x42);
}
```

## Notes for AI Assistants

### When Modifying This Library
- Maintain Papilio Library Standards structure
- Keep CDC synchronization for all SPI signals
- Validate timing at maximum 4 MHz operation
- Document register maps in module comments
- Add testbenches for new features

### Troubleshooting Patterns
- **No data received**: Check TX data loaded before CS active
- **Corrupted data**: Verify system clock ≥ 27 MHz for 4 MHz SPI
- **Timing violations**: Reduce SPI clock or increase system clock
- **FIFO overrun**: Check almost_full/almost_empty flags, add flow control

### Adding Features
- New transfer widths: Add to TRANSFER_WIDTH parameter validation
- Protocol enhancements: Extend command byte encoding
- Integration modules: Use ready/valid handshaking patterns
- Status registers: Add to spi_wb_bridge address decoder

### Reference Implementation
This library serves as the foundation for `papilio_wishbone_bus` and other SPI-based communication libraries in the Papilio ecosystem.

## Repository
https://github.com/Papilio-Labs/papilio_spi_slave

## Related Libraries
- `papilio_wishbone_bus`: Multi-width SPI-based Wishbone master (uses this library's patterns)
- `papilio_dev_tools`: Testing and simulation infrastructure
