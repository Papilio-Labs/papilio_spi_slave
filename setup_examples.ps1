# Script to complete papilio_spi_slave library examples setup
# Copies files and creates placeholders for all 6 examples

Write-Host "Setting up Papilio SPI Slave library examples..." -ForegroundColor Cyan

$baseDir = "c:\development\dev_wishbone_bus"
$libDir = "$baseDir\libs\papilio_spi_slave"
$examplesDir = "$libDir\examples"

# Copy constraint files to all examples
$examples = @('loopback_test', 'burst_transfers', 'bram_interface', 'speed_validation', 'wishbone_bridge', 'logic_analyzer')

foreach ($ex in $examples) {
    Write-Host "Setting up $ex..." -ForegroundColor Yellow
    
    # Copy constraints if not exists
    $constraintSrc = "$baseDir\fpga\constraints\spi_pins.cst"
    $constraintDst = "$examplesDir\$ex\constraints\spi_pins.cst"
    if (!(Test-Path $constraintDst)) {
        Copy-Item $constraintSrc $constraintDst -Force
        Write-Host "  - Copied constraint file" -ForegroundColor Green
    }
    
    # Create platformio.ini for each example
    $platformioContent = @"
[env:esp32-s3-devkitc-1]
platform = espressif32
board = esp32-s3-devkitc-1
framework = arduino
monitor_speed = 115200
lib_deps = 
    papilio_spi_slave
"@
    
    $platformioPath = "$examplesDir\$ex\platformio.ini"
    if (!(Test-Path $platformioPath)) {
        Set-Content -Path $platformioPath -Value $platformioContent
        Write-Host "  - Created platformio.ini" -ForegroundColor Green
    }
}

Write-Host "`nExample setup complete!" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Complete src/main.cpp for each example" 
Write-Host "  2. Complete gateware/top.v for each example"
Write-Host "  3. Add example-specific README.md files"
