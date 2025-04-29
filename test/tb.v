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
    #500;  // Reset duration
    rst_n = 1;
    #200;  // Stabilization
    ena = 1;    
    $display("[TB] Reset complete");
  end

  // UART Transmission Task
  task uart_send(input [7:0] data);
    integer i;
    begin
      $display("[TB] Sending UART: 0x%h (%s)", data, get_wave_name(data));
      ui_in[0] <= 0;  // Start bit
      repeat (2604) @(posedge clk);

      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] <= data[i];
        repeat (2604) @(posedge clk);
      end

      ui_in[0] <= 1;  // Stop bit
      repeat (2604) @(posedge clk);
    end
  endtask

  // Return waveform name for debug
  function string get_wave_name(input [7:0] data);
    case(data)
      8'h54: return "Triangle";
      8'h53: return "Sawtooth";
      8'h51: return "Square";
      8'h57: return "Sine";
      8'h4E: return "Noise ON";
      8'h46: return "Noise OFF";
      default: return "Frequency";
    endcase
  endfunction

  // Improved Encoder Rotation Task
  task rotate_encoder(input [1:0] encoder_id, input integer steps);
    integer i, j;
    reg [1:0] pins;
    begin
      pins = encoder_id * 2; // Calculate pin pair
      $display("[TB] Rotating encoder %0d (%0d steps)", encoder_id, steps);
      
      for (j = 0; j < steps; j = j + 1) begin
        // Clockwise rotation sequence
        uio_in[pins +: 2] = 2'b00; #100;
        uio_in[pins +: 2] = 2'b01; #100;
        uio_in[pins +: 2] = 2'b11; #100;
        uio_in[pins +: 2] = 2'b10; #100;
      end
    end
  endtask

  // I2S Data Capture
  reg [15:0] captured_data;
  always @(negedge i2s_ws) begin
    captured_data <= 16'h0000;
    fork
      begin
        for (int bitnum = 15; bitnum >= 0; bitnum--) begin
          @(negedge i2s_sck);
          captured_data[bitnum] <= i2s_sd;
        end
        $display("[TB] I2S Data: 0x%h (Scaled: %0d)", 
          captured_data, captured_data[15:8]);
      end
    join_none
  end

  // Main Test Sequence
  initial begin
    #1500;  // Post-reset delay

    // Test ADSR controls
    $display("\n=== Testing ADSR Encoders ===");
    rotate_encoder(0, 5);  // Attack
    rotate_encoder(1, 3);  // Decay
    rotate_encoder(2, 8);  // Sustain
    rotate_encoder(3, 4);  // Release
    #2000;

    // Test All Waveforms
    $display("\n=== Testing Waveforms ===");
    uart_send(8'h54);  // Triangle
    uart_send(8'h5B);  // A4 (440Hz)
    #10000;

    uart_send(8'h53);  // Sawtooth
    #10000;

    uart_send(8'h51);  // Square
    #10000;

    uart_send(8'h57);  // Sine
    #10000;

    uart_send(8'h4E);  // Noise ON
    #10000;
    uart_send(8'h46);  // Noise OFF
    #5000;

    // Test Frequency Range
    $display("\n=== Testing Frequencies ===");
    uart_send(8'h30);  // C2
    #5000;
    uart_send(8'h5B);  // A4
    #5000;
    uart_send(8'h7A);  // B6
    #5000;

    // Final check
    $display("\n[TB] All tests completed");
    $finish;
  end

endmodule