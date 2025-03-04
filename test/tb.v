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
      @(posedge clk); #8680;  // Simulating 115200 baud

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] <= data[i];
        @(posedge clk); #8680;
      end

      ui_in[0] <= 1;  // Stop bit
      @(posedge clk); #8680;
    end
  endtask

  // Debug I2S Output
  always @(posedge clk) begin
    $display("I2S Debug: SCK=%b, WS=%b, SD=%b", 
             i2s_sck, i2s_ws, i2s_sd);
  end

  // Initial Waveform Selection via UART
  initial begin
    #200;
    uart_send(8'h54);  // 'T' for Triangle wave
    #1000;
    $display("Triangle wave test completed");
    
    uart_send(8'h57);  // 'W' for Sine wave
    uart_send(8'h41);  // Frequency A4 (440 Hz)
    
    #5000;
    $finish;
  end

  // Manually Set ADSR in Testbench
  initial begin
    #1000;
    $display("Testing ADSR...");
    uio_in = 8'b11000000; // Simulated encoder values
    #5000;
    $display("ADSR Test Complete.");
  end

endmodule
