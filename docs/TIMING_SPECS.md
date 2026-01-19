# Papilio SPI Slave - Timing Specifications

Detailed timing analysis and speed limits for the SPI slave library.

## Maximum Validated Speeds

Based on extensive hardware testing with 27 MHz system clock:

| SPI Clock | System Cycles per Edge | Status | Notes |
|-----------|------------------------|--------|-------|
| 100 kHz | 135 | ✅ Pass | Very safe, recommended for initial testing |
| 500 kHz | 27 | ✅ Pass | Safe with good margins |
| 1 MHz | 13.5 | ✅ Pass | Reliable for most applications |
| 2 MHz | 6.75 | ✅ Pass | Good balance of speed and reliability |
| 4 MHz | 3.375 | ✅ Pass | Maximum validated speed |
| 8 MHz | 1.6875 | ❌ Fail | Timing violation - insufficient CDC time |

**Recommendation:** 
- **Production**: 4 MHz maximum
- **With margin**: 2 MHz  
- **Development/debug**: 1 MHz or lower

## Timing Constraints

### Clock Domain Crossing (CDC)

The SPI signals are asynchronous to the system clock and require synchronization:

**Method:** Dual-register synchronization (industry standard)
```verilog
reg spi_sclk_d1, spi_sclk_d2, spi_sclk_d3;

always @(posedge clk) begin
    spi_sclk_d1 <= spi_sclk;    // Stage 1 - may go metastable
    spi_sclk_d2 <= spi_sclk_d1; // Stage 2 - resolved
    spi_sclk_d3 <= spi_sclk_d2; // Stage 3 - for edge detection
end
```

**Latency:** 2 system clock cycles minimum for metastability resolution

**Why 8 MHz fails:**
- Each SPI edge requires ~2 system clocks for CDC
- At 8 MHz SPI with 27 MHz system clock: only 1.6875 cycles available
- Insufficient time for proper synchronization
- Results in bit errors and data corruption

### Setup and Hold Times

#### TX Data Setup Time
**Requirement:** TX data must be loaded BEFORE CS goes active

```
        _______________          _______________
CS     /               \________/               \
                        ^
                        |
                    Load TX data here
                    (during CS high)
```

**Why:** The first bit must be ready on MISO when CS asserts. Loading during transaction causes the first bit to be incorrect.

**Code pattern:**
```cpp
// Correct - preload before CS
spi.transfer8(0x42);  // Library handles CS timing

// In HDL loopback:
always @(posedge clk) begin
    if (!spi_cs_active && tx_valid) begin
        tx_shift <= tx_data;  // Load during CS idle
    end
end
```

#### RX Data Hold Time
**Characteristic:** RX data held until next word complete

Data remains stable on `rx_data` until `rx_valid` strobes again, providing ample hold time for application logic.

### Transaction Timing

#### Minimum CS Pulse Width
**Requirement:** At least 1 complete SPI clock cycle (HIGH + LOW)

For 8-bit transfer at 4 MHz:
- 8 bits × 250ns = 2μs minimum
- Plus setup/hold margins: ~2.5μs total

#### Inter-Transaction Gap
**Requirement:** Minimum 2 system clock cycles between CS edges

At 27 MHz: 74ns minimum gap

**Typical:** Most microcontrollers provide 100ns+ gap naturally through software overhead.

### Signal Timing Diagrams

#### Mode 0 Timing (CPOL=0, CPHA=0)

```
        ___     ___     ___     ___     ___     ___
SCK  __|   |___|   |___|   |___|   |___|   |___|   |___

CS   ______________________________________/ ...
        ^                                       ^
        |                                       |
     Sample MOSI                            Sample MOSI
     Shift MISO                             Shift MISO
     
MOSI ----<D7>---<D6>---<D5>---<D4>---<D3>---<D2>---...

MISO ----<D7>---<D6>---<D5>---<D4>---<D3>---<D2>---...
```

**Sampling:**
- MOSI sampled on SCK rising edge (after CDC)
- MISO shifted on SCK falling edge (setup for master sampling)

