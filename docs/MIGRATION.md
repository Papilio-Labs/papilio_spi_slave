# Papilio SPI Slave - Migration Guide

Guide for migrating from `papilio_hdl_blocks` to `papilio_spi_slave` library.

## Overview

The `papilio_spi_slave` library consolidates and improves upon the SPI slave functionality previously in `papilio_hdl_blocks`. This migration provides:

- **Arduino-style C++ API**: Simpler, more intuitive interface
- **Complete examples**: Working reference implementations
- **Better organization**: Clear separation of concerns
- **Comprehensive documentation**: API reference, timing specs, integration guides
- **Production-ready**: Version 1.0.0 with extensive validation

## What Changed

### Library Structure

**Before (papilio_hdl_blocks):**
```
papilio_hdl_blocks/
├── spi_slave.v
├── spi_slave_fifo.v
├── fifo_sync.v
├── README.md
└── examples/
```

**After (papilio_spi_slave):**
```
papilio_spi_slave/
├── src/              # C++ driver
│   ├── PapilioSPI.h
│   └── PapilioSPI.cpp
├── gateware/         # Verilog modules
│   ├── spi_slave.v
│   ├── spi_slave_fifo.v
│   ├── fifo_sync.v
│   ├── spi_wb_bridge.v
│   └── spi_bram_controller.v
├── examples/         # Complete working examples
├── tests/            # Automated test suite
└── docs/             # Comprehensive documentation
```

### HDL Modules

**No functional changes** to the core Verilog modules:
- `spi_slave.v` - Identical
- `spi_slave_fifo.v` - Identical
- `fifo_sync.v` - Identical

**New modules added:**
- `spi_wb_bridge.v` - Wishbone integration (from papilio_wishbone_spi_master)
- `spi_bram_controller.v` - Memory interface extracted from test code

### C++ API

**Before:** Direct SPI calls, manual CS management
```cpp
SPIClass spi;
spi.begin(SCK, MISO, MOSI, CS);

pinMode(CS, OUTPUT);
digitalWrite(CS, HIGH);

// Manual transaction
spi.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
digitalWrite(CS, LOW);
uint8_t data = spi.transfer(0x42);
digitalWrite(CS, HIGH);
spi.endTransaction();
```

**After:** Simplified PapilioSPI class
```cpp
#include <PapilioSPI.h>

PapilioSPI spi;
SPIClass fpgaSPI;
fpgaSPI.begin(SCK, MISO, MOSI, CS);
spi.begin(&fpgaSPI, CS, 1000000);

// Simple transaction
uint8_t data = spi.transfer8(0x42);
```

## Migration Steps

### Step 1: Update PlatformIO Dependencies

**Before:**
```ini
[env:esp32]
lib_deps = 
    papilio_hdl_blocks
```

**After:**
```ini
[env:esp32]
lib_deps = 
    papilio_spi_slave
```

### Step 2: Update C++ Includes

**Before:**
```cpp
#include <SPI.h>
// Manual SPI management
```

**After:**
```cpp
#include <PapilioSPI.h>
// Use PapilioSPI class
```

### Step 3: Update FPGA Module Paths

**Before:**
```verilog
`include "../libs/papilio_hdl_blocks/spi_slave.v"
```

**After:**
```verilog
`include "../libs/papilio_spi_slave/gateware/spi_slave.v"
```

Or update your build system to include the new path.

### Step 4: Refactor C++ Code

**Before - Manual SPI:**
```cpp
void setup() {
    SPIClass* spi = new SPIClass();
    spi->begin(SCK, MISO, MOSI, CS);
    pinMode(CS, OUTPUT);
    digitalWrite(CS, HIGH);
}

uint8_t sendByte(uint8_t data) {
    spi->beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
    digitalWrite(CS, LOW);
    delayMicroseconds(1);
    uint8_t result = spi->transfer(data);
    delayMicroseconds(1);
    digitalWrite(CS, HIGH);
    spi->endTransaction();
    return result;
}
```

**After - PapilioSPI:**
```cpp
#include <PapilioSPI.h>

PapilioSPI papilioSPI;

void setup() {
    SPIClass fpgaSPI;
    fpgaSPI.begin(SCK, MISO, MOSI, CS);
    papilioSPI.begin(&fpgaSPI, CS, 1000000, SPI_MODE0);
}

uint8_t sendByte(uint8_t data) {
    return papilioSPI.transfer8(data);
}
```

### Step 5: Update Burst Transfers

**Before:**
```cpp
for (int i = 0; i < 100; i++) {
    spi->beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
    digitalWrite(CS, LOW);
    rxData[i] = spi->transfer(txData[i]);
    digitalWrite(CS, HIGH);
    spi->endTransaction();
}
```

**After:**
```cpp
// More efficient - single CS cycle
papilioSPI.transferBurst(txData, rxData, 100);
```

### Step 6: Update 16/32-bit Transfers

**Before:**
```cpp
// 16-bit manual
spi->beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
digitalWrite(CS, LOW);
uint8_t high = spi->transfer((data >> 8) & 0xFF);
uint8_t low = spi->transfer(data & 0xFF);
digitalWrite(CS, HIGH);
spi->endTransaction();
uint16_t result = ((uint16_t)high << 8) | low;
```

**After:**
```cpp
// 16-bit with library
uint16_t result = papilioSPI.transfer16(data);
```

