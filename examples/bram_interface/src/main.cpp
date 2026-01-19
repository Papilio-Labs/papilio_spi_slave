// BRAM Interface Test - ESP32 Side
// Tests Block RAM memory access via SPI
// Writes test pattern, reads back, verifies

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
  
  Serial.println("\n=== Papilio SPI Slave - BRAM Interface Test ===\n");
  
  // Initialize SPI
  SPIClass fpgaSPI;
  fpgaSPI.begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);
  spi.begin(&fpgaSPI, SPI_CS, 1000000, SPI_MODE1);
  
  Serial.println("SPI initialized at 1 MHz");
  delay(100);
  
  // Test parameters
  const int TEST_SIZE = 256;
  uint8_t writeData[TEST_SIZE];
  uint8_t readData[TEST_SIZE];
  
  // Generate test pattern
  for (int i = 0; i < TEST_SIZE; i++) {
    uint8_t val = i;
    // Avoid command bytes
    if (val == 0xFE || val == 0xFF) {
      val = 0xFD;
    }
    writeData[i] = val;
  }
  
  Serial.println("\n--- Phase 1: Write to BRAM ---");
  
  // Reset address to 0 (write mode)
  spi.transfer8(0xFF);
  Serial.println("Sent 0xFF to reset address");
  delay(10);
  
  // Write data
  Serial.println("Writing 256 bytes...");
  for (int i = 0; i < TEST_SIZE; i++) {
    spi.transfer8(writeData[i]);
    delayMicroseconds(50);  // CS high time for FIFO to settle
    if (i < 4 || i >= TEST_SIZE - 4) {
      Serial.printf("  [%3d] Wrote 0x%02X\n", i, writeData[i]);
    } else if (i == 4) {
      Serial.println("  ...");
    }
  }
  Serial.println("Write complete");
  delay(10);
  
  Serial.println("\n--- Phase 2: Read from BRAM ---");
  
  // Reset address and enter read mode
  spi.transfer8(0xFF);  // Reset address
  delayMicroseconds(50);
  spi.transfer8(0xFE);  // Enter read mode
  delayMicroseconds(50);
  Serial.println("Sent 0xFE to enter read mode");
  delay(10);
  
  // Read data (send dummy bytes)
  Serial.println("Reading 256 bytes...");
  for (int i = 0; i < TEST_SIZE; i++) {
    readData[i] = spi.transfer8(0x00);
    delayMicroseconds(50);  // CS high time for FIFO to settle
    if (i < 4 || i >= TEST_SIZE - 4) {
      Serial.printf("  [%3d] Read 0x%02X (expected 0x%02X)\n", 
                    i, readData[i], writeData[i]);
    } else if (i == 4) {
      Serial.println("  ...");
    }
  }
  Serial.println("Read complete");
  
  Serial.println("\n--- Phase 3: Verify ---");
  
  int passed = 0;
  int failed = 0;
  
  for (int i = 0; i < TEST_SIZE; i++) {
    if (readData[i] == writeData[i]) {
      passed++;
    } else {
      failed++;
      if (failed <= 10) {
        Serial.printf("  [%3d] MISMATCH: Wrote 0x%02X, Read 0x%02X\n",
                      i, writeData[i], readData[i]);
      }
    }
  }
  
  Serial.println("\n=== Test Summary ===");
  Serial.printf("Passed: %d\n", passed);
  Serial.printf("Failed: %d\n", failed);
  
  if (failed == 0) {
    Serial.println("\n✓ ALL TESTS PASSED!");
    Serial.println("  • 256-byte BRAM working correctly");
    Serial.println("  • Auto-increment addressing working");
    Serial.println("  • Command protocol working (0xFF reset, 0xFE read)");
  } else {
    Serial.println("\n✗ SOME TESTS FAILED");
  }
}

void loop() {
  delay(5000);
  Serial.println("\nRestarting tests...\n");
  ESP.restart();
}
