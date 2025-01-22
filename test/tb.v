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

    // UART parameters
    parameter CLK_PERIOD = 40;     // 25 MHz clock period
    parameter BIT_PERIOD = 10417;  // 9600 baud (1/9600 seconds)

    // Assign UART RX to ui_in[0]
    assign ui_in[0] = rx;
    reg rx;  // UART RX line

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

            // Data bits
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

        // UART Commands - Testing Waveform Selection

        // Select TRIANGLE Wave ('T')
        send_uart_byte(8'h54);  // ASCII 'T'
        #50000;
        $display("Triangle wave selected, uo_out = %b", uo_out);

        // Select SAWTOOTH Wave ('S')
        send_uart_byte(8'h53);  // ASCII 'S'
        #50000;
        $display("Sawtooth wave selected, uo_out = %b", uo_out);

        // Select SQUARE Wave ('Q')
        send_uart_byte(8'h51);  // ASCII 'Q'
        #50000;
        $display("Square wave selected, uo_out = %b", uo_out);

        // Select SINE Wave ('W')
        send_uart_byte(8'h57);  // ASCII 'W'
        #50000;
        $display("Sine wave selected, uo_out = %b", uo_out);

        // Enable WHITE NOISE ('N')
        send_uart_byte(8'h4E);  // ASCII 'N'
        #50000;
        $display("White noise enabled, uo_out = %b", uo_out);

        // Disable WHITE NOISE ('F')
        send_uart_byte(8'h46);  // ASCII 'F'
        #50000;
        $display("White noise disabled, uo_out = %b", uo_out);

        // Select Frequency 'A' (First test frequency)
        send_uart_byte(8'h41);  // ASCII 'A'
        #50000;
        $display("Frequency A selected, uo_out = %b", uo_out);

        // Finish simulation
        $finish;
    end
endmodule
