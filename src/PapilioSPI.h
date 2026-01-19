// PapilioSPI.h - Simple SPI slave communication library
// 
// Provides Arduino-style API for communicating with Papilio SPI slave modules.
// Supports 8/16/32-bit transfers, burst mode, and FIFO status monitoring.
//
// Author: Papilio Labs
// Date: January 4, 2026
// License: MIT

#ifndef PAPILIOSPI_H
#define PAPILIOSPI_H

#include <Arduino.h>
#include <SPI.h>

class PapilioSPI {
public:
    // Constructor
    PapilioSPI();
    
    // Initialization and configuration
    bool begin(SPIClass* spi = &SPI, int cs_pin = SS, uint32_t speed = 1000000, uint8_t mode = SPI_MODE0);
    void end();
    
    // Basic transfer methods
    uint8_t transfer8(uint8_t data);
    uint16_t transfer16(uint16_t data);
    uint32_t transfer32(uint32_t data);
    
    // Burst transfer (multiple bytes)
    void transferBurst(const uint8_t* txBuf, uint8_t* rxBuf, size_t len);
    
    // Configuration
    void setBitWidth(uint8_t width);  // 8, 16, or 32
    void setSpeed(uint32_t hz);
    void setMode(uint8_t mode);       // SPI_MODE0, SPI_MODE1, etc.
    
    // FIFO operations (if using spi_slave_fifo on FPGA side)
    // Note: These are convenience methods for common patterns
    // For simple modules without FIFO, use basic transfer methods
    int rxAvailable();        // Returns estimated bytes available (based on protocol)
    bool txReady();           // Returns true if ready to send
    uint8_t readFifo();       // Read one byte from RX FIFO
    void writeFifo(uint8_t data);  // Write one byte to TX FIFO
    
    // Utility
    bool isReady();           // Check if FPGA is responding
    
private:
    SPIClass* _spi;
    int _cs;
    uint32_t _speed;
    uint8_t _mode;
    uint8_t _bitWidth;
    bool _initialized;
    
    // Internal helpers
    void _beginTransaction();
    void _endTransaction();
    void _csLow();
    void _csHigh();
};

#endif // PAPILIOSPI_H
