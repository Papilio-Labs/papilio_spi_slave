#!/bin/bash
# Simulation Test Runner for CI/CD
# Runs all iverilog testbenches

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_ROOT="$(dirname "$SCRIPT_DIR")"
GATEWARE_DIR="$LIB_ROOT/gateware"
EXAMPLES_DIR="$LIB_ROOT/examples"
LOG_DIR="$SCRIPT_DIR/test_logs"

# Create log directory
mkdir -p "$LOG_DIR"

echo "========================================"
echo "Papilio SPI Slave - Simulation Tests"
echo "========================================"
echo ""

# Check for iverilog
if ! command -v iverilog &> /dev/null; then
    echo "[ERROR] iverilog not found in PATH"
    echo "Install with: sudo apt-get install iverilog"
    exit 1
fi

echo "iverilog version: $(iverilog -V | head -n1)"
echo ""

# Track results
TOTAL=0
PASSED=0
FAILED=0

# Function to run a testbench
run_testbench() {
    local TB_FILE=$1
    local TB_NAME=$(basename "$TB_FILE" .v)
    local TEST_DIR=$(dirname "$TB_FILE")
    
    echo "----------------------------------------"
    echo "Running: $TB_NAME"
    echo "----------------------------------------"
    
    TOTAL=$((TOTAL + 1))
    
    cd "$TEST_DIR"
    
    # Compile
    echo "  Compiling..."
    if ! iverilog -o sim.vvp \
        -I"$GATEWARE_DIR" \
        "$TB_FILE" \
        "$GATEWARE_DIR/spi_slave.v" \
        "$GATEWARE_DIR/fifo_sync.v" \
        2>&1 | tee "$LOG_DIR/${TB_NAME}_compile.log"; then
        echo "  [FAIL] Compilation failed"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    # Run simulation
    echo "  Running simulation..."
    if vvp sim.vvp 2>&1 | tee "$LOG_DIR/${TB_NAME}_sim.log" | grep -q "PASS"; then
        echo "  [PASS] Test passed"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] Test failed"
        FAILED=$((FAILED + 1))
        cat "$LOG_DIR/${TB_NAME}_sim.log"
    fi
    
    # Cleanup
    rm -f sim.vvp
    
    cd - > /dev/null
    echo ""
}

# Find and run all testbenches
echo "Searching for testbenches..."
echo ""

# Run testbenches in examples
for EXAMPLE_DIR in "$EXAMPLES_DIR"/*; do
    if [ -d "$EXAMPLE_DIR/sim" ]; then
        for TB_FILE in "$EXAMPLE_DIR/sim"/tb_*.v; do
            if [ -f "$TB_FILE" ]; then
                run_testbench "$TB_FILE"
            fi
        done
    fi
done

# Run standalone testbenches in tests/sim
if [ -d "$SCRIPT_DIR/sim" ]; then
    for TB_FILE in "$SCRIPT_DIR/sim"/tb_*.v; do
        if [ -f "$TB_FILE" ]; then
            run_testbench "$TB_FILE"
        fi
    done
fi

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Total:  $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ] && [ $TOTAL -gt 0 ]; then
    echo "✓ ALL TESTS PASSED"
    exit 0
elif [ $TOTAL -eq 0 ]; then
    echo "⚠ NO TESTS FOUND"
    exit 1
else
    echo "✗ SOME TESTS FAILED"
    exit 1
fi
