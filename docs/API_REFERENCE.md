# Papilio SPI Slave - API Reference

Complete reference for C++ driver and HDL module interfaces.

## C++ Driver API (PapilioSPI Class)

### Constructor

```cpp
PapilioSPI()
```

Creates a new PapilioSPI object. Call `begin()` before use.

### Initialization

#### begin()

```cpp
bool begin(SPIClass* spi = &SPI, int cs_pin = SS, 
           uint32_t speed = 1000000, uint8_t mode = SPI_MODE0)
```

Initialize the SPI interface.

**Parameters:**
- `spi` - Pointer to SPIClass instance (default: &SPI)
- `cs_pin` - Chip select pin number (default: SS)
- `speed` - SPI clock speed in Hz (default: 1MHz, max: 4MHz validated)
- `mode` - SPI mode (default: SPI_MODE0)

**Returns:** `true` on success, `false` on failure

**Example:**
```cpp
PapilioSPI spi;
SPIClass fpgaSPI;
fpgaSPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, CS_PIN);
spi.begin(&fpgaSPI, CS_PIN, 1000000, SPI_MODE0);
```

#### end()

```cpp
void end()
```

Release the SPI interface and reset state.

### Data Transfer

#### transfer8()

```cpp
uint8_t transfer8(uint8_t data)
```

Perform a single 8-bit SPI transfer.

**Parameters:**
- `data` - Byte to send

**Returns:** Byte received from FPGA

**Example:**
```cpp
uint8_t response = spi.transfer8(0x42);
```

#### transfer16()

```cpp
uint16_t transfer16(uint16_t data)
```

Perform a single 16-bit SPI transfer (MSB first).

**Parameters:**
- `data` - 16-bit word to send

**Returns:** 16-bit word received from FPGA

**Example:**
```cpp
uint16_t response = spi.transfer16(0x1234);
```

#### transfer32()

```cpp
uint32_t transfer32(uint32_t data)
```

Perform a single 32-bit SPI transfer (MSB first).

**Parameters:**
- `data` - 32-bit word to send

**Returns:** 32-bit word received from FPGA

**Example:**
```cpp
uint32_t response = spi.transfer32(0x12345678);
```

#### transferBurst()

```cpp
void transferBurst(const uint8_t* txBuf, uint8_t* rxBuf, size_t len)
```

Perform efficient multi-byte transfer with single CS assertion.

**Parameters:**
- `txBuf` - Transmit buffer (NULL for dummy bytes)
- `rxBuf` - Receive buffer (NULL to discard)
- `len` - Number of bytes to transfer

**Example:**
```cpp
uint8_t txData[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
uint8_t rxData[10];
spi.transferBurst(txData, rxData, 10);
```

### Configuration

#### setBitWidth()

```cpp
void setBitWidth(uint8_t width)
```

Set transfer bit width. Must match FPGA configuration.

**Parameters:**
- `width` - Bit width (8, 16, or 32)

**Example:**
```cpp
spi.setBitWidth(16);  // Switch to 16-bit mode
```

#### setSpeed()

```cpp
void setSpeed(uint32_t hz)
```

Set SPI clock speed.

**Parameters:**
- `hz` - Frequency in Hz (max: 4MHz validated)

**Example:**
```cpp
spi.setSpeed(2000000);  // 2 MHz
```

#### setMode()

```cpp
void setMode(uint8_t mode)
```

Set SPI mode (0-3).

**Parameters:**
- `mode` - SPI_MODE0, SPI_MODE1, SPI_MODE2, or SPI_MODE3

**Example:**
```cpp
spi.setMode(SPI_MODE1);
```

### FIFO Operations

#### rxAvailable()

```cpp
int rxAvailable()
```

Check if RX data is available (placeholder - requires FPGA protocol support).

**Returns:** Estimated bytes available (0 if not implemented)

#### txReady()

```cpp
bool txReady()
```

Check if TX buffer is ready (placeholder).

**Returns:** `true` if ready (always true if not implemented)

