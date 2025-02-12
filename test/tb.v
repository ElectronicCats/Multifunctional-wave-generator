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

  // Observing selected_wave and noise_out
  wire [7:0] selected_wave;
  wire [7:0] noise_out;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Instantiate the module under test
  tt_um_waves dut (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  // Test sequence
  initial begin
    #100;
    rst_n = 1;    
    ena = 1;      

    #200;
    ui_in = 8'h41; 

    #500000;
    $finish;
  end

  // UART transmission simulation
  task uart_send(input [7:0] data);
    integer i;
    begin
      ui_in[0] = 0;
      #2604;  

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] = (data >> i) & 1;
        #2604;
      end

      ui_in[0] = 1;
      #2604;  
    end
  endtask

  // Test sequence for UART commands
  initial begin
    #100;
    uart_send(8'h54);  // 'T' for Triangle
    #1000;
    $display("Triangle: I2S SD: %b, selected_wave: %d", uo_out[2], selected_wave);

    uart_send(8'h53);  // 'S' for Sawtooth
    #1000;
    $display("Sawtooth: I2S SD: %b, selected_wave: %d", uo_out[2], selected_wave);

    uart_send(8'h51);  // 'Q' for Square
    #1000;
    $display("Square: I2S SD: %b, selected_wave: %d", uo_out[2], selected_wave);

    uart_send(8'h57);  // 'W' for Sine
    #1000;
    $display("Sine: I2S SD: %b, selected_wave: %d", uo_out[2], selected_wave);

    // Fix: Declare integer j before the loop
    integer j;
    for (j = 0; j < 10; j = j + 1) begin
      uart_send(8'h30 + j);
      #1000;
      $display("Freq %d: I2S SCK: %b", j, uo_out[0]);
    end

    // White Noise Test
    uart_send(8'h4E);  // Enable Noise
    #1000;
    $display("Noise On: I2S SD: %b, noise_out: %d", uo_out[2], noise_out);

    uart_send(8'h46);  // Disable Noise
    #1000;
    $display("Noise Off: I2S SD: %b, noise_out: %d", uo_out[2], noise_out);

    $finish;
  end
endmodule
