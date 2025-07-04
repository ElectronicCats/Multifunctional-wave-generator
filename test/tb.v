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
  real frequency;

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
      #104166;
      
      // Start bit
      ui_in[0] = 1'b0;
      #104166;
      
      // Data bits (LSB first)
      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] = data[i];
        #104166;
      end
      
      // Stop bit
      ui_in[0] = 1'b1;
      #104166;
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
      8'h39: return "A2 (110Hz)";
      8'h5B: return "A4 (440Hz)";
      8'h7A: return "B6 (1975.5Hz)";
      default: return "Unknown Command";
    endcase
  endfunction

  // Enhanced Encoder Simulation with Direction and Realistic Timing
  task rotate_encoder(input [1:0] encoder_id, input integer steps, input clockwise);
    integer i;
    reg [1:0] base_pin;
    reg [1:0] pattern [0:3];
    begin
      base_pin = encoder_id * 2;
      
      if (clockwise) begin
        pattern[0] = 2'b00;
        pattern[1] = 2'b01;
        pattern[2] = 2'b11;
        pattern[3] = 2'b10;
      end else begin
        pattern[0] = 2'b00;
        pattern[1] = 2'b10;
        pattern[2] = 2'b11;
        pattern[3] = 2'b01;
      end
      
      for (i = 0; i < steps; i = i + 1) begin
        uio_in[base_pin +: 2] = pattern[0]; #20000;
        uio_in[base_pin +: 2] = pattern[1]; #20000;
        uio_in[base_pin +: 2] = pattern[2]; #20000;
        uio_in[base_pin +: 2] = pattern[3]; #20000;
      end
      
      $display("[TB] Encoder %0d rotated %0d steps %s",
               encoder_id, steps, clockwise ? "CW" : "CCW");
    end
  endtask

  // Accurate I2S Frame Capture
  task capture_i2s_frame();
    begin
      // Wait for WS edge
      @(posedge i2s_ws);
      
      // Capture left channel (16 bits)
      for (int i = 15; i >= 0; i--) begin
        @(posedge i2s_sck);
        captured_data[i] = i2s_sd;
      end
      
      // Validate amplitude range
      if (captured_data[15:8] > 8'd250) 
        $display("[I2S] WARNING: Potential clipping - Value: %0d", captured_data[15:8]);
      else
        $display("[I2S] Captured: %0d", captured_data[15:8]);
    end
  endtask

  // ADSR Envelope Verification Task
  task verify_adsr();
    integer max_val, sustain_val, release_start;
    begin
      // Wait for attack peak
      capture_i2s_frame();
      while (captured_data[15:8] < 250) capture_i2s_frame();
      max_val = captured_data[15:8];
      $display("[ADSR] Attack peak: %0d", max_val);
      
      // Wait for sustain level
      repeat(10) capture_i2s_frame();
      while (captured_data[15:8] > max_val/2 + 10) capture_i2s_frame();
      sustain_val = captured_data[15:8];
      $display("[ADSR] Sustain level: %0d", sustain_val);
      
      // Trigger release
      rotate_encoder(3, 10, 0);  // Reduce release time
      #10000;
      
      // Verify release phase
      while (captured_data[15:8] > 10) capture_i2s_frame();
      $display("[ADSR] Release complete");
      
      // Validate sustain level
      if (sustain_val < max_val*0.6 && sustain_val > max_val*0.4)
        $display("[ADSR] Sustain level verified");
      else
        $error("Invalid sustain level: %0d (max: %0d)", sustain_val, max_val);
    end
  endtask

  // Frequency Measurement Task
  task measure_frequency();
    real period, last_edge;
    begin
      // Wait for WS rising edge
      @(posedge i2s_ws);
      last_edge = $realtime;
      
      // Measure time between 2 WS edges
      @(posedge i2s_ws);
      period = ($realtime - last_edge) / 1e9;  // in seconds
      frequency = 1.0 / period;
      
      $display("[FREQ] Measured: %0.1f Hz", frequency);
    end
  endtask

  // Comprehensive Test Sequence
  initial begin
    // Wait for initialization
    #1500;

    // Test ADSR Parameters
    $display("\n=== Testing ADSR Parameters ===");
    rotate_encoder(0, 5, 1);   // Attack up
    rotate_encoder(1, 3, 0);   // Decay down
    rotate_encoder(2, 8, 1);   // Sustain up
    rotate_encoder(3, 4, 0);   // Release down
    #10000;

    // ADSR Envelope Verification
    $display("\n=== ADSR Envelope Test ===");
    verify_adsr();
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
      
      // Capture 50 frames for analysis
      repeat(50) capture_i2s_frame();
    end
  endtask

  task test_frequency(input [7:0] freq_cmd, string freq_name);
    begin
      $display("Testing %s", freq_name);
      uart_send(freq_cmd);
      #10000; // Allow 10us for frequency change
      
      measure_frequency();
      
      // Validate frequency range
      case(freq_cmd)
        8'h30: if (frequency < 60 || frequency > 70) 
                 $error("C2 frequency out of range: %0.1f Hz", frequency);
        8'h39: if (frequency < 105 || frequency > 115) 
                 $error("A2 frequency out of range: %0.1f Hz", frequency);
        8'h5B: if (frequency < 435 || frequency > 445) 
                 $error("A4 frequency out of range: %0.1f Hz", frequency);
        8'h7A: if (frequency < 1970 || frequency > 1980) 
                 $error("B6 frequency out of range: %0.1f Hz", frequency);
      endcase
    end
  endtask

endmodule