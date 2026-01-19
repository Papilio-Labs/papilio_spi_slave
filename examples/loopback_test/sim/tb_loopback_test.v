// Testbench for SPI Slave Loopback
// Validates basic SPI communication with echo functionality
`timescale 1ns/1ps

module tb_loopback_test;

// Clock and reset
reg clk;
reg rst;

// SPI signals
reg spi_sclk;
reg spi_mosi;
wire spi_miso;
reg spi_cs_n;

// Test signals
integer test_count;
integer pass_count;
integer fail_count;

// Instantiate top module
top dut (
    .clk(clk),
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_cs_n(spi_cs_n)
);

// Clock generation (27MHz)
initial begin
    clk = 0;
    forever #18.5 clk = ~clk;  // 27MHz
end

// SPI clock (slower than system clock)
initial begin
    spi_sclk = 0;
end

// Task to send/receive SPI byte
task spi_transfer;
    input [7:0] data_out;
    output [7:0] data_in;
    integer i;
    begin
        spi_cs_n = 0;
        #100;
        
        data_in = 8'h00;
        for (i = 7; i >= 0; i = i - 1) begin
            spi_mosi = data_out[i];
            #100 spi_sclk = 1;
            #100 data_in[i] = spi_miso;
            spi_sclk = 0;
        end
        
        #100;
        spi_cs_n = 1;
        #200;
    end
endtask

// Test patterns
reg [7:0] test_patterns [0:7];
reg [7:0] received;
integer i;

initial begin
    // Initialize
    test_count = 0;
    pass_count = 0;
    fail_count = 0;
    
    rst = 1;
    spi_cs_n = 1;
    spi_mosi = 0;
    
    // Test patterns
    test_patterns[0] = 8'h00;
    test_patterns[1] = 8'hFF;
    test_patterns[2] = 8'hAA;
    test_patterns[3] = 8'h55;
    test_patterns[4] = 8'h0F;
    test_patterns[5] = 8'hF0;
    test_patterns[6] = 8'h12;
    test_patterns[7] = 8'h34;
    
    // Wait for reset
    #200;
    rst = 0;
    #1000;
    
    $display("=== SPI Loopback Simulation Test ===");
    $display("");
    
    // Run tests
    for (i = 0; i < 8; i = i + 1) begin
        spi_transfer(test_patterns[i], received);
        test_count = test_count + 1;
        
        // Note: First transfer may not echo due to pipeline delay
        // Second transfer should echo the first value
        if (i > 0) begin
            if (received == test_patterns[i-1]) begin
                $display("[PASS] Pattern 0x%02h -> 0x%02h", test_patterns[i-1], received);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Pattern 0x%02h -> 0x%02h (expected 0x%02h)", 
                    test_patterns[i-1], received, test_patterns[i-1]);
                fail_count = fail_count + 1;
            end
        end
    end
    
    // One more transfer to check last pattern
    spi_transfer(8'h00, received);
    if (received == test_patterns[7]) begin
        $display("[PASS] Pattern 0x%02h -> 0x%02h", test_patterns[7], received);
        pass_count = pass_count + 1;
    end else begin
        $display("[FAIL] Pattern 0x%02h -> 0x%02h (expected 0x%02h)", 
            test_patterns[7], received, test_patterns[7]);
        fail_count = fail_count + 1;
    end
    
    // Summary
    $display("");
    $display("=== Test Summary ===");
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", fail_count);
    
    if (fail_count == 0 && pass_count > 0) begin
        $display("");
        $display("PASS: All tests passed");
        $finish(0);
    end else begin
        $display("");
        $display("FAIL: Some tests failed");
        $finish(1);
    end
end

// Timeout
initial begin
    #100000;
    $display("TIMEOUT: Test exceeded time limit");
    $finish(2);
end

// Optional VCD dump for debugging
initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("tb_loopback_test.vcd");
        $dumpvars(0, tb_loopback_test);
    end
end

endmodule
