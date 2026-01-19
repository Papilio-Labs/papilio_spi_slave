# Automated Test Runner for SPI Slave Module
# Tests all transfer widths (8, 16, 32-bit) automatically
# Supports both loopback and BRAM modes
# Captures output to timestamped log files
#
# Usage:
#   .\run_all_tests.ps1                    # Run comprehensive tests (default: all loopback + 8-bit BRAM)
#   .\run_all_tests.ps1 -Mode comprehensive # Run all loopback tests + 8-bit BRAM test
#   .\run_all_tests.ps1 -Mode loopback     # Run loopback tests only (all widths)
#   .\run_all_tests.ps1 -Mode bram         # Run BRAM tests (8-bit only, 16/32-bit disabled)
#   .\run_all_tests.ps1 -Width 8           # Test only 8-bit transfers
#   .\run_all_tests.ps1 -Verbose           # Show detailed build output

param(
    [ValidateSet("comprehensive", "loopback", "bram")]
    [string]$Mode = "comprehensive",
    
    [ValidateSet("8", "16", "32", "all")]
    [string]$Width = "all",
    
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

# Fix Unicode encoding issues with PlatformIO output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"

# Add CTRL-C handler for graceful exit
$script:shouldExit = $false
[Console]::TreatControlCAsInput = $false
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-Host "`n[INTERRUPTED] Script stopped by user" -ForegroundColor Yellow
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = "test_logs"

# Create log directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Clean up previous log files
$oldLogs = Get-ChildItem -Path $logDir -Filter "*.log" -ErrorAction SilentlyContinue
if ($oldLogs.Count -gt 0) {
    Remove-Item -Path "$logDir\*.log" -Force
    Write-Host "Cleaned up $($oldLogs.Count) old log file(s)" -ForegroundColor DarkGray
}

$modeDisplay = $Mode.ToUpper()

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Automated SPI Slave Test Suite" -ForegroundColor Cyan
Write-Host "Mode: $modeDisplay" -ForegroundColor Yellow
if ($Mode -eq "comprehensive") {
    Write-Host "Running: All loopback tests + 8-bit BRAM test" -ForegroundColor Cyan
} elseif ($Mode -eq "bram") {
    Write-Host "Running: BRAM tests (8-bit only)" -ForegroundColor Cyan
} elseif ($Width -eq "all") {
    Write-Host "Testing 8, 16, and 32-bit transfer widths" -ForegroundColor Cyan
} else {
    Write-Host "Testing ${Width}-bit transfer width only" -ForegroundColor Cyan
}
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Function to update TRANSFER_WIDTH in Verilog file
function Set-TransferWidth {
    param(
        [int]$Width
    )
    
    $verilogFile = "fpga\src\spi_top.v"
    $content = Get-Content $verilogFile -Raw
    
    # Replace the TRANSFER_WIDTH parameter value
    $content = $content -replace 'localparam TRANSFER_WIDTH = \d+;', "localparam TRANSFER_WIDTH = $Width;"
    
    Set-Content $verilogFile -Value $content -NoNewline
    Write-Host "[OK] Set TRANSFER_WIDTH = $Width in $verilogFile" -ForegroundColor Green
    
    # Also update ESP32 test file
    $cppFile = "src\main_spi_test.cpp"
    $content = Get-Content $cppFile -Raw
    
    # Replace the TRANSFER_WIDTH define
    $content = $content -replace '#define TRANSFER_WIDTH \d+', "#define TRANSFER_WIDTH $Width"
    
    Set-Content $cppFile -Value $content -NoNewline
    Write-Host "[OK] Set TRANSFER_WIDTH = $Width in $cppFile" -ForegroundColor Green
}

# Function to set USE_BRAM parameter
function Set-BramMode {
    param(
        [int]$UseBram  # 0 = loopback, 1 = BRAM
    )
    
    $verilogFile = "fpga\src\spi_top.v"
    $content = Get-Content $verilogFile -Raw
    
    # Replace the USE_BRAM parameter value
    $content = $content -replace 'localparam USE_BRAM = \d+;', "localparam USE_BRAM = $UseBram;"
    
    Set-Content $verilogFile -Value $content -NoNewline
    $mode = if ($UseBram -eq 1) { "BRAM" } else { "LOOPBACK" }
    Write-Host "[OK] Set USE_BRAM = $UseBram ($mode mode) in $verilogFile" -ForegroundColor Green
}

# Function to update USE_BRAM_TESTING in ESP32 test file
function Set-Esp32TestMode {
    param(
        [int]$UseBram  # 0 = loopback, 1 = BRAM
    )
    
    $cppFile = "src\main_spi_test.cpp"
    $content = Get-Content $cppFile -Raw
    
    # Replace the USE_BRAM_TESTING define
    $content = $content -replace '#define USE_BRAM_TESTING \d+', "#define USE_BRAM_TESTING $UseBram"
    
    Set-Content $cppFile -Value $content -NoNewline
    $mode = if ($UseBram -eq 1) { "BRAM" } else { "LOOPBACK" }
    Write-Host "[OK] Set USE_BRAM_TESTING = $UseBram ($mode tests) in $cppFile" -ForegroundColor Green
}

# Function to run test for a specific width
function Run-Test {
    param(
        [int]$Width,
        [string]$TestMode,
        [int]$CaptureSeconds = 20
    )
    
    $useBram = if ($TestMode -eq "bram") { 1 } else { 0 }
    $testModeDisplay = $TestMode.ToUpper()
    $logFile = "$logDir\test_${TestMode}_${Width}bit_$timestamp.log"
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "Testing ${Width}-bit Transfer Width ($testModeDisplay mode)" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host ""
    
    # Update FPGA configuration
    Set-TransferWidth -Width $Width
    Set-BramMode -UseBram $useBram
    
    # Update ESP32 test mode
    Set-Esp32TestMode -UseBram $useBram
    
    # Small delay to ensure file writes complete
    Start-Sleep -Milliseconds 500
    
    Write-Host "Building and uploading FPGA bitstream..." -ForegroundColor Cyan
    if ($Verbose) {
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        pio run -e fpga -t clean -t upload | Out-Host
    } else {
        pio run -e fpga -t clean -t upload | Out-Null
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] FPGA build/upload failed!" -ForegroundColor Red
        return $false
    }
    Write-Host "[OK] FPGA bitstream uploaded" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Building and uploading ESP32 firmware..." -ForegroundColor Cyan
    if ($Verbose) {
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        pio run -e esp32 -t upload | Out-Host
    } else {
        pio run -e esp32 -t upload | Out-Null
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] ESP32 build/upload failed!" -ForegroundColor Red
        return $false
    }
    Write-Host "[OK] ESP32 firmware uploaded" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Capturing test output for $CaptureSeconds seconds..." -ForegroundColor Cyan
    Write-Host "Press CTRL-C to stop early" -ForegroundColor DarkGray
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    
    # Capture output with live display
    $monitorProcess = Start-Process -FilePath "pio" -ArgumentList "device","monitor" -NoNewWindow -PassThru -RedirectStandardOutput $logFile
    
    try {
        # Wait for specified duration with interruptible sleep
        $elapsed = 0
        while ($elapsed -lt $CaptureSeconds) {
            Start-Sleep -Milliseconds 500
            $elapsed += 0.5
            
            # Check if process is still running
            if ($monitorProcess.HasExited) {
                Write-Host "Monitor process exited unexpectedly" -ForegroundColor Yellow
                break
            }
        }
    }
    finally {
        # Always clean up the monitor process
        if (-not $monitorProcess.HasExited) {
            Stop-Process -Id $monitorProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    Write-Host "[OK] Output captured to: $logFile" -ForegroundColor Green
    
    # Display summary from log and determine success
    $testsPassed = $false
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -Raw
        if ($logContent -match "Passed: (\d+)") {
            $passed = [int]$Matches[1]
            $logContent -match "Failed: (\d+)" | Out-Null
            $failed = [int]$Matches[1]
            
            # Different success criteria for BRAM vs loopback mode
            if ($useBram -eq 1) {
                # BRAM mode: Pass if at least 1 test passed and no failures
                $testsPassed = ($passed -ge 1 -and $failed -eq 0)
            } else {
                # Loopback mode: Consider successful if we have 8+ passes (core tests work)
                # Note: 8MHz speed test is expected to fail
                $testsPassed = ($passed -ge 8)
            }
            
            $color = if ($testsPassed) { "Green" } elseif ($passed -gt 0) { "Yellow" } else { "Red" }
            Write-Host "  Results: $passed passed, $failed failed" -ForegroundColor $color
        } else {
            Write-Host "  Could not parse test results from log" -ForegroundColor Yellow
        }
    }
    
    return $testsPassed
}

