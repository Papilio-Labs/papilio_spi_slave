# Papilio SPI Slave Library

Production-ready SPI slave library for FPGA-to-microcontroller communication. Provides validated HDL modules and simple Arduino-style C++ API for rapid integration.

## Features

- ✅ **Variable bit-widths**: 8, 16, or 32-bit transfers
- ✅ **High-speed operation**: Validated up to 4 MHz (27 MHz system clock)
- ✅ **FIFO buffering**: 256-entry RX/TX FIFOs for DMA-ready streaming
- ✅ **Burst transfers**: Auto-increment addressing for efficient multi-byte operations
- ✅ **Wishbone integration**: Pre-built SPI-to-Wishbone bridge
- ✅ **Comprehensive testing**: Automated test suite with hardware validation
- ✅ **Multiple use cases**: Loopback, BRAM interface, register access, logic analyzer

## Quick Start

### Arduino (ESP32)

```cpp
#include <PapilioSPI.h>

PapilioSPI spi;

void setup() {
    spi.begin();  // Initialize with default settings (Mode 0, 1 MHz)
    
    // Simple 8-bit transfer
    uint8_t response = spi.transfer8(0x42);
    
    // Burst transfer (10 bytes)
    uint8_t txData[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
    uint8_t rxData[10];
    spi.transferBurst(txData, rxData, 10);
    
    // Check FIFO status
    if (spi.rxAvailable() > 0) {
        uint8_t data = spi.readFifo();
    }
}
```

### Verilog (FPGA)

```verilog
// Instantiate core SPI slave (8-bit loopback example)
spi_slave #(
    .WIDTH(8)  // 8, 16, or 32 bits
) spi_inst (
    .clk(sys_clk),
    .rst(reset),
    
    // SPI interface
    .spi_sck(spi_sck),
    .spi_cs_n(spi_cs_n),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    
    // Application interface
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),
    
    .tx_data(tx_data),
    .tx_valid(tx_valid),
    .tx_ready(tx_ready)
);

// Simple loopback: connect RX to TX
assign tx_data = rx_data;
assign tx_valid = rx_valid;
assign rx_ready = tx_ready;
```

## Examples

Complete working examples in `examples/` directory:

- **loopback_test/** - Basic echo validation (8/16/32-bit)
- **burst_transfers/** - Multi-transfer sequences
- **bram_interface/** - 256-byte memory with auto-increment
- **speed_validation/** - 100 kHz - 4 MHz benchmarks
- **wishbone_bridge/** - Register read/write patterns
- **logic_analyzer/** - High-throughput FIFO streaming

Each example includes ESP32 test harness, FPGA top module, constraints, and documentation.

## API Reference

### C++ Class: PapilioSPI

#### Initialization
- `bool begin(uint32_t speed = 1000000, uint8_t mode = SPI_MODE0)` - Initialize SPI interface
- `void end()` - Release SPI interface

#### Data Transfer
- `uint8_t transfer8(uint8_t data)` - Single 8-bit transfer
- `uint16_t transfer16(uint16_t data)` - Single 16-bit transfer
- `uint32_t transfer32(uint32_t data)` - Single 32-bit transfer
- `void transferBurst(uint8_t* txBuf, uint8_t* rxBuf, size_t len)` - Burst transfer

#### FIFO Operations
- `int rxAvailable()` - Number of bytes available in RX FIFO
- `bool txReady()` - TX FIFO has space
- `uint8_t readFifo()` - Read from RX FIFO
- `void writeFifo(uint8_t data)` - Write to TX FIFO

#### Configuration
- `void setBitWidth(uint8_t width)` - Set transfer width (8/16/32)
- `void setSpeed(uint32_t hz)` - Set SPI clock speed
- `void setMode(uint8_t mode)` - Set SPI mode (0-3)

### HDL Modules

See [gateware/README.md](gateware/README.md) for detailed module documentation.

**Core Modules:**
- `spi_slave.v` - Protocol engine (8/16/32-bit parameterized)
- `spi_slave_fifo.v` - FIFO-enhanced variant
- `fifo_sync.v` - Synchronous FIFO primitive

**Integration Modules:**
- `spi_wb_bridge.v` - SPI-to-Wishbone bridge
- `spi_bram_controller.v` - Memory interface with auto-increment

## Timing Specifications

- **Maximum validated speed**: 4 MHz SPI clock
- **Minimum system clock**: 27 MHz (6.75 cycles per SPI edge at 4 MHz)
- **Setup time**: TX data must be loaded BEFORE CS goes active
- **CDC synchronization**: Dual-register metastability protection
- **Supported SPI modes**: Mode 0 (CPOL=0, CPHA=0), works optimally with Mode 1 masters

See [docs/TIMING_SPECS.md](docs/TIMING_SPECS.md) for detailed timing analysis.

## Testing

Automated test suite in `tests/` directory validates:
- All bit widths (8/16/32-bit)
- Speed ranges (100 kHz - 4 MHz)
- Bit patterns (0x00, 0xFF, 0xAA, 0x55, etc.)
- Burst transfers (10+ transactions)
- BRAM operations (256 bytes)

Run tests:
```powershell
cd tests
.\run_library_tests.ps1
```

## Documentation

- [API Reference](docs/API_REFERENCE.md) - Complete C++ and HDL interface documentation
- [Timing Specifications](docs/TIMING_SPECS.md) - Speed limits and timing requirements
- [Integration Guide](docs/INTEGRATION_GUIDE.md) - Wishbone and FIFO patterns
- [Test Results](docs/TEST_RESULTS.md) - Hardware validation report
- [Migration Guide](docs/MIGRATION.md) - Porting from papilio_hdl_blocks

## Hardware Requirements

**FPGA:**
- Gowin GW1NSR-LV4C or compatible
- Minimum 27 MHz system clock for 4 MHz SPI
- ~200 LUTs for basic SPI slave
- ~1 BRAM (2KB) for FIFO variant

**Microcontroller:**
- ESP32 or compatible SPI master
- GPIO pins for CS, SCK, MOSI, MISO

## License

MIT License - See LICENSE file for details

## Support

- GitHub Issues: https://github.com/Papilio-Labs/papilio_spi_slave/issues
- Documentation: See `docs/` directory
- Examples: See `examples/` directory

## Version History

### 1.0.0 (January 4, 2026)
- Initial production release
- 8/16/32-bit transfers validated to 4 MHz
- FIFO buffering with 256-entry depth
- Burst transfer support
- Wishbone bridge integration
- 6 complete working examples
- Comprehensive test suite
- Full documentation
