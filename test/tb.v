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

  // Precision UART Transmission Task (9600 baud)
  task uart_send(input [7:0] data);
    integer i;
    begin
      ui_in[0] = 1'b1;  // Idle state
      #100000;
      
      // Start bit
      ui_in[0] = 1'b0;
      #104167; // Exact 9600 baud period (1/9600 ≈ 104166.666ns)
      
      // Data bits (LSB first)
      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] = data[i];
        #104167;
      end
      
      // Stop bit
      ui_in[0] = 1'b1;
      #104167;
      $display("[TB] Sent UART: 0x%h (%s)", data, get_command_name(data));
    end
  endtask

  // Command Decoder for Debugging
  function string get_command_name(input [7:0] cmd);
    case(cmd)
      8'h54: return "Triangle Wave";
      8'h53: return "Sawtooth Wave";
      8'h51: return "Square Wave";
      8'h57: return "Sine Wave";
      8'h4E: return "Noise ON";
      8'h46: return "Noise OFF";
      8'h30: return "C2 (65.4Hz)";
      8'h5B: return "A4 (440Hz)";
      8'h7A: return "B6 (1975.5Hz)";
      default: return "Unknown Command";
    endcase
  endfunction

  // Enhanced Encoder Simulation with Direction
  task rotate_encoder(input [1:0] encoder_id, input integer steps, input clockwise);
    integer i;
    reg [1:0] base_pin;
    begin
      base_pin = encoder_id * 2;
      for (i = 0; i < steps; i = i + 1) begin
        if (clockwise) begin
          // Clockwise pattern
          uio_in[base_pin +: 2] = 2'b00; #400;
          uio_in[base_pin +: 2] = 2'b01; #400;
          uio_in[base_pin +: 2] = 2'b11; #400;
          uio_in[base_pin +: 2] = 2'b10; #400;
        end else begin
          // Counter-clockwise pattern
          uio_in[base_pin +: 2] = 2'b00; #400;
          uio_in[base_pin +: 2] = 2'b10; #400;
          uio_in[base_pin +: 2] = 2'b11; #400;
          uio_in[base_pin +: 2] = 2'b01; #400;
        end
      end
      $display("[TB] Encoder %0d rotated %0d steps %s",
               encoder_id, steps, clockwise ? "CW" : "CCW");
    end
  endtask

  // Improved I2S Data Capture with Basic Validation
  always @(negedge i2s_ws) begin
    captured_data <= 16'h0000;
    for (int i = 15; i >= 0; i--) begin
      @(negedge i2s_sck);
      captured_data[i] <= i2s_sd;
    end
    
    // Basic amplitude validation
    if (captured_data[15:8] > 8'd250) 
      $display("[I2S] WARNING: Potential clipping - Value: %0d", captured_data[15:8]);
    else
      $display("[I2S] Captured: %0d", captured_data[15:8]);
  end

  // Comprehensive Test Sequence
  initial begin
    // Wait for initialization
    #1500;

    // Test ADSR Parameters with different directions
    $display("\n=== Testing ADSR Parameters ===");
    rotate_encoder(0, 5, 1);   // Attack up
    rotate_encoder(1, 3, 0);   // Decay down
    rotate_encoder(2, 8, 1);   // Sustain up
    rotate_encoder(3, 4, 0);   // Release down
    #10000;

    // Full Waveform Test Suite
    $display("\n=== Waveform Validation Tests ===");
    uart_send(8'h5B);  // Select A4 (440Hz)
    
    test_waveform(8'h54, "Triangle");  // T
    test_waveform(8'h53, "Sawtooth");  // S
    test_waveform(8'h51, "Square");    // Q
    test_waveform(8'h57, "Sine");      // W
    
    // Noise Control Test
    $display("\n=== Noise Control Test ===");
    uart_send(8'h4E);  // Noise ON
    #20000;
    uart_send(8'h46);  // Noise OFF
    #10000;

    // Frequency Range Validation
    $display("\n=== Frequency Range Test ===");
    test_frequency(8'h30, "C2 (65.4Hz)");
    test_frequency(8'h39, "A2 (110Hz)");
    test_frequency(8'h5B, "A4 (440Hz)");
    test_frequency(8'h7A, "B6 (1975.5Hz)");

    // Test completion
    #5000;
    $display("\n[TB] All Tests Completed Successfully");
    $finish;
  end

  task test_waveform(input [7:0] cmd, string wave_name);
    begin
      $display("\nTesting %s Wave", wave_name);
      uart_send(cmd);
      #20000; // Allow 20us for waveform transition
      
      // Add waveform-specific checks here
      case(cmd)
        8'h51: // Square wave validation
          if (captured_data[15:8] != 8'd0 && captured_data[15:8] != 8'd255)
            $error("Invalid square wave value: %0d", captured_data[15:8]);
      endcase
    end
  endtask

  task test_frequency(input [7:0] freq_cmd, string freq_name);
    begin
      $display("Testing %s", freq_name);
      uart_send(freq_cmd);
      #10000; // Allow 10us for frequency change
      // Add frequency-specific checks here
    end
  endtask

endmodule