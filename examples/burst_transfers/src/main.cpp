// Burst Transfer Test - ESP32 Side
// Tests high-throughput burst transfers at various speeds and bit widths
// Demonstrates the loopback performance of the FPGA
//
// IMPORTANT: The FPGA top.v TRANSFER_WIDTH must match the test mode below
// For 16-bit tests: Set FPGA TRANSFER_WIDTH = 16
// For 32-bit tests: Set FPGA TRANSFER_WIDTH = 32
#include <Arduino.h>
#include <SPI.h>
#include <PapilioSPI.h>

// SPI Configuration
#define SPI_CLK   1
#define SPI_MOSI  2
#define SPI_MISO  4
#define SPI_CS    3

// =========================================================================
// Configuration - Change this to match FPGA bit width
// =========================================================================
#define TEST_BIT_WIDTH 32  // 8, 16, or 32 (must match FPGA TRANSFER_WIDTH)
// =========================================================================

SPIClass fpgaSPI(HSPI);
PapilioSPI spi;

// Forward declarations
void testBurstAtSpeed_8bit(uint32_t speed_hz, const char* label);
void testBurstAtSpeed_16bit(uint32_t speed_hz, const char* label);
void testBurstAtSpeed_32bit(uint32_t speed_hz, const char* label);

// Global counters for test results
int total_passed = 0;
int total_failed = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== Papilio SPI Slave - Burst Transfer Test ===\n");
  
#if TEST_BIT_WIDTH == 8
  Serial.println("Mode: 8-bit transfers (byte-level)");
#elif TEST_BIT_WIDTH == 16
  Serial.println("Mode: 16-bit transfers (for audio/RGB565 video)");
#elif TEST_BIT_WIDTH == 32
  Serial.println("Mode: 32-bit transfers (for RGB888/float audio/high-res data)");
#endif
  
  Serial.println("IMPORTANT: Ensure FPGA TRANSFER_WIDTH matches this setting!\n");
  
  // Initialize SPIClass first
  fpgaSPI.begin(SPI_CLK, SPI_MISO, SPI_MOSI, SPI_CS);
  
  // Initialize PapilioSPI wrapper at 1 MHz for setup
  if (!spi.begin(&fpgaSPI, SPI_CS, 1000000, SPI_MODE1)) {
    Serial.println("ERROR: Failed to initialize SPI");
    while(1) delay(1000);
  }
  
  Serial.println("Testing burst transfers at different speeds...\n");
  
  // Test at increasing speeds
#if TEST_BIT_WIDTH == 8
  testBurstAtSpeed_8bit(1000000, "1 MHz");
  testBurstAtSpeed_8bit(2000000, "2 MHz");
  testBurstAtSpeed_8bit(4000000, "4 MHz");
  testBurstAtSpeed_8bit(8000000, "8 MHz");
#elif TEST_BIT_WIDTH == 16
  testBurstAtSpeed_16bit(1000000, "1 MHz");
  testBurstAtSpeed_16bit(2000000, "2 MHz");
  testBurstAtSpeed_16bit(4000000, "4 MHz");
  testBurstAtSpeed_16bit(8000000, "8 MHz");
#elif TEST_BIT_WIDTH == 32
  testBurstAtSpeed_32bit(1000000, "1 MHz");
  testBurstAtSpeed_32bit(2000000, "2 MHz");
  testBurstAtSpeed_32bit(4000000, "4 MHz");
#endif
  
  Serial.println("\n=== All Burst Tests Complete ===\n");
  
  // Print summary
  Serial.printf("=== Test Summary ===\n");
  Serial.printf("Passed: %d\n", total_passed);
  Serial.printf("Failed: %d\n", total_failed);
  Serial.println();
  
  if (total_failed == 0) {
    Serial.println("✓ ALL TESTS PASSED!");
  } else {
    Serial.println("✗ SOME TESTS FAILED");
  }
}

void loop() {
  delay(5000);
  Serial.println("\nRestarting tests...\n");
  ESP.restart();
}

