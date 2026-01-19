# Papilio SPI Slave - Integration Guide

Best practices and patterns for integrating the SPI slave library into your projects.

## Common Integration Patterns

### 1. Simple Loopback

Immediate echo for testing and verification.

**HDL:**
```verilog
wire [7:0] rx_data, tx_data;
wire rx_valid, rx_ready, tx_valid, tx_ready;

spi_slave #(.TRANSFER_WIDTH(8)) spi (
    .clk(sys_clk), .rst(reset),
    .spi_sclk(sck), .spi_mosi(mosi), 
    .spi_miso(miso), .spi_cs_n(cs_n),
    .rx_data(rx_data), .rx_valid(rx_valid), .rx_ready(rx_ready),
    .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready)
);

// Direct loopback
assign tx_data = rx_data;
assign tx_valid = rx_valid;
assign rx_ready = tx_ready;
```

**C++:**
```cpp
PapilioSPI spi;
SPIClass fpgaSPI;
fpgaSPI.begin(SCK, MISO, MOSI, CS);
spi.begin(&fpgaSPI, CS, 1000000);

uint8_t response = spi.transfer8(0x42);
// response should equal 0x42
```

### 2. Buffered Processing

Use internal register to decouple timing.

**HDL:**
```verilog
reg [7:0] process_reg;

always @(posedge clk) begin
    if (rst) begin
        process_reg <= 0;
    end else if (rx_valid && rx_ready) begin
        // Process received data
        process_reg <= rx_data ^ 8'hFF;  // Example: invert
    end
end

assign tx_data = process_reg;
assign tx_valid = 1'b1;  // Always ready
assign rx_ready = 1'b1;
```

### 3. Memory Interface

Sequential memory access with auto-increment.

**HDL:**
```verilog
spi_bram_controller #(
    .DATA_WIDTH(8),
    .MEM_DEPTH(256)
) bram_ctrl (
    .clk(clk), .rst(rst),
    .rx_data(spi_rx_data),
    .rx_valid(spi_rx_valid),
    .rx_ready(spi_rx_ready),
    .tx_data(spi_tx_data),
    .tx_valid(spi_tx_valid),
    .tx_ready(spi_tx_ready)
);
```

**C++ Protocol:**
```cpp
// Write 256 bytes
for (int i = 0; i < 256; i++) {
    spi.transfer8(i);  // Auto-increment after each write
}

// Reset address
spi.transfer8(0xFF);

// Switch to read mode
spi.transfer8(0xFE);

// Read back 256 bytes
for (int i = 0; i < 256; i++) {
    uint8_t data = spi.transfer8(0x00);
    // data should equal i
}
```

### 4. Wishbone Bridge

Register access via SPI.

**Protocol:** `[CMD][ADDR_HI][ADDR_LO][DATA]`

**HDL:**
```verilog
spi_wb_bridge bridge (
    .clk(clk), .rst(rst),
    .spi_sclk(sck), .spi_mosi(mosi),
    .spi_miso(miso), .spi_cs_n(cs_n),
    .wb_adr_o(wb_addr),
    .wb_dat_o(wb_wr_data),
    .wb_dat_i(wb_rd_data),
    .wb_we_o(wb_we),
    .wb_stb_o(wb_stb),
    .wb_cyc_o(wb_cyc),
    .wb_ack_i(wb_ack)
);
```

**C++ Usage:**
```cpp
// Write to register 0x1234
spi.transfer8(0x01);  // CMD_WRITE
spi.transfer8(0x12);  // ADDR_HI
spi.transfer8(0x34);  // ADDR_LO
spi.transfer8(0xAB);  // DATA

// Read from register 0x1234
spi.transfer8(0x02);  // CMD_READ
spi.transfer8(0x12);  // ADDR_HI
spi.transfer8(0x34);  // ADDR_LO
uint8_t data = spi.transfer8(0x00);  // Clock out result
```

### 5. FIFO Streaming

High-throughput data capture (e.g., logic analyzer).

**HDL:**
```verilog
spi_slave_fifo #(
    .TRANSFER_WIDTH(8),
    .RX_FIFO_DEPTH(256),
    .TX_FIFO_DEPTH(256)
) spi_fifo (
    .clk(clk), .rst_n(!rst),
    .spi_sclk(sck), .spi_mosi(mosi),
    .spi_miso(miso), .spi_cs_n(cs_n),
    // RX FIFO - data from SPI
    .rx_fifo_data(app_rx_data),
    .rx_fifo_valid(app_rx_valid),
    .rx_fifo_ready(app_rx_ready),
    // TX FIFO - data to SPI
    .tx_fifo_data(captured_data),
    .tx_fifo_valid(capture_valid),
    .tx_fifo_ready(tx_fifo_ready)
);

// Application: capture data and stream via SPI
always @(posedge clk) begin
    if (capture_enable) begin
        captured_data <= gpio_input;  // Example: capture GPIO
        capture_valid <= 1;
    end
end
```

**C++ Usage:**
```cpp
// Continuous read
uint8_t buffer[256];
spi.transferBurst(nullptr, buffer, 256);  // Read 256 bytes

// Process captured data
for (int i = 0; i < 256; i++) {
    processLogicAnalyzerSample(buffer[i]);
}
```

## Best Practices

### 1. Ready/Valid Handshaking

Always respect backpressure to avoid data loss:

```verilog
always @(posedge clk) begin
    if (rx_valid && rx_ready) begin
        // Only process when both valid and ready
        process_data(rx_data);
    end
end
```

### 2. Reset Handling

Ensure proper reset sequencing:

