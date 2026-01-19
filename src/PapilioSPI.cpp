// PapilioSPI.cpp - Implementation
// 
// Simple SPI slave communication library for Papilio FPGA modules.
//
// Author: Papilio Labs
// Date: January 4, 2026
// License: MIT

#include "PapilioSPI.h"

// Constructor
PapilioSPI::PapilioSPI() : 
    _spi(nullptr),
    _cs(-1),
    _speed(1000000),
    _mode(SPI_MODE0),
    _bitWidth(8),
    _initialized(false)
{
}

// Initialize SPI interface
bool PapilioSPI::begin(SPIClass* spi, int cs_pin, uint32_t speed, uint8_t mode) {
    _spi = spi;
    _cs = cs_pin;
    _speed = speed;
    _mode = mode;
    _bitWidth = 8;  // Default to 8-bit
    
    // Configure CS pin
    pinMode(_cs, OUTPUT);
    digitalWrite(_cs, HIGH);  // CS idle high
    
    _initialized = true;
    return true;
}

// Release SPI interface
void PapilioSPI::end() {
    _initialized = false;
    _spi = nullptr;
}

// 8-bit transfer
uint8_t PapilioSPI::transfer8(uint8_t data) {
    if (!_initialized || !_spi) return 0;
    
    uint8_t result;
    _beginTransaction();
    _csLow();
    result = _spi->transfer(data);
    _csHigh();
    _endTransaction();
    
    return result;
}

// 16-bit transfer (MSB first)
uint16_t PapilioSPI::transfer16(uint16_t data) {
    if (!_initialized || !_spi) return 0;
    
    uint16_t result;
    _beginTransaction();
    _csLow();
    
    // Send/receive high byte first
    uint8_t high = _spi->transfer((data >> 8) & 0xFF);
    uint8_t low = _spi->transfer(data & 0xFF);
    
    _csHigh();
    _endTransaction();
    
    result = ((uint16_t)high << 8) | low;
    return result;
}

// 32-bit transfer (MSB first)
uint32_t PapilioSPI::transfer32(uint32_t data) {
    if (!_initialized || !_spi) return 0;
    
    uint32_t result;
    _beginTransaction();
    _csLow();
    
    // Send/receive bytes in big-endian order
    uint8_t b3 = _spi->transfer((data >> 24) & 0xFF);
    uint8_t b2 = _spi->transfer((data >> 16) & 0xFF);
    uint8_t b1 = _spi->transfer((data >> 8) & 0xFF);
    uint8_t b0 = _spi->transfer(data & 0xFF);
    
    _csHigh();
    _endTransaction();
    
    result = ((uint32_t)b3 << 24) | ((uint32_t)b2 << 16) | 
             ((uint32_t)b1 << 8) | b0;
    return result;
}

// Burst transfer - efficient for multiple bytes
void PapilioSPI::transferBurst(const uint8_t* txBuf, uint8_t* rxBuf, size_t len) {
    if (!_initialized || !_spi || len == 0) return;
    
    _beginTransaction();
    _csLow();
    
    for (size_t i = 0; i < len; i++) {
        uint8_t txByte = txBuf ? txBuf[i] : 0x00;
        uint8_t rxByte = _spi->transfer(txByte);
        if (rxBuf) {
            rxBuf[i] = rxByte;
        }
    }
    
    _csHigh();
    _endTransaction();
}

// Set bit width (8, 16, or 32)
void PapilioSPI::setBitWidth(uint8_t width) {
    if (width == 8 || width == 16 || width == 32) {
        _bitWidth = width;
    }
}

// Set SPI speed
void PapilioSPI::setSpeed(uint32_t hz) {
    _speed = hz;
}

// Set SPI mode
void PapilioSPI::setMode(uint8_t mode) {
    if (mode <= SPI_MODE3) {
        _mode = mode;
    }
}

// Check if any data available (basic heuristic)
// Note: This is a simplified implementation. For true FIFO status,
// you would need a status register in your FPGA design.
int PapilioSPI::rxAvailable() {
    // Placeholder - would need protocol support on FPGA side
    // For now, return 0 (not implemented)
    return 0;
}

// Check if TX ready (basic heuristic)
bool PapilioSPI::txReady() {
    // Placeholder - would need protocol support on FPGA side
    // For now, always return true
    return true;
}

// Read one byte from FIFO
uint8_t PapilioSPI::readFifo() {
    return transfer8(0x00);
}

// Write one byte to FIFO
void PapilioSPI::writeFifo(uint8_t data) {
    transfer8(data);
}

// Check if FPGA is responding
bool PapilioSPI::isReady() {
    if (!_initialized || !_spi) return false;
    
    // Perform a simple loopback test with known pattern
    uint8_t testPattern = 0xA5;
    uint8_t response = transfer8(testPattern);
    
    // In loopback mode, should echo back
    // In other modes, may return different data
    // This is a basic check - enhance based on your protocol
    return true;  // Optimistic - can be enhanced
}

// Internal: Begin SPI transaction
void PapilioSPI::_beginTransaction() {
    if (_spi) {
        _spi->beginTransaction(SPISettings(_speed, MSBFIRST, _mode));
    }
}

// Internal: End SPI transaction
void PapilioSPI::_endTransaction() {
    if (_spi) {
        _spi->endTransaction();
    }
}

// Internal: Assert CS (active low)
void PapilioSPI::_csLow() {
    digitalWrite(_cs, LOW);
    delayMicroseconds(1);  // Small delay for setup time
}

// Internal: Deassert CS (idle high)
void PapilioSPI::_csHigh() {
    delayMicroseconds(1);  // Small delay before releasing
    digitalWrite(_cs, HIGH);
}
