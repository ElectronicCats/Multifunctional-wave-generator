`default_nettype none
`timescale 1ns / 1ps

module tb;
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

  // Clock Generation: 25 MHz (40ns period)
  reg clk = 0;
  always #20 clk = ~clk;

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

  // DUT Instantiation
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

  // Reset & Enable Sequence
  initial begin
    rst_n = 0;
    ena = 0;
    #500;  // Extended reset duration
    rst_n = 1;
    #200;  // Stabilization period
    ena = 1;    
    $display("[TB] Reset complete: rst_n=%b, ena=%b", rst_n, ena);
  end

  // UART Transmission Task
  task uart_send(input [7:0] data);
    integer i;
    begin
      $display("[TB] Sending UART Data: 0x%h", data);
      ui_in[0] <= 0;  // Start bit
      repeat (2604) @(posedge clk);  // Bit duration

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] <= data[i];  // LSB-first transmission
        repeat (2604) @(posedge clk);
      end

      ui_in[0] <= 1;  // Stop bit
      repeat (2604) @(posedge clk);
    end
  endtask

  // Encoder Rotation Simulation Task
  task rotate_encoder(input [1:0] encoder_pins, input integer steps);
    integer i, j;
    begin
      for (j = 0; j < steps; j = j + 1) begin
        // Quadrature sequence for one full step:
        uio_in[encoder_pins*2 +: 2] = 2'b00; #100;  // Initial state
        uio_in[encoder_pins*2 +: 2] = 2'b01; #100;  // First edge
        uio_in[encoder_pins*2 +: 2] = 2'b11; #100;  // Second edge
        uio_in[encoder_pins*2 +: 2] = 2'b10; #100;  // Third edge
        uio_in[encoder_pins*2 +: 2] = 2'b00; #100;  // Return to initial
      end
    end
  endtask

  // I2S Frame Monitoring
  always @(posedge i2s_ws) begin
    $display("[TB] I2S Frame: SCK=%b, WS=%b, SD=%b", i2s_sck, i2s_ws, i2s_sd);
  end

  // Main Test Sequence
  initial begin
    #1500;  // Post-reset delay

    // Configure ADSR parameters via encoders
    rotate_encoder(0, 5);  // Attack (pins 0-1), 5 steps
    rotate_encoder(1, 3);  // Decay (pins 2-3), 3 steps
    rotate_encoder(2, 8);  // Sustain (pins 4-5), 8 steps
    rotate_encoder(3, 4);  // Release (pins 6-7), 4 steps
    #2000;

    // Configure waveform and frequency via UART
    uart_send(8'h54);  // 'T' = Triangle wave
    #2000;
    uart_send(8'h41);  // 'A' = A4 (440Hz)
    #10000;

    $display("[TB] All test sequences completed");
    $finish;
  end

endmodule