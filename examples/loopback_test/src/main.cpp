// Loopback Test - ESP32 Side
// Tests basic SPI communication with echo validation
// Part of Papilio SPI Slave Library

#include <Arduino.h>
#include <PapilioSPI.h>

// SPI Configuration
#define SPI_CLK   1
#define SPI_MOSI  2
#define SPI_MISO  4
#define SPI_CS    3

PapilioSPI spi;

void setup() {
  Serial.begin(115200);
  delay(500);
  
  Serial.println("\n=== Papilio SPI Slave - Loopback Test ===\n");
  
  // Initialize SPI
  SPIClass fpgaSPI;
  fpgaSPI.begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);
  
  if (!spi.begin(&fpgaSPI, SPI_CS, 1000000, SPI_MODE1)) {
    Serial.println("SPI initialization failed!");
    return;
  }
  
  Serial.println("SPI initialized at 1 MHz");
  delay(100);
  
  // Clear any power-on garbage from FPGA - send a few dummy transactions
  for (int i = 0; i < 3; i++) {
    spi.transfer8(0x00);
    delay(10);
  }
  
  // Test patterns
  uint8_t patterns[] = {0x00, 0xFF, 0xAA, 0x55, 0x0F, 0xF0, 0x12, 0x34};
  int passed = 0, failed = 0;
  
  // Single byte tests (with proper loopback logic)
  Serial.println("\n--- Single Byte Tests ---");
  
  // Prime the pump - send first pattern, discard result
  spi.transfer8(patterns[0]);
  
  // Test remaining patterns - should receive previous pattern
  for (int i = 1; i < sizeof(patterns); i++) {
    uint8_t sent = patterns[i];
    uint8_t received = spi.transfer8(sent);
    uint8_t expected = patterns[i-1];
    
    if (received == expected) {
      Serial.printf("✓ Pattern 0x%02X → 0x%02X (loopback of previous)\n", sent, received);
      passed++;
    } else {
      Serial.printf("✗ Pattern 0x%02X → 0x%02X (expected 0x%02X from previous)\n", sent, received, expected);
      failed++;
    }
    delay(10);
  }
  
  // Clear residual data before burst test and prime for first transfer
  for (int i = 0; i < 3; i++) {
    spi.transfer8(0x00);
    delay(10);
  }
  
  // Burst test (also needs to account for shift)
  // Send as individual transactions (CS toggles between bytes)
  Serial.println("\n--- Burst Transfer Test ---");
  uint8_t txBuf[11], rxBuf[11];
  for (int i = 0; i < 11; i++) txBuf[i] = i;
  
  // Prime the burst - send first value, discard result (will be 0x00 from clearing)
  spi.transfer8(txBuf[0]);
  delay(10);
  
  // Send remaining bytes - each should receive the previous value
  for (int i = 1; i < 11; i++) {
    rxBuf[i] = spi.transfer8(txBuf[i]);
    delay(10);
  }
  
  bool burstOk = true;
  // Check that rx[i] == tx[i-1] (we receive previous value)
  // Since we primed with txBuf[0], rxBuf[1] should be txBuf[0], rxBuf[2] should be txBuf[1], etc.
  for (int i = 1; i < 11; i++) {
    if (rxBuf[i] != txBuf[i-1]) {
      burstOk = false;
      Serial.printf("  Burst mismatch at index %d: got 0x%02X, expected 0x%02X\n", i, rxBuf[i], txBuf[i-1]);
      break;
    }
  }
  
  if (burstOk) {
    Serial.println("✓ Burst transfer (10 bytes verified) - All matched!");
    passed++;
  } else {
    Serial.println("✗ Burst transfer - Mismatch detected");
    failed++;
  }
  
  // Summary
  Serial.println("\n=== Test Summary ===");
  Serial.printf("Passed: %d\n", passed);
  Serial.printf("Failed: %d\n", failed);
  
  if (failed == 0) {
    Serial.println("\n✓ ALL TESTS PASSED!");
  } else {
    Serial.println("\n✗ SOME TESTS FAILED");
  }
}

void loop() {
  delay(5000);
  Serial.println("\nRestarting tests...\n");
  ESP.restart();
}
