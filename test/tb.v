`timescale 1ns/1ps

module tb;

    reg clk;
    reg rst_n;
    reg rx;
    wire [5:0] freq_select;
    wire [2:0] wave_select;
    wire white_noise_en;

    // Instantiate the UART receiver module
    uart_receiver uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .freq_select(freq_select),
        .wave_select(wave_select),
        .white_noise_en(white_noise_en)
    );

    // Generate a 25 MHz clock (40 ns period)
    always #20 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        rx = 1; // RX line idle state

        // Apply reset
        #100;
        rst_n = 1;

        // Wait for reset to propagate
        #100;

        // Send 'T' (Triangle Wave)
        send_uart_byte(8'h54);
        #1000;
        $display("Wave Select = %b (Expected: 000)", wave_select);

        // Send 'S' (Sawtooth Wave)
        send_uart_byte(8'h53);
        #1000;
        $display("Wave Select = %b (Expected: 001)", wave_select);

        // Send 'Q' (Square Wave)
        send_uart_byte(8'h51);
        #1000;
        $display("Wave Select = %b (Expected: 010)", wave_select);

        // Send 'W' (Sine Wave)
        send_uart_byte(8'h57);
        #1000;
        $display("Wave Select = %b (Expected: 011)", wave_select);

        // Send 'N' (Enable White Noise)
        send_uart_byte(8'h4E);
        #1000;
        $display("White Noise Enable = %b (Expected: 1)", white_noise_en);

        // Send 'F' (Disable White Noise)
        send_uart_byte(8'h46);
        #1000;
        $display("White Noise Enable = %b (Expected: 0)", white_noise_en);

        // Send a frequency byte (e.g., 0x3C)
        send_uart_byte(8'h3C);
        #1000;
        $display("Frequency Select = %b (Expected: 00111100)", freq_select);

        // Finish simulation
        $finish;
    end

    // Task to send a UART byte
    task send_uart_byte(input [7:0] byte);
        integer i;
        begin
            rx = 0; // Start bit
            #10416; // Wait 1 baud (assuming 9600 baud rate)

            for (i = 0; i < 8; i = i + 1) begin
                rx = byte[i]; // Send each bit
                #10416;       // Wait 1 baud
            end

            rx = 1; // Stop bit
            #10416; // Wait 1 baud
        end
    endtask

endmodule
