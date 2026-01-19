# Papilio SPI Slave Library - Testing Framework

Automated testing framework supporting both hardware validation and CI/CD simulation tests.

## Quick Start

### Hardware Tests (Local)
```powershell
cd tests
.\run_tests.ps1                          # Test all examples
.\run_tests.ps1 -Example loopback_test   # Test specific example
.\run_tests.ps1 -Example bram_interface  # Test BRAM interface
.\run_tests.ps1 -Example burst_transfers # Test burst mode (8/16/32-bit)
.\run_tests.ps1 -Verbose                 # Show detailed build output
```

### Simulation Tests (CI/CD)
```bash
cd tests
chmod +x run_sim_tests.sh
./run_sim_tests.sh
```

## Available Examples

### 1. loopback_test ✓
**Purpose:** Basic SPI communication validation  
**Tests:** 9 core functionality tests  
**Duration:** ~15 seconds  
**Validates:** SPI protocol, FIFO operation, basic data integrity  
**Expected Results:** 9 passes, 0 failures

### 2. bram_interface ✓
**Purpose:** Memory read/write interface  
**Tests:** 256 address read/write operations  
**Duration:** ~25 seconds  
**Validates:** BRAM integration, address decoding, data persistence  
**Expected Results:** 256 passes, 0 failures  
**Notes:** Tests all 256 memory addresses with read-write-verify pattern

### 3. burst_transfers ✓
**Purpose:** High-speed multi-bit-width transfers  
**Tests:** 256 transfers at 1-4 MHz (configurable 8/16/32-bit modes)  
**Duration:** ~20 seconds per mode  
**Validates:** Throughput, speed scaling, multi-byte transfers  
**Expected Results:** 256 passes, 0 failures (at 1-4 MHz)

**Throughput Results:**
- **8-bit mode:** 12-14 KB/s (baseline byte transfers)
- **16-bit mode:** 22-27 KB/s (for audio PCM, RGB565 video)
- **32-bit mode:** 36-49 KB/s (for RGB888, float audio, high-res data)

**Notes:** 
- Configure bit width in `gateware/top.v` (TRANSFER_WIDTH parameter)
- Match ESP32 test mode in `src/main.cpp` (TEST_BIT_WIDTH define)
- Maximum reliable speed: 4 MHz across all bit widths

## Test Types

### 1. Hardware Tests
Full integration tests with ESP32-S3 + FPGA hardware:
- Builds and uploads FPGA bitstream
- Builds and uploads ESP32 firmware  
- Captures serial output for validation
- Parses test results automatically

**Requirements:**
- PlatformIO installed
- Hardware connected (ESP32-S3 + Gowin GW2A-18C FPGA)
- COM port accessible
- GPIO connections: 1=CLK, 2=MOSI, 3=CS, 4=MISO

### 2. Simulation Tests (Iverilog)
HDL-only tests that run in CI/CD:
- No hardware required
- Fast execution
- Validates core SPI logic
- Runs on every push/PR

## Test Structure

```
tests/
├── run_tests.ps1           # Hardware test runner (Windows)
├── run_sim_tests.sh        # Simulation test runner (Linux/CI)
├── test_logs/              # Output logs (auto-generated)
└── README.md               # This file

examples/{example}/
├── src/main.cpp            # ESP32 test code
├── gateware/top.v          # FPGA implementation
├── fpga/project.gprj       # FPGA build config
└── platformio.ini          # Build configuration
```

## Running Tests

### Test All Examples
```powershell
cd tests
.\run_tests.ps1
```

### Test Specific Example
```powershell
.\run_tests.ps1 -Example loopback_test
.\run_tests.ps1 -Example bram_interface
.\run_tests.ps1 -Example burst_transfers
```

## Interpreting Results

Log files saved to `test_logs/` with timestamps.

### Success Criteria
- **loopback_test:** 9 passes, 0 failures
- **bram_interface:** 256 passes, 0 failures
- **burst_transfers:** 256 passes at 1-4 MHz