// =========================================================================
// 8-bit Burst Tests
// =========================================================================
void testBurstAtSpeed_8bit(uint32_t speed_hz, const char* label) {
  const int BURST_SIZE = 256;
  uint8_t tx_data[BURST_SIZE + 1];  // +1 to prime the pump
  uint8_t rx_data[BURST_SIZE + 1];
  
  spi.setSpeed(speed_hz);
  Serial.printf("=== Testing at %s (8-bit) ===\n", label);
  
  // Generate test pattern
  for (int i = 0; i <= BURST_SIZE; i++) {
    tx_data[i] = i & 0xFF;
  }
  
  unsigned long start_time = micros();
  
  // Transfer all bytes
  for (int i = 0; i <= BURST_SIZE; i++) {
    rx_data[i] = spi.transfer8(tx_data[i]);
    delayMicroseconds(50);
  }
  
  unsigned long elapsed = micros() - start_time;
  
  // Verify loopback
  int passed = 0, failed = 0;
  for (int i = 1; i <= BURST_SIZE; i++) {
    if (rx_data[i] == tx_data[i-1]) {
      passed++;
    } else {
      if (failed == 0) {
        Serial.printf("  First error at [%3d]: Got 0x%02X (expected 0x%02X)\n",
                      i, rx_data[i], tx_data[i-1]);
      }
      failed++;
    }
  }
  
  float kbytes_per_sec = (BURST_SIZE * 1000000.0) / elapsed / 1024.0;
  
  if (failed == 0) {
    Serial.printf("✓ PASSED: %d/%d bytes verified (%.2f KB/s)\n\n", passed, BURST_SIZE, kbytes_per_sec);
    total_passed += BURST_SIZE;
  } else {
    Serial.printf("✗ FAILED: %d passed, %d failed\n\n", passed, failed);
    total_passed += passed;
    total_failed += failed;
  }
}

// =========================================================================
// 16-bit Burst Tests
// =========================================================================
void testBurstAtSpeed_16bit(uint32_t speed_hz, const char* label) {
  const int BURST_SIZE = 256;
  uint16_t tx_data[BURST_SIZE + 1];  // +1 to prime the pump
  uint16_t rx_data[BURST_SIZE + 1];
  
  spi.setSpeed(speed_hz);
  Serial.printf("=== Testing at %s (16-bit) ===\n", label);
  
  // Generate test pattern
  for (int i = 0; i <= BURST_SIZE; i++) {
    tx_data[i] = 0xA000 + i;  // Recognizable pattern
  }
  
  unsigned long start_time = micros();
  
  // Transfer all words
  for (int i = 0; i <= BURST_SIZE; i++) {
    rx_data[i] = spi.transfer16(tx_data[i]);
    delayMicroseconds(50);
  }
  
  unsigned long elapsed = micros() - start_time;
  
  // Verify loopback
  int passed = 0, failed = 0;
  for (int i = 1; i <= BURST_SIZE; i++) {
    if (rx_data[i] == tx_data[i-1]) {
      passed++;
    } else {
      if (failed == 0) {
        Serial.printf("  First error at [%3d]: Got 0x%04X (expected 0x%04X)\n",
                      i, rx_data[i], tx_data[i-1]);
      }
      failed++;
    }
  }
  
  float kbytes_per_sec = (BURST_SIZE * 2 * 1000000.0) / elapsed / 1024.0;
  
  if (failed == 0) {
    Serial.printf("✓ PASSED: %d/%d words verified (%.2f KB/s)\n\n", passed, BURST_SIZE, kbytes_per_sec);
    total_passed += BURST_SIZE;
  } else {
    Serial.printf("✗ FAILED: %d passed, %d failed\n\n", passed, failed);
    total_passed += passed;
    total_failed += failed;
  }
}

// =========================================================================
// 32-bit Burst Tests
// =========================================================================
void testBurstAtSpeed_32bit(uint32_t speed_hz, const char* label) {
  const int BURST_SIZE = 256;
  uint32_t tx_data[BURST_SIZE + 1];  // +1 to prime the pump
  uint32_t rx_data[BURST_SIZE + 1];
  
  spi.setSpeed(speed_hz);
  Serial.printf("=== Testing at %s (32-bit) ===\n", label);
  
  // Generate test pattern
  for (int i = 0; i <= BURST_SIZE; i++) {
    tx_data[i] = 0xDEAD0000 + i;  // Recognizable pattern
  }
  
  unsigned long start_time = micros();
  
  // Transfer all words
  for (int i = 0; i <= BURST_SIZE; i++) {
    rx_data[i] = spi.transfer32(tx_data[i]);
    delayMicroseconds(50);
  }
  
  unsigned long elapsed = micros() - start_time;
  
  // Verify loopback
  int passed = 0, failed = 0;
  for (int i = 1; i <= BURST_SIZE; i++) {
    if (rx_data[i] == tx_data[i-1]) {
      passed++;
    } else {
      if (failed == 0) {
        Serial.printf("  First error at [%3d]: Got 0x%08X (expected 0x%08X)\n",
                      i, rx_data[i], tx_data[i-1]);
      }
      failed++;
    }
  }
  
  float kbytes_per_sec = (BURST_SIZE * 4 * 1000000.0) / elapsed / 1024.0;
  
  if (failed == 0) {
    Serial.printf("✓ PASSED: %d/%d dwords verified (%.2f KB/s)\n\n", passed, BURST_SIZE, kbytes_per_sec);
    total_passed += BURST_SIZE;
  } else {
    Serial.printf("✗ FAILED: %d passed, %d failed\n\n", passed, failed);
    total_passed += passed;
    total_failed += failed;
  }
}















