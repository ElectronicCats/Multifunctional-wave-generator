`default_nettype none
`timescale 1ns / 1ps

module tb;
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

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
  
  reg [7:0] captured_wave;
  integer measured_freq;
  reg [7:0] waveform_samples [0:255];
  integer sample_idx = 0;

  tt_um_waves dut (.*);

  initial begin
    rst_n = 0;
    ena = 0;
    #500 rst_n = 1;
    #200 ena = 1;
    #100;
  end

  task uart_send(input [7:0] data);
    integer i;
    integer baud_period_ns = 8681;  // 1e9/115200 ≈ 8680.55ns
    begin
      ui_in[0] = 1'b0;
      #baud_period_ns;
      for (i = 0; i < 8; i = i + 1) begin
        ui_in[0] = data[i];
        #baud_period_ns;
      end
      ui_in[0] = 1'b1;
      #baud_period_ns;
    end
  endtask

  task rotate_encoder(input [1:0] encoder_id, input integer steps, input clockwise);
    integer i, j;
    reg [1:0] base_pin;
    reg [1:0] pattern [0:3];
    begin
      base_pin = encoder_id * 2;
      if (clockwise) begin
        pattern[0] = 2'b00; pattern[1] = 2'b10;
        pattern[2] = 2'b11; pattern[3] = 2'b01;
      end else begin
        pattern[0] = 2'b00; pattern[1] = 2'b01;
        pattern[2] = 2'b11; pattern[3] = 2'b10;
      end
      for (i = 0; i < steps; i = i + 1) begin
        for (j = 0; j < 4; j = j + 1) begin
          uio_in[base_pin +: 2] = pattern[j];
          #40;  // Fixed: One clock cycle (25MHz)
        end
      end
    end
  endtask

  task capture_i2s_frame();
    integer i;
    reg [15:0] captured_data;
    begin
      @(negedge i2s_ws);
      for (i = 15; i >= 0; i = i - 1) begin
        @(posedge i2s_sck);
        captured_data[i] = i2s_sd;
      end
      captured_wave = captured_data[15:8];
      if (sample_idx < 256) begin
        waveform_samples[sample_idx] = captured_wave;
        sample_idx = sample_idx + 1;
      end
    end
  endtask

  task measure_frequency();
    integer t1, t2;
    begin
      @(negedge i2s_ws);
      t1 = $time;
      @(negedge i2s_ws);
      t2 = $time;
      measured_freq = 1000000000 / (t2 - t1);
      // Verify 48kHz frame rate (±2%)
      if (measured_freq < 47000 || measured_freq > 49000) begin
        $error("Sample rate error: %0d Hz", measured_freq);
      end
    end
  endtask

  task analyze_waveform(input string wave_name);
    integer min_val = 255;
    integer max_val = 0;
    integer avg_val = 0;
    integer i;
    begin
      if (sample_idx > 0) begin
        for (i = 0; i < sample_idx; i = i + 1) begin
          if (waveform_samples[i] < min_val) min_val = waveform_samples[i];
          if (waveform_samples[i] > max_val) max_val = waveform_samples[i];
          avg_val = avg_val + waveform_samples[i];
        end
        avg_val = avg_val / sample_idx;
        $display("%s: Min=%0d, Max=%0d, Avg=%0d", 
                 wave_name, min_val, max_val, avg_val);
        sample_idx = 0;
      end
    end
  endtask

  initial begin
    #2000;
    uart_send(8'h5B);  // A4
    #10000;
    
    uart_send(8'h54);  // Triangle
    #20000; 
    repeat(50) capture_i2s_frame();
    analyze_waveform("Triangle");
    
    // ... similar for other waveforms ...
    
    // ADSR Test
    uart_send(8'h54);  // Triangle
    #5000;
    rotate_encoder(0, 10, 1);  // Attack up
    rotate_encoder(2, 8, 1);   // Sustain up
    #20000;
    repeat(50) capture_i2s_frame();
    analyze_waveform("Triangle+ADSR");
    
    // Frequency Test
    uart_send(8'h30);  // C2
    #20000;
    measure_frequency();
    
    #10000 $finish;
  end

  initial #100000000 $finish;  // Timeout
endmodule