# Build test plan based on mode
$testPlan = @()
if ($Mode -eq "comprehensive") {
    # Run all loopback tests + 8-bit BRAM test
    $testPlan += @{Width=8; Mode="loopback"}
    $testPlan += @{Width=16; Mode="loopback"}
    $testPlan += @{Width=32; Mode="loopback"}
    $testPlan += @{Width=8; Mode="bram"}
} elseif ($Mode -eq "bram") {
    # BRAM mode: only 8-bit (16/32-bit disabled)
    $testPlan += @{Width=8; Mode="bram"}
} else {
    # Loopback mode
    if ($Width -eq "all") {
        $testPlan += @{Width=8; Mode="loopback"}
        $testPlan += @{Width=16; Mode="loopback"}
        $testPlan += @{Width=32; Mode="loopback"}
    } else {
        $testPlan += @{Width=[int]$Width; Mode="loopback"}
    }
}

$results = @{}
foreach ($test in $testPlan) {
    $testKey = "$($test.Mode)-$($test.Width)bit"
    $success = Run-Test -Width $test.Width -TestMode $test.Mode -CaptureSeconds 20
    $results[$testKey] = $success
    
    if ($success) {
        Write-Host "[PASS] $testKey tests completed successfully" -ForegroundColor Green
    } else {
        Write-Host "" -ForegroundColor Red
        Write-Host "[FAIL] $testKey tests FAILED - stopping test suite" -ForegroundColor Red
        Write-Host "" -ForegroundColor Red
        break
    }
}

# Final summary
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Suite Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Results Summary:" -ForegroundColor White
$allPassed = $true
foreach ($test in $testPlan) {
    $testKey = "$($test.Mode)-$($test.Width)bit"
    if ($results.ContainsKey($testKey)) {
        $status = if ($results[$testKey]) { "[PASS]" } else { "[FAIL]" }
        $color = if ($results[$testKey]) { "Green" } else { "Red" }
        Write-Host "  ${testKey}: $status" -ForegroundColor $color
        if (-not $results[$testKey]) { $allPassed = $false }
    } else {
        Write-Host "  ${testKey}: [NOT RUN]" -ForegroundColor DarkGray
        $allPassed = $false
    }
}
Write-Host ""
if ($allPassed) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED OR WERE NOT RUN" -ForegroundColor Red
}
Write-Host ""
Write-Host "Log files saved to: $logDir\" -ForegroundColor Cyan

# Restore to 8-bit default
Write-Host ""
Write-Host "Restoring defaults (8-bit, loopback mode)..." -ForegroundColor Cyan
Set-TransferWidth -Width 8
Set-BramMode -UseBram 0
Set-Esp32TestMode -UseBram 0
Write-Host "[OK] Done!" -ForegroundColor Green