## API Mapping

### Data Transfer Functions

| Old Pattern | New API | Notes |
|-------------|---------|-------|
| `spi->transfer(byte)` with manual CS | `papilioSPI.transfer8(byte)` | CS handled automatically |
| Manual 16-bit transfer | `papilioSPI.transfer16(word)` | MSB first |
| Manual 32-bit transfer | `papilioSPI.transfer32(dword)` | MSB first |
| Loop with CS toggles | `papilioSPI.transferBurst(tx, rx, len)` | Much more efficient |

### Configuration Functions

| Old Pattern | New API | Notes |
|-------------|---------|-------|
| `SPISettings(speed, ...)` | `papilioSPI.setSpeed(speed)` | Update speed dynamically |
| Change mode in settings | `papilioSPI.setMode(mode)` | Update mode dynamically |
| Recompile for bit width | `papilioSPI.setBitWidth(width)` | 8/16/32 (must match FPGA) |

## HDL Migration

No changes required for basic instantiation:

```verilog
// Same as before
spi_slave #(
    .TRANSFER_WIDTH(8)
) spi_inst (
    .clk(clk),
    .rst(rst),
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_cs_n(spi_cs_n),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),
    .tx_data(tx_data),
    .tx_valid(tx_valid),
    .tx_ready(tx_ready)
);
```

### New Modules Available

Take advantage of new integration modules:

```verilog
// BRAM controller (previously in test code)
spi_bram_controller #(
    .DATA_WIDTH(8),
    .MEM_DEPTH(256)
) bram (
    // Connect to SPI slave RX/TX
);

// Wishbone bridge (previously in papilio_wishbone_spi_master)
spi_wb_bridge bridge (
    // SPI + Wishbone interfaces
);
```

## Testing After Migration

### 1. Run Loopback Test

```bash
cd libs/papilio_spi_slave/examples/loopback_test
pio run --target upload
pio device monitor
```

Expected output: All tests pass

### 2. Run Full Test Suite

```bash
cd libs/papilio_spi_slave/tests
.\run_library_tests.ps1
```

This validates all configurations (8/16/32-bit, loopback, BRAM).

### 3. Verify Your Application

After migrating:
1. Compile successfully (check includes and lib_deps)
2. Basic loopback test passes
3. Application-specific functionality works
4. Performance is same or better (burst transfers should be faster)

## Breaking Changes

### 1. Include Path Changes

- Old: `#include <SPI.h>` (direct use)
- New: `#include <PapilioSPI.h>`

### 2. CS Management

- Old: Manual `digitalWrite(CS, LOW/HIGH)`
- New: Automatic (handled by library)

If you need manual CS control for special protocols, you can still access the underlying SPIClass:
```cpp
// Not recommended, but possible
digitalWrite(CS, LOW);
// custom protocol
digitalWrite(CS, HIGH);
```

### 3. Function Names

- Old: Generic `spi->transfer()`
- New: Explicit `papilioSPI.transfer8/16/32()`

This makes bit width explicit and catches mismatches at compile time.

### 4. Library Name in PlatformIO

- Old: `lib_deps = papilio_hdl_blocks`
- New: `lib_deps = papilio_spi_slave`

## Deprecation Notice

The `papilio_hdl_blocks` library is now considered deprecated for SPI slave functionality. While the HDL modules themselves are unchanged, the improved organization, documentation, and C++ API make `papilio_spi_slave` the recommended choice for all new projects.

**Existing projects using papilio_hdl_blocks:**
- Will continue to work (HDL modules are identical)
- Should migrate when convenient for the benefits listed above
- Can reference this guide for step-by-step migration

## Benefits of Migration

### For Users

1. **Simpler API**: Less boilerplate code
2. **Better examples**: Complete working references
3. **Comprehensive docs**: API reference, timing specs, integration guides
4. **Burst efficiency**: Single CS for multiple bytes
5. **Explicit bit widths**: Catch mismatches at compile time

### For Developers

1. **Organized structure**: Clear separation (src/, gateware/, examples/, docs/)
2. **Integration modules**: Pre-built Wishbone bridge, BRAM controller
3. **Test infrastructure**: Automated validation
4. **Production ready**: Version 1.0.0, extensively tested

## Getting Help

If you encounter issues during migration:

1. Check [examples/](../examples/) for reference implementations
2. Review [API Reference](API_REFERENCE.md) for detailed interface docs
3. See [Integration Guide](INTEGRATION_GUIDE.md) for common patterns
4. Run [tests/](../tests/) to validate your setup
5. File an issue on GitHub with details

## Version History

### papilio_spi_slave 1.0.0 (January 4, 2026)
- Initial release consolidating papilio_hdl_blocks SPI functionality
- Added PapilioSPI C++ API
- Added spi_wb_bridge and spi_bram_controller modules
- Complete examples and documentation
- Automated test suite

### papilio_hdl_blocks 1.0.0 (Previous)
- Original SPI slave implementation
- HDL modules only
- Basic examples
- Now deprecated for SPI slave use

## See Also

- [API Reference](API_REFERENCE.md) - Complete interface documentation
- [Examples](../examples/) - Working migration examples
- [Integration Guide](INTEGRATION_GUIDE.md) - Usage patterns
- [README](../README.md) - Library overview and quick start