#### readFifo()

```cpp
uint8_t readFifo()
```

Read one byte from RX FIFO.

**Returns:** Byte read

#### writeFifo()

```cpp
void writeFifo(uint8_t data)
```

Write one byte to TX FIFO.

**Parameters:**
- `data` - Byte to write

### Utility

#### isReady()

```cpp
bool isReady()
```

Check if FPGA is responding (basic implementation).

**Returns:** `true` if communication appears functional

---

## HDL Modules

### spi_slave.v

Core SPI slave protocol engine.

```verilog
module spi_slave #(
    parameter TRANSFER_WIDTH = 8  // 8, 16, or 32 bits
)(
    // System interface
    input wire clk,           // System clock (27MHz recommended)
    input wire rst,           // Active-high reset
    
    // SPI interface (asynchronous)
    input wire spi_sclk,      // SPI clock from master
    input wire spi_mosi,      // Master Out, Slave In
    output wire spi_miso,     // Master In, Slave Out
    input wire spi_cs_n,      // Chip select (active low)
    
    // Receive interface (system clock domain)
    output reg [TRANSFER_WIDTH-1:0] rx_data,  // Received word
    output reg rx_valid,                       // Strobe when valid
    input wire rx_ready,                       // Backpressure
    
    // Transmit interface (system clock domain)
    input wire [TRANSFER_WIDTH-1:0] tx_data,  // Word to transmit
    input wire tx_valid,                       // Load signal
    output reg tx_ready                        // Ready for new data
);
```

**Parameters:**
- `TRANSFER_WIDTH` - Bits per transfer (8, 16, or 32)

**Timing:**
- TX data must be loaded BEFORE CS active
- RX data valid strobed when word complete
- Dual-register CDC synchronization (2 cycles latency)

**See:** [gateware/README.md](../gateware/README.md) for detailed documentation

### spi_slave_fifo.v

FIFO-enhanced SPI slave for buffered operation.

```verilog
module spi_slave_fifo #(
    parameter TRANSFER_WIDTH = 8,
    parameter RX_FIFO_DEPTH = 256,
    parameter TX_FIFO_DEPTH = 256
)(
    input wire clk,
    input wire rst_n,          // Active-low reset
    
    // SPI interface
    input wire spi_sclk,
    input wire spi_mosi,
    output wire spi_miso,
    input wire spi_cs_n,
    
    // RX FIFO interface
    output wire [TRANSFER_WIDTH-1:0] rx_fifo_data,
    output wire rx_fifo_valid,
    input wire rx_fifo_ready,
    output wire rx_fifo_empty,
    output wire rx_fifo_almost_full,
    output wire [$clog2(RX_FIFO_DEPTH):0] rx_fifo_count,
    
    // TX FIFO interface
    input wire [TRANSFER_WIDTH-1:0] tx_fifo_data,
    input wire tx_fifo_valid,
    output wire tx_fifo_ready,
    output wire tx_fifo_full,
    output wire tx_fifo_almost_empty,
    output wire [$clog2(TX_FIFO_DEPTH):0] tx_fifo_count
);
```

**Parameters:**
- `TRANSFER_WIDTH` - Bits per transfer (8, 16, or 32)
- `RX_FIFO_DEPTH` - RX FIFO depth (power of 2 recommended)
- `TX_FIFO_DEPTH` - TX FIFO depth (power of 2 recommended)

**Features:**
- Automatic buffering
- DMA-ready interface
- Status flags for flow control

### Other Modules

See [gateware/README.md](../gateware/README.md) for documentation on:
- `fifo_sync.v` - Synchronous FIFO primitive
- `spi_wb_bridge.v` - Wishbone integration
- `spi_bram_controller.v` - Memory interface

---

## See Also

- [Timing Specifications](TIMING_SPECS.md) - Speed limits and requirements
- [Integration Guide](INTEGRATION_GUIDE.md) - Usage patterns
- [Examples](../examples/) - Working code examples
