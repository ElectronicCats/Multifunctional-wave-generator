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

  // Reset and Enable Signals
  reg rst_n;
  reg ena;
  
  // DUT I/O
  reg [7:0] ui_in = 0;
  reg [7:0] uio_in = 0;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // I2S Interface Monitoring
  wire i2s_sck = uo_out[0];
  wire i2s_ws  = uo_out[1];
  wire i2s_sd  = uo_out[2];
  reg [15:0] captured_data;

  // Instantiate DUT
  tt_um_waves dut (
    .ui_in(ui_in),
    .uo_out(uo_out),
    .uio_in(uio_in),
    .uio_out(uio_out),
    .uio_oe(uio_oe),
    .ena(ena),
    .clk(clk),
    .rst_n(rst_n)
  );

  // Reset and Enable Initialization
  initial begin
    rst_n = 0;
    ena = 0;
    #500 rst_n = 1;
    #200 ena = 1;
    $display("[TB] System Enabled");
  end

  // UART Transmission Task
  task uart_send(input [7:0] data);
    integer i;
    begin
      ui_in[0] = 1'b1;  // Idle state
      #100000;
      
      // Start bit
      ui_in[0] = 1'b0;
      #104160;
      
      // Data bits
      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] = data[i];
        #104160;
      end
      
      // Stop bit
      ui_in[0] = 1'b1;
      #104160;
      $display("[TB] Sent UART: 0x%h", data);
    end
  endtask

  // Encoder Simulation Task
  task rotate_encoder(input [1:0] encoder_id, input integer steps);
    integer i;
    reg [1:0] base_pin;
    begin
      base_pin = encoder_id * 2;
      for (i = 0; i < steps; i = i + 1) begin
        // Clockwise rotation pattern
        uio_in[base_pin +: 2] = 2'b00; #400;
        uio_in[base_pin +: 2] = 2'b01; #400;
        uio_in[base_pin +: 2] = 2'b11; #400;
        uio_in[base_pin +: 2] = 2'b10; #400;
      end
      $display("[TB] Encoder %0d rotated %0d steps", encoder_id, steps);
    end
  endtask

  // I2S Data Capture
  always @(negedge i2s_ws) begin
    captured_data <= 16'h0000;
    for (int i = 15; i >= 0; i--) begin
      @(negedge i2s_sck);
      captured_data[i] <= i2s_sd;
    end
    $display("[I2S] Captured: 0x%h (%0d)", captured_data, captured_data[15:8]);
  end

  // Main Test Sequence
  initial begin
    // Wait for initialization
    #1500;

    // Test ADSR Controls
    $display("\nTesting ADSR Parameters");
    rotate_encoder(0, 5);  // Attack
    rotate_encoder(1, 3);  // Decay
    rotate_encoder(2, 8);  // Sustain
    rotate_encoder(3, 4);  // Release
    #10000;

    // Waveform Tests
    $display("\nTesting Waveform Selection");
    uart_send(8'h54);  // Triangle
    uart_send(8'h5B);  // A4
    #20000;
    
    uart_send(8'h53);  // Sawtooth
    #20000;
    
    uart_send(8'h51);  // Square
    #20000;
    
    uart_send(8'h57);  // Sine
    #20000;

    // Noise Test
    uart_send(8'h4E);  // Noise ON
    #20000;
    uart_send(8'h46);  // Noise OFF
    #10000;

    // Frequency Range Test
    $display("\nTesting Frequency Range");
    uart_send(8'h30);  // C2
    #10000;
    uart_send(8'h5B);  // A4
    #10000;
    uart_send(8'h7A);  // B6
    #10000;

    // Test Completion
    #5000;
    $display("\n[TB] All Tests Completed");
    $finish;
  end

endmodule