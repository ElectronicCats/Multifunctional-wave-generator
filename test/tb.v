`timescale 1ns/1ps

module tb_uart_wave;

    reg clk;                 // Clock signal
    reg rst_n;               // Reset signal (active low)
    reg rx;                  // UART RX signal
    wire [2:0] wave_select;  // Selected wave
    wire white_noise_en;     // White noise enable

    // Instantiate the UART receiver module
    uart_receiver uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .freq_select(),      // Not used for this test
        .wave_select(wave_select),
        .white_noise_en(white_noise_en)
    );

    // Clock generation
    initial clk = 0;
    always #20 clk = ~clk;  // 25 MHz clock (40 ns period)

    // UART transmission task
    task send_uart_byte(input [7:0] data);
        integer i;
        begin
            rx = 0; // Start bit
            #8680;  // 115200 baud rate = ~8680 ns per bit
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #8680;  // Data bits
            end
            rx = 1; // Stop bit
            #8680;
        end
    endtask

    // Testbench sequence
    initial begin
        // Initialize signals
        rx = 1;
        rst_n = 0;

        // Apply reset
        #100;
        rst_n = 1;

        // Send 'T' for Triangle wave
        #1000;
        send_uart_byte(8'h54);

        // Wait and check the output
        #10000;
        if (wave_select !== 3'b000) $display("Test failed: Expected 3'b000, got %b", wave_select);
        else $display("Test passed: Triangle wave selected.");

        // Send 'S' for Sawtooth wave
        send_uart_byte(8'h53);

        // Wait and check the output
        #10000;
        if (wave_select !== 3'b001) $display("Test failed: Expected 3'b001, got %b", wave_select);
        else $display("Test passed: Sawtooth wave selected.");

        // End simulation
        $finish;
    end
endmodule
