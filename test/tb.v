`timescale 1ns/1ps

module tb_uart_receiver();

    reg clk;
    reg rst_n;
    reg rx;
    wire [5:0] freq_select;
    wire [2:0] wave_select;
    wire white_noise_en;

    // Instantiate the UART Receiver
    uart_receiver uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .freq_select(freq_select),
        .wave_select(wave_select),
        .white_noise_en(white_noise_en)
    );

    // Clock generation
    always #5 clk = ~clk; // 100MHz clock (10ns period)

    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        rx = 1;  // Idle state of UART line is high

        // Reset the module
        #20 rst_n = 1;

        // Send 'T' (0x54 in ASCII) to select Triangle Wave
        send_uart_byte(8'h54);

        // Wait for UART processing
        #100000;

        // Send 'S' (0x53 in ASCII) to select Sawtooth Wave
        send_uart_byte(8'h53);

        // Wait for UART processing
        #100000;

        // End simulation
        #1000 $finish;
    end

    // Task to simulate UART byte transmission
    task send_uart_byte(input [7:0] byte);
        integer i;
        begin
            // Start bit
            rx = 0;
            #8680; // One UART bit time (for 115200 baud rate at 100MHz)

            // Send data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte[i];
                #8680;
            end

            // Stop bit
            rx = 1;
            #8680;
        end
    endtask
endmodule
