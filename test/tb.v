`timescale 1ns / 1ps
`default_nettype none

module tb;

    // Simulation clock and reset
    reg clk = 0;
    always #20 clk = ~clk;  // 25 MHz clock (40 ns period)

    reg rst_n = 0;  // Active-low reset
    reg ena = 0;    // Enable signal

    // Inputs and outputs for the DUT
    reg [7:0] ui_in = 0;  // UART input
    reg [7:0] uio_in = 0; // User IO (used for ADSR control)
    wire [7:0] uo_out;    // Output (I2S signals)
    wire [7:0] uio_out;   // IO output (unused in this design)
    wire [7:0] uio_oe;    // IO output enable (unused in this design)

    // I2S signals for verification
    wire i2s_sck = uo_out[0];
    wire i2s_ws  = uo_out[1];
    wire i2s_sd  = uo_out[2];

    // Instantiate the DUT
    tt_um_waves dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    // VCD file for waveform analysis
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    // Reset and initialization sequence
    initial begin
        #100;  // Wait for simulation to settle
        rst_n = 1;  // Release reset
        #50;
        ena = 1;  // Enable the design

        // Send test commands via UART
        uart_send(8'h54);  // Select triangle wave
        #1000;
        uart_send(8'h53);  // Select sawtooth wave
        #1000;
        uart_send(8'h51);  // Select square wave
        #1000;

        // Test frequency selection via UART
        uart_send(8'h30);  // Set frequency 0
        #1000;
        uart_send(8'h31);  // Set frequency 1
        #1000;

        // Enable white noise
        uart_send(8'h4E);  // Enable white noise
        #1000;
        uart_send(8'h46);  // Disable white noise
        #1000;

        // Simulate ADSR control
        uio_in = 8'b00000011;  // Example ADSR configuration
        #10000;

        // Finish simulation
        $finish;
    end

    // UART transmission task
    task uart_send(input [7:0] data);
        integer i;
        begin
            // Start bit
            ui_in[0] = 0;
            #1041660;  // Simulate 9600 baud (1/9600s = ~1041660ns at 25 MHz clock)

            // Send 8 data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                ui_in[0] = data[i];
                #1041660;  // 9600 baud bit time
            end

            // Stop bit
            ui_in[0] = 1;
            #1041660;
        end
    endtask

    // Monitor key signals
    initial begin
        $monitor("Time: %0dns | wave_select: %h | freq_select: %h | i2s_sck: %b | i2s_ws: %b | i2s_sd: %b",
                 $time, dut.uart_rx_inst.wave_select, dut.uart_rx_inst.freq_select, i2s_sck, i2s_ws, i2s_sd);
    end

endmodule
