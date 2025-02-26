`default_nettype none
`timescale 1ns / 1ps

/* Testbench for tt_um_waves */

module tb;

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb, dut.attack, dut.decay, dut.sustain, dut.rel, dut.selected_wave, dut.scaled_wave);
  end

  reg clk = 0;
  always #20 clk = ~clk;

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

  initial begin
    #100;
    rst_n = 1;
    #100;
    ena = 1;

    #200;
    ui_in = 8'h41; // Arbitrary UART input

    #500000;
    $finish;
  end

  // UART transmission simulation (for frequency and waveform selection)
  task uart_send(input [7:0] data);
    reg [3:0] i;
    begin
      ui_in[0] <= 0;  // Start bit
      @(posedge clk); #200;

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] <= data[i];
        @(posedge clk); #200;
      end

      ui_in[0] <= 1;  // Stop bit
      @(posedge clk); #200;
    end
  endtask

  // Testing frequency and waveform selection via UART
  initial begin
    #200;

    uart_send(8'h54);  // 'T' for Triangle wave
    #500;
    if (uo_out[2:0] === 3'b000) 
        $display("ERROR: Triangle wave not generated!");
    else 
        $display("Triangle wave successfully generated!");

    uart_send(8'h51);  // 'Q' for Square wave
    #500;
    if (uo_out[2:0] === 3'b000) 
        $display("ERROR: Square wave not generated!");
    else 
        $display("Square wave successfully generated!");

    uart_send(8'h57);  // 'W' for Sine wave (CORDIC)
    #500;
    if (uo_out[2:0] === 3'b000) 
        $display("ERROR: Sine wave not generated!");
    else 
        $display("Sine wave successfully generated!");

    for (int j = 0; j < 10; j = j + 1) begin
      uart_send(8'h30 + j);
      #500;
      $display("Freq %d Selected - I2S SD: %b", j, i2s_sd);
    end

    $finish;
  end

  // Testing ADSR using Encoders (via `uio_in`)
  initial begin
    #1000;

    $display("Testing Encoder Control for ADSR...");

    // Simulate increasing attack using rotary encoder (uio_in[0] and uio_in[1])
    uio_in = 8'b0000_0001; 
    #5000;
    uio_in = 8'b0000_0010; 
    #5000;
    uio_in = 8'b0000_0000; // Stop rotating
    #5000;
    $display("ADSR Attack Level: %d", dut.attack);

    // Simulate increasing decay using rotary encoder (uio_in[2] and uio_in[3])
    uio_in = 8'b0000_0100; 
    #5000;
    uio_in = 8'b0000_1000; 
    #5000;
    uio_in = 8'b0000_0000; // Stop rotating
    #5000;
    $display("ADSR Decay Level: %d", dut.decay);

    // Simulate increasing sustain using rotary encoder (uio_in[4] and uio_in[5])
    uio_in = 8'b0001_0000; 
    #5000;
    uio_in = 8'b0010_0000; 
    #5000;
    uio_in = 8'b0000_0000; // Stop rotating
    #5000;
    $display("ADSR Sustain Level: %d", dut.sustain);

    // Simulate increasing release using rotary encoder (uio_in[6] and uio_in[7])
    uio_in = 8'b0100_0000; 
    #5000;
    uio_in = 8'b1000_0000; 
    #5000;
    uio_in = 8'b0000_0000; // Stop rotating
    #5000;
    $display("ADSR Release Level: %d", dut.rel);

    $display("ADSR Encoder Testing Complete.");
    #2000;
  end

endmodule
