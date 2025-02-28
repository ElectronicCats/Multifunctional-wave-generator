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

  // Debug I2S Output
  always @(posedge clk) begin
    $display("I2S Debug: SCK=%b, WS=%b, SD=%b | Waveform=%h | ADSR=%h", 
             i2s_sck, i2s_ws, i2s_sd, tb.dut.selected_wave, tb.dut.adsr_amplitude);
  end

  // Force Initial Waveform Selection
  initial begin
    #200;

    uart_send(8'h54);  // 'T' for Triangle wave
    #1000;
    $display("Triangle wave test completed");

    // FORCE wave selection and ADSR parameters
    force tb.dut.wave_select = 3'b011;  // Select sine wave
    force tb.dut.freq_select = 6'b100001;  // Set frequency (A4)
    force tb.dut.adsr_amplitude = 8'hFF;  // Max amplitude
    #5000;

    release tb.dut.wave_select;
    release tb.dut.freq_select;
    release tb.dut.adsr_amplitude;

    $finish;
  end

  // Manually Set ADSR in Testbench
  initial begin
    #1000;
    $display("Testing ADSR...");

    // Set attack, decay, sustain, release to nonzero values
    force tb.dut.attack = 8'd50;
    force tb.dut.decay = 8'd30;
    force tb.dut.sustain = 8'd128;
    force tb.dut.rel = 8'd40;

    #5000;
    release tb.dut.attack;
    release tb.dut.decay;
    release tb.dut.sustain;
    release tb.dut.rel;

    $display("ADSR Forced Settings Complete.");
  end

endmodule
