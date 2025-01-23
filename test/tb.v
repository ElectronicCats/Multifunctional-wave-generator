`timescale 1ns / 1ps

module tb;

    reg clk;
    reg rst_n;
    reg ena;
    reg [7:0] ui_in;   // Dedicated inputs
    reg [7:0] uio_in;  // IO inputs
    wire [7:0] uo_out; // Dedicated outputs
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    
    reg rx;  // UART RX line

    // Assign UART RX to ui_in[0]
    assign ui_in[0] = rx;

    // UART parameters
    parameter CLK_PERIOD = 40;     // 25 MHz clock period
    parameter BIT_PERIOD = 10417;  // 9600 baud (1/9600 seconds)

    // Instantiate the module under test (MUT)
    tt_um_waves uut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Clock generation (25 MHz)
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // UART Byte Transmission Task
    task send_uart_byte(input [7:0] byte);
        integer i;
        begin
            // Start bit
            rx = 0;
            #(BIT_PERIOD);

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte[i];
                #(BIT_PERIOD);
            end

            // Stop bit
            rx = 1;
            #(BIT_PERIOD);
        end
    endtask

    initial begin
        // Initialize signals
        rst_n = 0;
        ena = 1;
        ui_in = 8'b00000000;  // All inputs LOW
        uio_in = 8'b00000000; // No external IO interaction
        rx = 1;               // UART idle state

        // Reset pulse
        #100;
        rst_n = 1;
        #50000;

        // UART Commands - Testing Waveform Selection
        $display("Testing waveform selection...");

        send_uart_byte(8'h54);  // 'T' -> Triangle Wave
        #50000;
        $display("Triangle wave selected, I2S SD = %b", uo_out[2]);

        send_uart_byte(8'h53);  // 'S' -> Sawtooth Wave
        #50000;
        $display("Sawtooth wave selected, I2S SD = %b", uo_out[2]);

        send_uart_byte(8'h51);  // 'Q' -> Square Wave
        #50000;
        $display("Square wave selected, I2S SD = %b", uo_out[2]);

        send_uart_byte(8'h57);  // 'W' -> Sine Wave
        #50000;
        $display("Sine wave selected, I2S SD = %b", uo_out[2]);

        // Test White Noise Enable/Disable
        send_uart_byte(8'h4E);  // 'N' -> Enable White Noise
        #50000;
        $display("White noise enabled, I2S SD = %b", uo_out[2]);

        send_uart_byte(8'h46);  // 'F' -> Disable White Noise
        #50000;
        $display("White noise disabled, I2S SD = %b", uo_out[2]);

        // Test Frequency Selection
        $display("Testing frequency selection...");

        send_uart_byte(8'h41);  // 'A' -> Frequency Selection
        #50000;
        $display("Frequency A selected, I2S SCK = %b", uo_out[0]);

        send_uart_byte(8'h35);  // '5' -> Another frequency selection
        #50000;
        $display("Frequency 5 selected, I2S SCK = %b", uo_out[0]);

        // I2S Signal Verification
        $display("Verifying I2S output...");
        $display("I2S SCK: %b, WS: %b, SD: %b", uo_out[0], uo_out[1], uo_out[2]);

        // End simulation
        $finish;
    end
endmodule
