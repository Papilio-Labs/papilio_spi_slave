# Papilio SPI Slave - Loopback Test Example

Basic echo validation test for 8/16/32-bit transfers. This example demonstrates the simplest use case: data sent to the FPGA is immediately echoed back.

## Purpose

Validate basic SPI communication with configurable bit widths (8, 16, or 32 bits). Useful for:
- Verifying hardware connections
- Testing different transfer widths
- Benchmarking SPI speeds
- Debugging SPI timing issues

## Hardware Requirements

- **ESP32** (or compatible SPI master)
- **Papilio FPGA** with Gowin GW1NSR-LV4C or compatible
- **Connections**: CS, SCK, MOSI, MISO (see constraints/spi_pins.cst)

## How It Works

1. ESP32 sends data byte/word via SPI
2. FPGA receives data and immediately echoes it back
3. ESP32 verifies received data matches sent data
4. Test iterates through various patterns and speeds

## Building and Running

### FPGA Side

```bash
# Navigate to gateware directory
cd gateware

# Build with your FPGA toolchain
# For Gowin, use the GUI or command-line tools to synthesize top.v
```

### ESP32 Side

```bash
# Navigate to example root
cd papilio_spi_slave/examples/loopback_test

# Build and upload
pio run --target upload

# Monitor output
pio device monitor
```

## Configuration

### Bit Width

Edit `gateware/top.v`:
```verilog
localparam TRANSFER_WIDTH = 8;   // Change to 8, 16, or 32
```

Edit `src/main.cpp`:
```cpp
#define TRANSFER_WIDTH 8  // Must match FPGA configuration
```

### SPI Speed

Edit `src/main.cpp`:
```cpp
#define TEST_SPEED_HZ 1000000  // Change to desired speed (up to 4MHz validated)
```

## Expected Output

```
===========================================
SPI Slave Loopback Test
Testing: papilio_spi_slave
===========================================

SPI initialized at 1MHz (Mode 0)

--- 8-bit Transfer Tests ---
✓ Single byte loopback (0x42 → 0x42)
✓ Pattern 0x00 → 0x00
✓ Pattern 0xFF → 0xFF
✓ Pattern 0xAA → 0xAA
✓ Pattern 0x55 → 0x55
✓ Burst transfer (10 bytes) - All matched!

===========================================
TEST SUMMARY
===========================================
Passed: 6
Failed: 0

✓ ALL TESTS PASSED!
===========================================
```

## Troubleshooting

### No Response (all 0x00 or 0xFF)

- Check wiring connections
- Verify FPGA is programmed and running
- Check CS polarity (should be active-low)
- Measure SPI signals with logic analyzer

### Bit Errors

- Try lower SPI speed (start with 100kHz)
- Check for noise on signal lines
- Verify ground connection between ESP32 and FPGA
- Ensure system clock is stable (27MHz recommended)

### Timing Violations at High Speed

- Maximum validated speed is 4MHz with 27MHz system clock
- Above 4MHz may cause timing violations
- Use 2MHz for extra margin in noisy environments

## Pin Configuration

See `constraints/spi_pins.cst` for FPGA pin assignments.

Default ESP32 pins:
- CS: GPIO3
- SCK: GPIO1  
- MOSI: GPIO2
- MISO: GPIO4

Modify in `src/main.cpp` if using different pins.

## Files

- `src/main.cpp` - ESP32 test harness
- `gateware/top.v` - FPGA top module (loopback configuration)
- `constraints/spi_pins.cst` - Pin assignments
- `platformio.ini` - PlatformIO configuration
- `README.md` - This file
