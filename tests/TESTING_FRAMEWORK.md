# Papilio SPI Slave Library - Testing Framework Summary

## What We Created

### 1. Automated Hardware Test Runner
**File:** `libs/papilio_spi_slave/tests/run_tests.ps1`

- Runs hardware tests on actual ESP32 + FPGA
- Automatically builds and uploads both FPGA and ESP32
- Captures serial output and parses results
- Supports verbose mode for debugging
- Saves timestamped logs

### 2. CI/CD Simulation Test Runner  
**File:** `libs/papilio_spi_slave/tests/run_sim_tests.sh`

- Runs iverilog testbenches without hardware
- Suitable for GitHub Actions CI/CD
- Fast execution (no uploads required)
- Tests core HDL logic

### 3. GitHub Actions Workflow
**File:** `.github/workflows/test-library.yml`

- Runs on every push/PR
- Three test stages:
  1. Simulation tests (iverilog)
  2. Build tests (compile all examples)
  3. Lint tests (Verilator)
- Uploads artifacts (logs, binaries)

### 4. Example Testbench
**File:** `libs/papilio_spi_slave/examples/loopback_test/sim/tb_loopback_test.v`

- Iverilog testbench for SPI loopback
- Tests 8 different patterns
- Validates echo functionality
- Example template for other tests

### 5. Documentation
**File:** `libs/papilio_spi_slave/tests/README.md`

- Complete testing guide
- Usage examples
- Troubleshooting tips
- Best practices

## How to Use

### Run All Hardware Tests
```powershell
cd libs/papilio_spi_slave/tests
.\run_tests.ps1
```

### Run Specific Example
```powershell
.\run_tests.ps1 -Example loopback_test -Verbose
```

### Run Simulation Tests (for CI)
```bash
cd libs/papilio_spi_slave/tests
chmod +x run_sim_tests.sh
./run_sim_tests.sh
```

## Test Flow

### Hardware Test Flow
```
1. Build FPGA bitstream (clean + compile)
2. Upload bitstream to FPGA flash
3. Build ESP32 firmware
4. Upload firmware to ESP32
5. Capture serial output (15-20 seconds)
6. Parse "Passed: N, Failed: M" from output
7. Determine PASS/FAIL based on expected values
```

### Simulation Test Flow
```
1. Find all tb_*.v files in examples/*/sim/
2. Compile with iverilog + library gateware
3. Run simulation with vvp
4. Check output for "PASS" string
5. Report results
```

## Adding New Tests

### For Hardware
1. Create example in `examples/{name}/`
2. ESP32 code must print:
   ```
   Passed: N
   Failed: M
   ```
3. Add to `run_tests.ps1`:
   ```powershell
   "test_name" = @{
       Description = "What it tests"
       ExpectedPasses = 5
       HasFPGA = $true
       HasSimulation = $true
       CaptureSeconds = 15
   }
   ```

### For Simulation
1. Create `examples/{name}/sim/tb_{name}.v`
2. Must print "PASS" if successful
3. Must call `$finish(0)` for success, `$finish(1)` for failure
4. Automatically discovered by `run_sim_tests.sh`

## Benefits

✅ **Repeatable** - Same tests every time, automated
✅ **Fast Feedback** - Simulation tests run in seconds
✅ **CI/CD Ready** - GitHub Actions runs on every push
✅ **No Manual Steps** - Fully automated build/upload/test
✅ **Clear Results** - PASS/FAIL with detailed logs
✅ **Hardware + Sim** - Test both HDL logic and full system
✅ **Extensible** - Easy to add new tests

## Current Test Status

### Examples Ready
- ✅ loopback_test - Has hardware test code, has testbench
- ⏸️ burst_transfers - Needs implementation

### CI/CD Status
- ✅ Workflow file created
- ⏸️ Needs first push to activate
- ⏸️ May need iverilog setup verification

## Next Steps

1. **Test the framework** - Run `.\run_tests.ps1 -Example loopback_test`
2. **Fix any issues** - Debug hardware/simulation mismatches
3. **Add more examples** - burst_transfers, bram_interface, etc.
4. **Push to GitHub** - Activate CI/CD pipeline
5. **Document results** - Update TEST_RESULTS.md with validated timings

## Lessons Learned

This framework was created to avoid:
- ❌ Manual build/upload cycles
- ❌ Forgotten test steps
- ❌ Inconsistent test conditions
- ❌ Lost test output
- ❌ Difficulty reproducing failures
- ❌ No CI/CD validation

Now we have:
- ✅ One command runs everything
- ✅ Automated and consistent
- ✅ All output saved to logs
- ✅ Easy to reproduce
- ✅ CI/CD catches regressions early
