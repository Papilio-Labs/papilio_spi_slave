# Papilio SPI Slave Library - Hardware Test Runner
# Automated testing for all library examples
#
# Usage:
#   .\run_tests.ps1                          # Test all examples
#   .\run_tests.ps1 -Example loopback_test   # Test specific example
#   .\run_tests.ps1 -Verbose                 # Show detailed build output

param(
    [ValidateSet("all", "loopback_test", "bram_interface", "burst_transfers")]
    [string]$Example = "all",
    
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

# Fix Unicode encoding issues with PlatformIO output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$libRoot = Split-Path -Parent $scriptDir
$logDir = Join-Path $scriptDir "test_logs"

# Create log directory
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Clean up old logs
Write-Host "Cleaning up old log files..." -ForegroundColor DarkGray
Get-ChildItem -Path $logDir -Filter "*.log*" -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Papilio SPI Slave Library Test Suite" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Example configurations
$examples = @{
    "loopback_test" = @{
        Description = "Basic SPI loopback validation"
        ExpectedPasses = 8
        CaptureSeconds = 15
    }
    "bram_interface" = @{
        Description = "Memory read/write test (256 addresses)"
        ExpectedPasses = 256
        CaptureSeconds = 25
    }
    "burst_transfers" = @{
        Description = "High-speed burst transfers (8/16/32-bit)"
        ExpectedPasses = 2304  # 768 per bit width × 3 widths
        CaptureSeconds = 25
    }
}

# Helper function to set TRANSFER_WIDTH in burst_transfers FPGA and ESP32
function Set-BurstTransferWidth {
    param(
        [string]$ExamplePath,
        [int]$BitWidth
    )
    
    $topVPath = Join-Path $ExamplePath "gateware\top.v"
    $mainCppPath = Join-Path $ExamplePath "src\main.cpp"
    
    # Update FPGA top.v
    $topVContent = Get-Content $topVPath -Raw
    $topVContent = $topVContent -replace "localparam TRANSFER_WIDTH = \d+;", "localparam TRANSFER_WIDTH = $BitWidth;"
    $topVContent | Set-Content -Path $topVPath
    
    # Update ESP32 main.cpp
    $mainCppContent = Get-Content $mainCppPath -Raw
    $mainCppContent = $mainCppContent -replace "#define TEST_BIT_WIDTH \d+", "#define TEST_BIT_WIDTH $BitWidth"
    $mainCppContent | Set-Content -Path $mainCppPath
    
    # Give filesystem time to flush changes
    Start-Sleep -Milliseconds 500
}

# Special function for burst_transfers to test all bit widths
function Test-BurstTransfers {
    param(
        [string]$ExampleName,
        [hashtable]$Config
    )
    
    $examplePath = Join-Path $libRoot "examples\$ExampleName"
    if (-not (Test-Path $examplePath)) {
        Write-Host "[SKIP] Example not found: $ExampleName" -ForegroundColor Yellow
        return $null
    }
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "Testing: $ExampleName" -ForegroundColor Yellow
    Write-Host "$($Config.Description)" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host ""
    
    $totalPassed = 0
    $totalFailed = 0
    $allWidthsPassed = $true
    
    # Test each bit width
    foreach ($bitWidth in @(8, 16, 32)) {
        Write-Host "--- Testing ${bitWidth}-bit mode ---" -ForegroundColor Magenta
        
        # Set the bit width in both FPGA and ESP32
        Set-BurstTransferWidth -ExamplePath $examplePath -BitWidth $bitWidth
        
        $logFile = Join-Path $logDir "${ExampleName}_${bitWidth}bit_${timestamp}.log"
        
        # Build and upload FPGA
        Write-Host "[1/3] Building and uploading FPGA bitstream..." -ForegroundColor Cyan
        Push-Location $examplePath
        try {
            if ($Verbose) {
                pio run -e fpga -t clean
                pio run -e fpga -t upload
            } else {
                $null = pio run -e fpga -t clean 2>&1
                $null = pio run -e fpga -t upload 2>&1
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Host "      [FAIL] FPGA build/upload failed! (Exit code: $LASTEXITCODE)" -ForegroundColor Red
                if (-not $Verbose) {
                    Write-Host "      Run with -Verbose to see build output" -ForegroundColor Yellow
                }
                $allWidthsPassed = $false
                continue
            }
            Write-Host "      [OK] FPGA bitstream uploaded" -ForegroundColor Green
        }
        finally {
            Pop-Location
        }
        
        # Build and upload ESP32
        Write-Host "[2/3] Building and uploading ESP32 firmware..." -ForegroundColor Cyan
        Push-Location $examplePath
        try {
            if ($Verbose) {
                pio run -e esp32 -t upload
            } else {
                $null = pio run -e esp32 -t upload 2>&1
            }
            if ($LASTEXITCODE -ne 0) {
                Write-Host "      [FAIL] ESP32 build/upload failed! (Exit code: $LASTEXITCODE)" -ForegroundColor Red
                if (-not $Verbose) {
                    Write-Host "      Run with -Verbose to see build output" -ForegroundColor Yellow
                }
                $allWidthsPassed = $false
                continue
            }
            Write-Host "      [OK] ESP32 firmware uploaded" -ForegroundColor Green
        }
        finally {
            Pop-Location
        }
        
        # Capture test output
        Write-Host "[3/3] Capturing test output ($($Config.CaptureSeconds) seconds)..." -ForegroundColor Cyan
        Write-Host "      Waiting for device to stabilize..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
        
        Push-Location $examplePath
        try {
            $monitorProcess = Start-Process -FilePath "pio" `
                -ArgumentList "device","monitor" `
                -NoNewWindow -PassThru `
                -RedirectStandardOutput $logFile `
                -RedirectStandardError "$logFile.err"
            
            Start-Sleep -Seconds $Config.CaptureSeconds
            
            if (-not $monitorProcess.HasExited) {
                Stop-Process -Id $monitorProcess.Id -Force -ErrorAction SilentlyContinue
                # Wait for serial port to be released
                Start-Sleep -Seconds 2
            }
        }
        finally {
            Pop-Location
        }
        
        Write-Host "      [OK] Output captured to: $logFile" -ForegroundColor Green
        
        # Parse results for this width
        if (Test-Path $logFile) {
            $logContent = Get-Content $logFile -Raw
            
            if ($logContent -match "Passed:\s*(\d+)\s*\n.*Failed:\s*(\d+)") {
                $passed = [int]$Matches[1]
                $failed = [int]$Matches[2]
            }
            else {
                Write-Host "      Could not parse test results from log" -ForegroundColor Yellow
                $allWidthsPassed = $false
                continue
            }
            
            $totalPassed += $passed
            $totalFailed += $failed
            
            Write-Host "      ${bitWidth}-bit: $passed passed, $failed failed" -ForegroundColor $(if ($passed -ge 768) { "Green" } else { "Red" })
        }
        else {
            $allWidthsPassed = $false
        }
        
        Write-Host ""
    }
    
    # Report combined results
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "Combined Results: $totalPassed passed, $totalFailed failed" -ForegroundColor $(if ($totalPassed -ge $Config.ExpectedPasses) { "Green" } else { "Red" })
    $testsPassed = ($totalPassed -ge $Config.ExpectedPasses)
    
    return @{
        Name = $ExampleName
        Passed = $totalPassed
        Failed = $totalFailed
        Success = $testsPassed
    }
}

# Function to run a single example test
function Test-Example {
    param(
        [string]$ExampleName,
        [hashtable]$Config
    )
    
    $examplePath = Join-Path $libRoot "examples\$ExampleName"
    if (-not (Test-Path $examplePath)) {
        Write-Host "[SKIP] Example not found: $ExampleName" -ForegroundColor Yellow
        return $null
    }
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "Testing: $ExampleName" -ForegroundColor Yellow
    Write-Host "$($Config.Description)" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host ""
    
    $logFile = Join-Path $logDir "${ExampleName}_${timestamp}.log"
    
    # Build and upload FPGA
    Write-Host "[1/3] Building and uploading FPGA bitstream..." -ForegroundColor Cyan
    Push-Location $examplePath
    try {
        # Clean first to avoid locked file issues
        if ($Verbose) {
            pio run -e fpga -t clean
            pio run -e fpga -t upload
        } else {
            $null = pio run -e fpga -t clean 2>&1
            $null = pio run -e fpga -t upload 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "      [FAIL] FPGA build/upload failed! (Exit code: $LASTEXITCODE)" -ForegroundColor Red
            if (-not $Verbose) {
                Write-Host "      Run with -Verbose to see build output" -ForegroundColor Yellow
            }
            return $false
        }
        Write-Host "      [OK] FPGA bitstream uploaded" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
    
    # Build and upload ESP32
    Write-Host "[2/3] Building and uploading ESP32 firmware..." -ForegroundColor Cyan
    Push-Location $examplePath
    try {
        if ($Verbose) {
            pio run -e esp32 -t upload
        } else {
            $null = pio run -e esp32 -t upload 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "      [FAIL] ESP32 build/upload failed! (Exit code: $LASTEXITCODE)" -ForegroundColor Red
            if (-not $Verbose) {
                Write-Host "      Run with -Verbose to see build output" -ForegroundColor Yellow
            }
            return $false
        }
        Write-Host "      [OK] ESP32 firmware uploaded" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
    
    # Capture test output
    Write-Host "[3/3] Capturing test output ($($Config.CaptureSeconds) seconds)..." -ForegroundColor Cyan
    Write-Host "      Waiting for device to stabilize..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
    
    Push-Location $examplePath
    try {
        $monitorProcess = Start-Process -FilePath "pio" `
            -ArgumentList "device","monitor" `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $logFile `
            -RedirectStandardError "$logFile.err"
        
        Start-Sleep -Seconds $Config.CaptureSeconds
        
        if (-not $monitorProcess.HasExited) {
            Stop-Process -Id $monitorProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Host "      [OK] Output captured to: $logFile" -ForegroundColor Green
    
    # Parse results
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -Raw
        
        # Try different result patterns
        if ($logContent -match "Passed:\s*(\d+)\s*\n.*Failed:\s*(\d+)") {
            # Format: "Passed: X\nFailed: Y" (loopback_test format)
            $passed = [int]$Matches[1]
            $failed = [int]$Matches[2]
        }
        elseif ($logContent -match "(\d+) passed, (\d+) failed") {
            # Format: "X passed, Y failed"
            $passed = [int]$Matches[1]
            $failed = [int]$Matches[2]
        }
        elseif ($logContent -match "Results: (\d+) passed, (\d+) failed") {
            # Format: "Results: X passed, Y failed"
            $passed = [int]$Matches[1]
            $failed = [int]$Matches[2]
        }
        elseif ($logContent -match "PASSED: (\d+)/\d+") {
            # Format: "PASSED: X/Y"
            $passed = [int]$Matches[1]
            $failed = 0
        }
        else {
            Write-Host ""
            Write-Host "      Could not parse test results from log" -ForegroundColor Yellow
            return $false
        }
        
        # Test passes if we meet or exceed expected passes (failures allowed for speed limit testing)
        $testsPassed = ($passed -ge $Config.ExpectedPasses)
        $color = if ($testsPassed) { "Green" } else { "Red" }
        
        Write-Host ""
        Write-Host "      Results: $passed passed, $failed failed" -ForegroundColor $color
        return $testsPassed
    }
    
    return $false
}

# Build test plan
$testList = if ($Example -eq "all") { 
    @("loopback_test", "bram_interface", "burst_transfers")
} else { 
    @($Example) 
}

$results = @{}
$allPassed = $true

foreach ($exName in $testList) {
    if (-not $examples.ContainsKey($exName)) {
        Write-Host "[ERROR] Unknown example: $exName" -ForegroundColor Red
        continue
    }
    
    $config = $examples[$exName]
    
    # Use special handler for burst_transfers to test all bit widths
    if ($exName -eq "burst_transfers") {
        $result = Test-BurstTransfers -ExampleName $exName -Config $config
        if ($result) {
            $results[$exName] = @{
                Passed = $result.Passed
                Failed = $result.Failed
                Success = $result.Success
            }
            
            if ($result.Success) {
                Write-Host "[PASS] $exName tests completed successfully - $($result.Passed) passed, $($result.Failed) failed" -ForegroundColor Green
            } else {
                Write-Host "[FAIL] $exName tests FAILED - $($result.Passed) passed, $($result.Failed) failed" -ForegroundColor Red
                $allPassed = $false
            }
        } else {
            $results[$exName] = @{ Success = $false }
            Write-Host "[FAIL] $exName tests FAILED" -ForegroundColor Red
            $allPassed = $false
        }
    } else {
        $success = Test-Example -ExampleName $exName -Config $config
        $results[$exName] = @{ Success = $success }
        
        if ($success) {
            Write-Host "[PASS] $exName tests completed successfully" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] $exName tests FAILED" -ForegroundColor Red
            $allPassed = $false
        }
    }
}

# Final summary
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Suite Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Results Summary:" -ForegroundColor White

foreach ($exName in $testList) {
    if ($results.ContainsKey($exName)) {
        $result = $results[$exName]
        $status = if ($result.Success) { "[PASS]" } else { "[FAIL]" }
        $color = if ($result.Success) { "Green" } else { "Red" }
        
        if ($result.Passed -and $result.Failed) {
            Write-Host "  ${exName}: $status - $($result.Passed) passed, $($result.Failed) failed" -ForegroundColor $color
        } else {
            Write-Host "  ${exName}: $status" -ForegroundColor $color
        }
    }
}

Write-Host ""
if ($allPassed) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
}
Write-Host ""
Write-Host "Log files saved to: $logDir" -ForegroundColor Cyan
