`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
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

  // Clock generation
  always #5 clk = ~clk;  // 10ns clock period

  // Replace `tt_um_example` with your actual module name:
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
  #100000 $finish;
  end

  // Debugging: Monitor signals during simulation
  always @(posedge clk) begin
    $display("Time=%0dns | clk=%b | rst_n=%b | ena=%b | ui_in=%b | uo_out=%b | uio_in=%b | uio_out=%b | uio_oe=%b",
             $time, clk, rst_n, ena, ui_in, uo_out, uio_in, uio_out, uio_oe);
  end

endmodule
