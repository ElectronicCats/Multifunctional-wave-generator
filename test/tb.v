`default_nettype none
`timescale 1ns / 1ps

module tb;
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
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
    rst_n = 0;
    ena = 0;
    #50;
    rst_n = 1;  // Release reset
    #10;
    ena = 1;    // Enable system after reset is stable
    $display("Reset applied: Reset=%b, Ena=%b", rst_n, ena);
  end

  // UART transmission simulation for waveform and frequency selection
  task uart_send(input [7:0] data);
    integer i;
    begin
      ui_in[0] <= 0;  // Start bit
      repeat (2604) @(posedge clk); // Simulating 115200 baud

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] <= data[i];
        repeat (2604) @(posedge clk);
      end

      ui_in[0] <= 1;  // Stop bit
      repeat (2604) @(posedge clk);
    end
  endtask

  // Debugging for I2S output
  reg [2:0] prev_i2s;
  always @(posedge clk) begin
    if ({i2s_sck, i2s_ws, i2s_sd} !== prev_i2s) begin
      $display("I2S Debug: SCK=%b, WS=%b, SD=%b", i2s_sck, i2s_ws, i2s_sd);
      prev_i2s <= {i2s_sck, i2s_ws, i2s_sd};
    end
  end

  // Initial waveform selection via UART
  initial begin
    #500;  
    uart_send(8'h54);  // 'T' for Triangle
    #500;
    uart_send(8'h57);  // 'W' for Sine
    uart_send(8'h41);  // Frequency A4 (440 Hz)
    #2000;
    $display("Waveform test completed.");
  end

  // ADSR control test
  initial begin
    #1000;
    uio_in = 8'b11000000; // Simulated encoder values
    #5000;
    $display("ADSR Test Complete.");
    $finish;
  end

endmodule