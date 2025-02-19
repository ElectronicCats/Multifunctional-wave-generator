`default_nettype none
`timescale 1ns / 1ps

/* Testbench for tt_um_waves */

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

  // I2S Signals
  wire i2s_sck = uo_out[0];
  wire i2s_ws  = uo_out[1];
  wire i2s_sd  = uo_out[2];

  // Instantiate the module under test
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

  // Reset and enable sequence
  initial begin
    #200;
    rst_n = 1;  // Release reset
    #50;
    ena = 1;    // Enable I2S transmitter and waveform generation

    // Transmit arbitrary data for testing
    #200;
    ui_in = 8'h41;

    // Run simulation for a sufficient duration
    #500000;
    $finish;
  end

  // UART transmission simulation
  task uart_send(input [7:0] data);
    integer i;
    begin
      ui_in[0] = 0;  // Start bit
      #(25_000_000 / 9600);

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] = (data >> i) & 1;
        #(25_000_000 / 9600);  // 9600 baud bit time
      end

      ui_in[0] = 1;  // Stop bit
      #(25_000_000 / 9600);
    end
  endtask

  // Test sequence for UART commands & I2S validation
  reg [3:0] j;
  initial begin
    #300;

    // Test wave selection
    uart_send(8'h54);  // 'T' for Triangle wave
    #1000;
    $display("Triangle Wave Selected - I2S SD: %b", i2s_sd);

    uart_send(8'h53);  // 'S' for Sawtooth wave
    #1000;
    $display("Sawtooth Wave Selected - I2S SD: %b", i2s_sd);

    uart_send(8'h51);  // 'Q' for Square wave
    #1000;
    $display("Square Wave Selected - I2S SD: %b", i2s_sd);

    // Test frequency selection
    for (j = 0; j < 10; j = j + 1) begin
      uart_send(8'h30 + j);
      #1000;
      $display("Freq %d Selected - I2S SCK: %b, WS: %b, SD: %b", j, i2s_sck, i2s_ws, i2s_sd);
    end

    // White Noise Test
    uart_send(8'h4E);  // Enable White Noise
    #1000;
    $display("White Noise Enabled - I2S SD: %b", i2s_sd);

    uart_send(8'h46);  // Disable White Noise
    #1000;
    $display("White Noise Disabled - I2S SD: %b", i2s_sd);

    $finish;
  end

endmodule
