`default_nettype none
`timescale 1ns / 1ps

module tb;

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

  initial begin
    #50;
    $display("Reset=%b, Ena=%b", rst_n, ena);
    #100;
    $display("After reset: Reset=%b, Ena=%b", rst_n, ena);
  end

  reg clk = 0;
  always #20 clk = ~clk;  // 25 MHz clock (40ns period)

  reg rst_n;
  reg ena;

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

  // Improved reset and enable handling
  initial begin
    rst_n = 0;  // Ensure reset is asserted at the start
    ena = 0;    // Disable enable at the beginning
    #50;
    rst_n = 1;  // Release reset
    ena = 1;    // Enable the system immediately after reset
    $display("Reset applied: Reset=%b, Ena=%b", rst_n, ena);
  end

  // Ensure Ena is set whenever Reset is active
  always @(posedge clk) begin
    if (!rst_n) begin
      $display("Reset detected: Forcing Ena to 1");
      ena <= 1;
    end
  end

  // UART transmission simulation for waveform and frequency selection
  task uart_send(input [7:0] data);
    integer i;
    begin
      ui_in[0] <= 0;  // Start bit
      @(posedge clk); #8680;  // Simulating 115200 baud

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] <= data[i];
        @(posedge clk); #8680;
      end

      ui_in[0] <= 1;  // Stop bit
      @(posedge clk); #8680;
    end
  endtask

  // Debugging for I2S output
  always @(posedge clk) begin
    if (i2s_sck !== 1'bx && i2s_ws !== 1'bx && i2s_sd !== 1'bx) begin
      $display("I2S Debug: SCK=%b, WS=%b, SD=%b", i2s_sck, i2s_ws, i2s_sd);
    end else begin
      $display("Error: I2S in an undefined state");
    end
  end

  // Initial waveform selection via UART with extended delay
  initial begin
    #500;  // Ensure signal stability before sending data
    uart_send(8'h54);  // 'T' for triangular wave
    #1000;
    $display("Triangle wave test completed");
    
    uart_send(8'h57);  // 'W' for sine wave
    uart_send(8'h41);  // Frequency A4 (440 Hz)
    
    #5000;
    $finish;
  end

  // ADSR control simulation
  initial begin
    #1000;
    $display("Testing ADSR...");
    uio_in = 8'b11000000; // Simulated encoder values
    #5000;
    $display("ADSR Test Complete.");
  end

endmodule