#### Full-Duplex Timing

Both directions operate simultaneously:
```
Master TX → MOSI → FPGA RX
Master RX ← MISO ← FPGA TX
```

This is why Mode 1 masters work best - their shift timing aligns with slave output timing.

## System Clock Requirements

### Minimum System Clock Frequency

For reliable operation at desired SPI speed:

**Formula:** `f_sys ≥ f_spi × 6.75`

Examples:
- 4 MHz SPI → 27 MHz system (6.75× margin) ✅
- 2 MHz SPI → 13.5 MHz system (6.75× margin) ✅
- 8 MHz SPI → 54 MHz system would be needed ⚠️

**Why 6.75 cycles:**
- 2 cycles for CDC synchronization
- 1-2 cycles for edge detection logic
- 1-2 cycles for state machine processing
- ~1.75 cycles margin for routing and jitter

### Clock Stability

**Requirement:** ±100 ppm or better

Both system clock and SPI clock should be derived from stable sources:
- Crystal oscillators preferred
- RC oscillators acceptable at lower speeds (<1 MHz)
- PLL-generated clocks acceptable if low jitter

## Resource Utilization vs Speed

FPGA resource usage is independent of SPI speed (combinational logic only for protocol):

| Module | LUTs | FFs | BRAM | Max Speed Impact |
|--------|------|-----|------|------------------|
| spi_slave (8-bit) | ~100 | ~50 | 0 | None |
| spi_slave (32-bit) | ~150 | ~100 | 0 | None |
| spi_slave_fifo | +100 | +100 | 2 | FIFO depth affects routing |

**Speed determined by:** System clock frequency, not module complexity.

## Power Consumption

Approximate power at different speeds (Gowin GW1NSR-LV4C):

| SPI Speed | Active Current | Notes |
|-----------|----------------|-------|
| 100 kHz | ~5 mA | Minimal activity |
| 1 MHz | ~8 mA | Low speed operation |
| 4 MHz | ~12 mA | Validated maximum |

**Note:** Actual power depends on application logic, not just SPI speed.

## Temperature and Voltage Effects

### Operating Range
- **Temperature:** -40°C to +85°C (industrial)
- **Voltage:** 3.3V ±10% (check FPGA datasheet)

### Derating
At temperature/voltage extremes, consider reducing maximum speed:
- **High temp (>70°C):** Use 2 MHz max
- **Low voltage (<3.0V):** Use 2 MHz max
- **Both:** Use 1 MHz max

## Testing and Validation

### Speed Validation Procedure

1. Start at 100 kHz - verify basic communication
2. Increase to 500 kHz - verify patterns
3. Increase to 1 MHz - run burst tests
4. Increase to 2 MHz - extended operation (1000+ transfers)
5. Increase to 4 MHz - final validation
6. Test at 8 MHz - should fail (confirms limits)

Use `examples/speed_validation` for automated testing.

### Margin Testing

For production qualification:
- Test at 4.5 MHz (10% over max) - should still pass
- Test at temperature extremes
- Test with power supply variations
- Extended duration testing (hours)

## Troubleshooting Timing Issues

### Symptoms and Solutions

**Bit errors at high speed:**
- Reduce SPI clock frequency
- Verify system clock stability
- Check signal integrity (scope waveforms)
- Reduce trace lengths
- Add ground plane

**Intermittent failures:**
- Check power supply noise
- Verify clock source stability
- Test at different times of day (temperature)
- Check for EMI sources

**First byte always wrong:**
- TX data not loaded before CS active
- Fix timing in application code
- Use ready/valid handshaking properly

**Random data corruption:**
- Insufficient CDC synchronization
- System clock too slow for SPI speed
- Signal integrity issues (reflections, ringing)

## See Also

- [API Reference](API_REFERENCE.md) - Interface documentation
- [Test Results](TEST_RESULTS.md) - Detailed validation data
- [Integration Guide](INTEGRATION_GUIDE.md) - Best practices
- [Examples](../examples/speed_validation/) - Speed testing code
