# Papilio SPI Slave - Example Stubs

This directory contains 6 complete examples demonstrating various use cases:

## 1. loopback_test ✅
**Status**: Complete
Basic echo validation - data sent is immediately returned. Good for verifying hardware connections and testing different bit widths.

## 2. burst_transfers
**Status**: Stub created
Demonstrates efficient multi-byte transfers with automatic CS management. Shows how to transfer 10+ consecutive bytes efficiently.

## 3. bram_interface
**Status**: Stub created  
256-byte memory with auto-increment addressing. Write sequential data, read it back. Demonstrates protocol: 0xFF=reset address, 0xFE=read mode.

## 4. speed_validation
**Status**: Stub created
Benchmarks SPI communication from 100kHz to 4MHz. Validates timing margins and identifies maximum reliable speed for your hardware.

## 5. wishbone_bridge
**Status**: Stub created
SPI-to-Wishbone register access. Read/write FPGA registers via simple [CMD][ADDR][DATA] protocol. Foundation for peripheral control.

## 6. logic_analyzer
**Status**: Stub created
High-throughput FIFO streaming for data capture. Demonstrates DMA-ready continuous data transfer using FIFOs.

## Usage

Each example contains:
- `src/main.cpp` - ESP32 test harness
- `gateware/top.v` - FPGA top module  
- `constraints/spi_pins.cst` - Pin assignments
- `platformio.ini` - Build configuration
- `README.md` - Documentation

To build and run an example:
```bash
cd examples/<example_name>
pio run --target upload
pio device monitor
```

## Development Status

Priority was given to the loopback_test as a complete reference implementation. Remaining examples follow the same structure and can be completed based on the test scenarios in `tests/run_library_tests.ps1`.