```verilog
// Power-on reset generator
reg [3:0] reset_counter = 0;
reg rst = 1;

always @(posedge clk) begin
    if (reset_counter != 4'b1111) begin
        reset_counter <= reset_counter + 1;
        rst <= 1;
    end else begin
        rst <= 0;
    end
end
```

### 3. CS Timing

Preload TX data during CS idle:

```verilog
always @(posedge clk) begin
    if (!spi_cs_active) begin
        // CS idle - load new data
        if (tx_valid && tx_ready) begin
            tx_shift <= tx_data;
        end
    end
end
```

### 4. Burst Efficiency

Use `transferBurst()` instead of multiple `transfer8()` calls:

```cpp
// Inefficient - multiple CS toggles
for (int i = 0; i < 100; i++) {
    data[i] = spi.transfer8(i);  // 100 CS cycles
}

// Efficient - single CS cycle
spi.transferBurst(txBuf, rxBuf, 100);  // 1 CS cycle
```

### 5. Error Handling

Check for communication failures:

```cpp
if (!spi.isReady()) {
    Serial.println("FPGA not responding!");
    // Retry or error recovery
}

// Validate loopback
uint8_t sent = 0xA5;
uint8_t received = spi.transfer8(sent);
if (received != sent) {
    Serial.println("Communication error!");
}
```

## Multi-Instance Designs

### Multiple SPI Slaves

Each with dedicated CS:

```verilog
// Instance 1 - Loopback
spi_slave #(.TRANSFER_WIDTH(8)) spi1 (
    .clk(clk), .rst(rst),
    .spi_sclk(sck), .spi_mosi(mosi), 
    .spi_miso(miso1), .spi_cs_n(cs1_n),
    // ...
);

// Instance 2 - BRAM
spi_slave #(.TRANSFER_WIDTH(8)) spi2 (
    .clk(clk), .rst(rst),
    .spi_sclk(sck), .spi_mosi(mosi),
    .spi_miso(miso2), .spi_cs_n(cs2_n),
    // ...
);

// MISO multiplexing
assign miso = !cs1_n ? miso1 : 
              !cs2_n ? miso2 : 1'bz;
```

**C++ Access:**
```cpp
PapilioSPI spi1, spi2;
spi1.begin(&SPI, CS1_PIN, 1000000);
spi2.begin(&SPI, CS2_PIN, 1000000);

// Independent access
uint8_t resp1 = spi1.transfer8(0x42);
uint8_t resp2 = spi2.transfer8(0x99);
```

## Performance Optimization

### 1. Clock Frequency

Higher system clock allows higher SPI speed:

| System Clock | Max SPI Speed | Margin |
|--------------|---------------|--------|
| 27 MHz | 4 MHz | 6.75× |
| 50 MHz | 7.4 MHz | 6.75× |
| 100 MHz | 14.8 MHz | 6.75× |

### 2. FIFO Depth Selection

Balance resource usage vs buffering:

```verilog
// Minimal (32 entries) - Low latency, less buffering
localparam FIFO_DEPTH = 32;

// Standard (256 entries) - Good balance
localparam FIFO_DEPTH = 256;

// Large (1024 entries) - High throughput
localparam FIFO_DEPTH = 1024;
```

### 3. DMA-Style Transfers

Minimize CPU involvement:

```cpp
// Setup TX buffer once
uint8_t txBuf[1024];
prepareTransmitData(txBuf, 1024);

// Efficient burst with minimal overhead
spi.transferBurst(txBuf, rxBuf, 1024);
```

## Debugging Tips

### 1. Logic Analyzer

Capture SPI signals for timing analysis:
- CS, SCK, MOSI, MISO
- Look for proper timing relationships
- Verify CS setup/hold times

### 2. Loopback First

Always start with loopback mode:
```cpp
uint8_t test = 0xA5;
uint8_t result = spi.transfer8(test);
if (result != test) {
    Serial.println("Hardware issue!");
}
```

### 3. Speed Stepping

If failures occur, reduce speed:
```cpp
uint32_t speeds[] = {100000, 500000, 1000000, 2000000, 4000000};
for (int i = 0; i < 5; i++) {
    spi.setSpeed(speeds[i]);
    if (testCommunication()) {
        Serial.printf("Working at %d Hz\n", speeds[i]);
    } else {
        Serial.printf("Failed at %d Hz\n", speeds[i]);
        break;
    }
}
```

### 4. Pattern Testing

Test various bit patterns:
```cpp
uint8_t patterns[] = {0x00, 0xFF, 0xAA, 0x55, 0x0F, 0xF0};
for (uint8_t pattern : patterns) {
    uint8_t result = spi.transfer8(pattern);
    Serial.printf("0x%02X → 0x%02X\n", pattern, result);
}
```

## Common Pitfalls

### 1. TX Data Not Preloaded
**Problem:** First bit incorrect  
**Solution:** Load TX data during CS idle

### 2. Ignoring Backpressure
**Problem:** Data loss  
**Solution:** Check rx_ready before processing

### 3. Wrong Bit Width
**Problem:** Garbled data  
**Solution:** Match TRANSFER_WIDTH in HDL and C++

### 4. Insufficient System Clock
**Problem:** Timing violations at high SPI speed  
**Solution:** Increase system clock or reduce SPI speed

### 5. No CDC Synchronization
**Problem:** Metastability, random errors  
**Solution:** Use provided modules with built-in CDC

## See Also

- [API Reference](API_REFERENCE.md) - Complete interface documentation
- [Timing Specifications](TIMING_SPECS.md) - Speed limits and requirements
- [Examples](../examples/) - Working integration examples
- [Test Results](TEST_RESULTS.md) - Validation data
