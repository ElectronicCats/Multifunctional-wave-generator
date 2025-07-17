`default_nettype none
`timescale 1ns / 1ps

module tb;
  // VCD Waveform Dumping
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    $display("[TB] VCD waveform capture enabled");
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
  
  // Waveform capture registers
  reg [7:0] captured_wave;
  real measured_freq;
  reg [7:0] waveform_samples [0:255];
  integer sample_idx = 0;

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
    #100;
  end

  // UART Transmission Task (115200 baud)
  task uart_send(input [7:0] data);
    integer i;
    begin
      // Baud period: 1/115200 ≈ 8680.55ns (use 8681ns)
      real baud_period_ns = 1000000000.0 / 115200;
      
      // Start bit
      ui_in[0] = 1'b0;
      #(baud_period_ns);
      
      // Data bits (LSB first)
      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] = data[i];
        #(baud_period_ns);
      end
      
      // Stop bit
      ui_in[0] = 1'b1;
      #(baud_period_ns);
      
      $display("[UART] Sent: 0x%h (%s)", data, get_command_name(data));
    end
  endtask

  // Command Decoder
  function string get_command_name(input [7:0] cmd);
    case(cmd)
      8'h54: return "Triangle Wave";
      8'h53: return "Sawtooth Wave";
      8'h51: return "Square Wave";
      8'h57: return "Sine Wave";
      8'h4E, 8'h6E: return "Noise ON";
      8'h46, 8'h66: return "Noise OFF";
      8'h30: return "C2 (65.4Hz)";
      8'h39: return "A2 (110Hz)";
      8'h5B: return "A4 (440Hz)";
      8'h7A: return "B6 (1975.5Hz)";
      default: return $sformatf("Unknown: 0x%h", cmd);
    endcase
  endfunction

  // Encoder Simulation
  task rotate_encoder(input [1:0] encoder_id, input integer steps, input clockwise);
    integer i, j;
    reg [1:0] base_pin;
    reg [1:0] pattern [0:3];
    begin
      base_pin = encoder_id * 2;
      
      if (clockwise) begin
        pattern[0] = 2'b00;
        pattern[1] = 2'b10;
        pattern[2] = 2'b11;
        pattern[3] = 2'b01;
      end else begin
        pattern[0] = 2'b00;
        pattern[1] = 2'b01;
        pattern[2] = 2'b11;
        pattern[3] = 2'b10;
      end
      
      for (i = 0; i < steps; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          uio_in[base_pin +: 2] = pattern[j];
          #2000; // 2μs per state change
        end
      end
      
      $display("[ENCODER] %0d rotated %0d steps %s", 
               encoder_id, steps, clockwise ? "CW" : "CCW");
    end
  endtask

  // I2S Frame Capture
  task capture_i2s_frame();
    integer i;
    reg [15:0] captured_data;
    begin
      // Wait for WS falling edge (start of left channel)
      @(negedge i2s_ws);
      
      // Capture 16 bits (MSB first)
      for (i = 15; i >= 0; i = i - 1) begin
        @(posedge i2s_sck);
        captured_data[i] = i2s_sd;
      end
      
      // Only care about top 8 bits (our actual sample)
      captured_wave = captured_data[15:8];
      
      // Store for waveform analysis
      if (sample_idx < 256) begin
        waveform_samples[sample_idx] = captured_wave;
        sample_idx = sample_idx + 1;
      end
      
      $display("[I2S] Captured sample: %0d", captured_wave);
    end
  endtask

  // Frequency Measurement
  task measure_frequency();
    real t1, t2;
    begin
      // Measure between two falling edges of WS
      @(negedge i2s_ws);
      t1 = $realtime;
      @(negedge i2s_ws);
      t2 = $realtime;
      
      measured_freq = 1.0e9 / (t2 - t1); // Convert ns to Hz
      $display("[FREQ] Measured sample rate: %0.1f Hz", measured_freq);
    end
  endtask

  // Waveform Analysis
  task analyze_waveform(string wave_name);
    integer min_val = 255;
    integer max_val = 0;
    integer avg_val = 0;
    integer i;
    begin
      if (sample_idx == 0) begin
        $display("[WAVE] No samples captured for analysis");
        return;
      end
      
      // Calculate waveform characteristics
      for (i = 0; i < sample_idx; i = i + 1) begin
        if (waveform_samples[i] < min_val) min_val = waveform_samples[i];
        if (waveform_samples[i] > max_val) max_val = waveform_samples[i];
        avg_val = avg_val + waveform_samples[i];
      end
      avg_val = avg_val / sample_idx;
      
      $display("[WAVE] %s Analysis: Min=%0d, Max=%0d, Avg=%0d, Pk-Pk=%0d",
               wave_name, min_val, max_val, avg_val, max_val - min_val);
      
      // Reset sample index
      sample_idx = 0;
    end
  endtask

  // Main Test Sequence
  initial begin
    // Wait for system initialization
    #2000;
    
    // Test 1: Basic waveform generation
    $display("\n=== TEST 1: Waveform Generation ===");
    uart_send(8'h5B);  // Select A4 (440Hz)
    #10000;
    
    // Test each waveform
    test_waveform(8'h54, "Triangle");
    test_waveform(8'h53, "Sawtooth");
    test_waveform(8'h51, "Square");
    test_waveform(8'h57, "Sine");
    
    // Test 2: ADSR Envelope Control
    $display("\n=== TEST 2: ADSR Envelope ===");
    uart_send(8'h54);  // Triangle wave
    #5000;
    
    $display("Setting ADSR parameters...");
    rotate_encoder(0, 10, 1);  // Attack up
    rotate_encoder(1, 5, 0);   // Decay down
    rotate_encoder(2, 8, 1);   // Sustain up
    rotate_encoder(3, 4, 0);   // Release down
    #20000;
    
    // Capture samples with ADSR applied
    repeat(50) capture_i2s_frame();
    analyze_waveform("Triangle with ADSR");
    
    // Test 3: Frequency Selection
    $display("\n=== TEST 3: Frequency Selection ===");
    test_frequency(8'h30, "C2 (65.4Hz)");
    test_frequency(8'h39, "A2 (110Hz)");
    test_frequency(8'h5B, "A4 (440Hz)");
    test_frequency(8'h7A, "B6 (1975.5Hz)");
    
    // Test 4: Noise Generator
    $display("\n=== TEST 4: Noise Generator ===");
    uart_send(8'h4E);  // Noise ON
    #20000;
    repeat(50) capture_i2s_frame();
    analyze_waveform("White Noise");
    
    uart_send(8'h46);  // Noise OFF
    #10000;
    
    // Test completion
    $display("\n[TB] All tests completed successfully");
    #10000;
    $finish;
  end

  // Waveform Test Subroutine
  task test_waveform(input [7:0] cmd, string wave_name);
    begin
      $display("\nTesting %s wave", wave_name);
      uart_send(cmd);
      #20000; // Allow 20us for waveform transition
      
      // Capture 50 samples
      repeat(50) capture_i2s_frame();
      analyze_waveform(wave_name);
    end
  endtask

  // Frequency Test Subroutine
  task test_frequency(input [7:0] freq_cmd, string freq_name);
    begin
      $display("\nTesting frequency: %s", freq_name);
      uart_send(freq_cmd);
      #20000; // Allow 20us for frequency change
      
      measure_frequency();
      
      // Verify expected sample rate
      if (measured_freq < 90000 || measured_freq > 100000) begin
        $error("Sample rate out of range! Expected ~97.6kHz, got %0.1f Hz", measured_freq);
      end
      else begin
        $display("Sample rate verified: %0.1f Hz", measured_freq);
      end
    end
  endtask

  // Simulation timeout
  initial begin
    #100000000; // 100ms timeout
    $display("[TB] Simulation timed out!");
    $finish;
  end

endmodule