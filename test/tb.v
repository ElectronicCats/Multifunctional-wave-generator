`default_nettype none
`timescale 1ns / 1ps

/* Testbench for tt_um_waves
   - Instantiates the module under test (DUT)
   - Generates a 25 MHz clock (40 ns period)
   - Initializes reset and enable signals
   - Tests UART transmission, waveform selection, frequency control, and noise handling
*/

module tb;

  // Dump signals to a VCD file for waveform analysis
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

  // Clock generation (25 MHz -> 40 ns period)
  reg clk = 0;
  always #20 clk = ~clk;  // Toggle every 20 ns -> 25 MHz

  // Reset and enable signals
  reg rst_n = 0;
  reg ena = 0;

  // Inputs and outputs
  reg [7:0] ui_in = 0;
  reg [7:0] uio_in = 0;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Instantiate the module under test
  tt_um_waves (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // Enable - goes high when design is selected
      .clk    (clk),      // 25 MHz clock
      .rst_n  (rst_n)     // Active-low reset
  );

  // Test sequence
  initial begin
    #100;         // Wait for 100 ns
    rst_n = 1;    // Release reset
    ena = 1;      // Enable module

    #200;         // Wait for 200 ns
    ui_in = 8'h41; // Example UART command (ASCII 'A')

    #500000;      // Run for some time
    $finish;      // End simulation
  end

  // UART transmission simulation
  task uart_send(input [7:0] data);
    begin
      // Start bit (low)
      ui_in = 0;
      #2604;  // Adjusted for 25 MHz clock (one bit period)

      // Send 8 data bits (LSB first)
      for (int i = 0; i < 8; i = i + 1) begin
        ui_in = (data >> i) & 1;
        #2604;
      end

      // Stop bit (high)
      ui_in = 1;
      #2604;  // Wait for stop bit
    end
  endtask

  // Test sequence for UART commands
  initial begin
    // Test UART: Select different waveforms and verify I2S output changes
    #100;
    uart_send(8'h54);  // 'T' for Triangle
    #1000;  // Wait for processing time
    // Observe I2S serial data (uo_out[2]) change
    $display("I2S SD signal after Triangle command: %b", uo_out[2]);

    uart_send(8'h53);  // 'S' for Sawtooth
    #1000;
    $display("I2S SD signal after Sawtooth command: %b", uo_out[2]);

    uart_send(8'h51);  // 'Q' for Square
    #1000;
    $display("I2S SD signal after Square command: %b", uo_out[2]);

    uart_send(8'h57);  // 'W' for Sine
    #1000;
    $display("I2S SD signal after Sine command: %b", uo_out[2]);

    // Test UART: Set frequency ('0'-'9') and observe I2S clock
    for (int i = 0; i < 10; i = i + 1) begin
      uart_send(8'h30 + i);  // Send frequency character (e.g., '0', '1', ..., '9')
      #1000;
      $display("I2S SCK signal after frequency '%d' command: %b", i, uo_out[0]);
    end

    // Test UART: Enable White Noise ('N') and Disable ('F')
    uart_send(8'h4E);  // 'N' for Enable White Noise
    #1000;
    $display("I2S SD signal after enabling White Noise: %b", uo_out[2]);

    uart_send(8'h46);  // 'F' for Disable White Noise
    #1000;
    $display("I2S SD signal after disabling White Noise: %b", uo_out[2]);

    $finish;  // End simulation
  end
endmodule
