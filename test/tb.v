`default_nettype none
`timescale 1ns / 1ps

/* Testbench for tt_um_waves */

module tb;

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

  reg clk = 0;
  always #20 clk = ~clk;  // 25 MHz clock (40ns period)

  reg rst_n = 0;
  reg ena = 0;

  reg [7:0] ui_in = 0;
  reg [7:0] uio_in = 0;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  wire i2s_sck = uo_out[0];
  wire i2s_ws  = uo_out[1];
  wire i2s_sd  = uo_out[2];

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

  // Reset and enable
  initial begin
    #100;
    rst_n = 1;
    #100;
    ena = 1;
  end

  // UART Transmission Simulation (for frequency and waveform selection)
  task uart_send(input [7:0] data);
    integer i;
    begin
      ui_in[0] <= 0;  // Start bit
      @(posedge clk); #8680;  // Simulating 115200 baud (1/115200 ≈ 8680ns)

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] <= data[i];
        @(posedge clk); #8680;
      end

      ui_in[0] <= 1;  // Stop bit
      @(posedge clk); #8680;
    end
  endtask

  // Monitor I2S Output
  always @(posedge clk) begin
    $display("I2S: SCK=%b, WS=%b, SD=%b", i2s_sck, i2s_ws, i2s_sd);
  end

  // Testing Frequency and Waveform Selection via UART
  initial begin
    #200;

    uart_send(8'h54);  // 'T' for Triangle wave
    #1000;
    $display("Triangle wave test completed");

    uart_send(8'h51);  // 'Q' for Square wave
    #1000;
    $display("Square wave test completed");

    uart_send(8'h57);  // 'W' for Sine wave (CORDIC)
    #1000;
    $display("Sine wave test completed");

    uart_send(8'h53);  // 'S' for Sawtooth wave
    #1000;
    $display("Sawtooth wave test completed");

    // Frequency Selection (Octaves & Notes)
    for (int j = 0; j < 10; j = j + 1) begin
      uart_send(8'h30 + j);
      #2000;
      $display("Frequency %d selected - I2S SD: %b", j, i2s_sd);
    end

    $finish;
  end

  // Testing ADSR using Encoders (via `uio_in`)
  initial begin
    #5000;
    $display("Testing Encoder Control for ADSR...");

    // Simulate increasing attack using rotary encoder
    uio_in = 8'b0000_0001; 
    #5000;
    uio_in = 8'b0000_0010; 
    #5000;
    uio_in = 8'b0000_0000;
    #5000;
    $display("ADSR Attack Level Test completed");

    // Simulate increasing decay
    uio_in = 8'b0000_0100; 
    #5000;
    uio_in = 8'b0000_1000; 
    #5000;
    uio_in = 8'b0000_0000;
    #5000;
    $display("ADSR Decay Level Test completed");

    // Simulate increasing sustain
    uio_in = 8'b0001_0000; 
    #5000;
    uio_in = 8'b0010_0000; 
    #5000;
    uio_in = 8'b0000_0000;
    #5000;
    $display("ADSR Sustain Level Test completed");

    // Simulate increasing release
    uio_in = 8'b0100_0000; 
    #5000;
    uio_in = 8'b1000_0000; 
    #5000;
    uio_in = 8'b0000_0000;
    #5000;
    $display("ADSR Release Level Test completed");

    $display("ADSR Encoder Testing Complete.");
    #2000;
    $finish;
  end

endmodule
