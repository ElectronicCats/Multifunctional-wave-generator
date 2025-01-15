`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Dump the signals to a VCD file. You can view it with GTKWave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Internal UART receiver signals
  wire white_noise_en;
  wire [2:0] wave_select;
  wire [5:0] freq_select;

  // Instantiate the DUT (Device Under Test)
  tt_um_waves user_project (
    .ui_in  (ui_in),
    .uo_out (uo_out),
    .uio_in (uio_in),
    .uio_out(uio_out),
    .uio_oe (uio_oe),
    .ena    (ena),
    .clk    (clk),
    .rst_n  (rst_n)
  );

  // Connect internal signals for monitoring
  assign white_noise_en = user_project.uart_rx_inst.white_noise_en;
  assign wave_select = user_project.uart_rx_inst.wave_select;
  assign freq_select = user_project.uart_rx_inst.freq_select;

  // Clock generation
  always #5 clk = ~clk;  // 10-unit clock period

  // Testbench initialization
  initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    ena = 0;
    ui_in = 8'b0;
    uio_in = 8'b0;

    // Apply reset
    #10 rst_n = 1;
    ena = 1;

    // Simulation duration
    #1000 $finish;
  end

endmodule
