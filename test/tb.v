`default_nettype none
`timescale 1ns / 1ps

/* Testbench for tt_um_waves
   - Instantiates the module
   - Generates a 25 MHz clock (40 ns period)
   - Initializes reset and enable signals
*/
module tb ();

  // Dump the signals to a VCD file for waveform analysis
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

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Instantiate the module under test
  tt_um_waves user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // Enable - goes high when design is selected
      .clk    (clk),      // 25 MHz clock
      .rst_n  (rst_n)     // Active-low reset
  );

  // Test sequence
  initial begin
    #100;         // Wait for 100 ns
    rst_n = 1;    // Release reset
    ena = 1;      // Enable module

    #200;         // Wait for 200 ns
    ui_in = 8'h41; // Example UART command (ASCII 'A')

    #500000;      // Run for some time
    $finish;      // End simulation
  end

endmodule
