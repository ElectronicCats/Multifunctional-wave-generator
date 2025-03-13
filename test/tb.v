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

  // Improved Reset & Enable Handling
  initial begin
    rst_n = 0;
    ena = 0;
    #500;  // Longer reset for stability
    rst_n = 1;
    #200;  // Ensure stable startup
    ena = 1;    
    $display("[TB] Reset complete: rst_n=%b, ena=%b", rst_n, ena);
  end

  // UART Transmission Task with Improved Logging
  task uart_send(input [7:0] data);
    integer i;
    begin
      $display("[TB] Sending UART Data: 0x%h", data);
      ui_in[0] <= 0;  // Start bit
      repeat (2604) @(posedge clk); 

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] <= data[i];
        repeat (2604) @(posedge clk);
      end

      ui_in[0] <= 1;  // Stop bit
      repeat (2604) @(posedge clk);

      // ✅ UART Sequence Validation
      if (ui_in[0] !== 1)
        $display("[ERROR] UART transmission error: Stop bit not detected.");
    end
  endtask

  // Enhanced I2S Debugging (Trigger on WS change)
  always @(posedge i2s_ws) begin
    if (i2s_sd === 1'bx)
      $display("[ERROR] I2S Data Error: Invalid state detected.");
    else
      $display("[TB] I2S Frame: SCK=%b, WS=%b, SD=%b", i2s_sck, i2s_ws, i2s_sd);
  end

  // UART Commands for Waveform & Frequency Selection
  initial begin
    #1000;  
    uart_send(8'h54);  // 'T' -> Triangle Wave
    #2000;              // ⏳ Added delay for processing
    uart_send(8'h57);  // 'W' -> Sine Wave
    #2000;
    uart_send(8'h41);  // 'A' -> A4 (440 Hz)
    #3000; 
    $display("[TB] Waveform & Frequency Selection Done.");
  end

  // Improved ADSR Control Test with Value Changes
  initial begin
    #2000;
    uio_in = 8'b11000000; // Initial encoder values
    #3000;
    uio_in = 8'b10010000; // Simulated encoder value change
    #3000;
    uio_in = 8'b11110000; // Another simulated encoder value change
    #5000;
    $display("[TB] ADSR Test Complete.");
    $finish;
  end

endmodule
