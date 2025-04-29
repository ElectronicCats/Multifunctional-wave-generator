`define default_netname none

module tt_um_waves (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // Will go high when the design is enabled
    input  wire       clk,      // Clock
    input  wire       rst_n     // Active-low reset
);
  
    // UART Signals
    wire [5:0] freq_select;
    wire [2:0] wave_select;
    reg        white_noise_en;
    
    // ADSR Control
    wire [7:0] adsr_amplitude;
    reg [15:0] temp_wave; 
    reg [7:0] attack, decay, sustain, rel; 
  
    wire unused_ui_in = |ui_in[7:1]; 
    wire unused_temp_wave = |temp_wave[7:0];

    // Frequency Divider
    reg [20:0] freq_divider;
    reg [20:0] clk_div;
    reg wave_clk;
    reg [5:0] prev_freq_select;
    wire [20:0] uart_freq_divider;

  
    // Phase accumulator for all waveforms
    reg [7:0] phase_accum;

    // Phase accumulator update with correct scaling 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_accum <= 8'd0;
        end else if (ena && freq_select != 6'b000000) begin
            phase_accum <= phase_accum + {2'b00, freq_select} + 1;
            $display("Phase Accumulator Updated: %d, Freq Select: %b, Ena: %b", phase_accum, freq_select, ena);
        end
    end


    // Clock Divider for waveform clocking
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 0;
            wave_clk <= 0;
        end else if (clk_div >= (freq_divider >> 1) && freq_divider > 0) begin
            clk_div <= 0;
            wave_clk <= ~wave_clk;
        end else begin
            clk_div <= clk_div + 1;
        end
    end
  
    // Frequency Divider Assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_freq_select <= 6'b000001;
            freq_divider <= 21'd1915712;
        end else if (freq_select != prev_freq_select || prev_freq_select == 6'b000000) begin
            prev_freq_select <= freq_select;
            freq_divider <= uart_freq_divider;
        end
    end


    // UART Receiver
    uart_receiver uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(ui_in[0]),
        .freq_select(freq_select),
        .wave_select(wave_select),
        .white_noise_en(white_noise_en),
        .freq_divider(uart_freq_divider)
    );

    // Encoders for ADSR
    encoder attack_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[0]), .b(uio_in[1]), .value(attack), .ena(ena));
    encoder decay_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[2]), .b(uio_in[3]), .value(decay), .ena(ena));
    encoder sustain_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[4]), .b(uio_in[5]), .value(sustain), .ena(ena));
    encoder release_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[6]), .b(uio_in[7]), .value(rel), .ena(ena));

    // Wave generators 
    wire [7:0] tri_wave_out, saw_wave_out, sqr_wave_out, sine_wave_out;
    wire [7:0] noise_out;

    square_wave_generator sqr_gen (.clk(clk), .rst_n(rst_n), .ena(ena), .phase(phase_accum), .wave_out(sqr_wave_out));
    triangular_wave_generator tri_gen (.clk(clk), .rst_n(rst_n), .ena(ena), .phase(phase_accum), .wave_out(tri_wave_out));
    sawtooth_wave_generator saw_gen (.clk(clk), .rst_n(rst_n), .ena(ena), .phase(phase_accum), .wave_out(saw_wave_out));
    white_noise_generator noise_gen (.clk(clk), .rst_n(rst_n), .noise_out(noise_out), .ena(white_noise_en & ena));
    cordic_sine_generator sine_gen (.clk(clk), .rst_n(rst_n), .ena(ena), .phase(phase_accum), .sine_out(sine_wave_out));

    // Select waveform output
    reg [7:0] selected_wave;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) selected_wave <= 8'd128;
        else begin
            case (wave_select)
                3'b000: selected_wave <= tri_wave_out;
                3'b001: selected_wave <= saw_wave_out;
                3'b010: selected_wave <= sqr_wave_out;
                3'b011: selected_wave <= sine_wave_out;
                3'b100: selected_wave <= noise_out;
                default: selected_wave <= 8'd128;
            endcase
        end
    end



    // ADSR generator
    adsr_generator adsr_gen (
        .clk(clk), 
        .rst_n(rst_n),
        .attack(attack), 
        .decay(decay),
        .sustain(sustain), 
        .rel(rel),
        .amplitude(adsr_amplitude), 
        .ena(ena)
    );


    // Apply ADSR Envelope to waveform output
    reg [7:0] scaled_wave;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_wave <= 16'd0;
            scaled_wave <= 8'd10;
        end else begin
            temp_wave <= (selected_wave * adsr_amplitude) >> 8;
            scaled_wave <= (temp_wave[15:8] > 8'd10) ? temp_wave[15:8] : 8'd10;
            $display("ADSR Amplitude: %d, Scaled Wave: %d", adsr_amplitude, scaled_wave);
        end
    end

  
    wire i2s_sck, i2s_ws, i2s_sd;
    i2s_transmitter i2s_out (
        .clk(clk),
        .rst_n(rst_n),
        .data(scaled_wave), 
        .sck(i2s_sck),
        .ws(i2s_ws),
        .sd(i2s_sd),
        .ena(ena)
    );

    // I2S Output
    assign uo_out[0] = i2s_sck;
    assign uo_out[1] = i2s_ws;
    assign uo_out[2] = i2s_sd;
    assign uo_out[7:3] = 5'b00000;
    assign uio_out = 8'b0;     
    assign uio_oe = 8'b0;      

endmodule


module uart_receiver (
    input wire clk,
    input wire rst_n,
    input wire rx,
    output reg [5:0] freq_select,
    output reg [2:0] wave_select,
    output reg white_noise_en,
    output reg [20:0] freq_divider
);

    parameter BAUD_TICKS = 2604;
    
    reg [31:0] baud_counter;
    reg [7:0] received_byte;
    reg [2:0] bit_count;
    reg receiving;
    reg [5:0] temp_freq;

    typedef enum logic [1:0] {
        IDLE       = 2'b00,
        RECEIVING  = 2'b01,
        PROCESSING = 2'b10
    } uart_state_t;

    uart_state_t state;

    reg rx_last;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) rx_last <= 1'b1;
        else rx_last <= rx;
    end
    wire start_bit = (rx_last && !rx);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            received_byte   <= 8'd0;
            bit_count       <= 3'd0;
            receiving       <= 1'b0;
            freq_select     <= 6'd9;
            wave_select     <= 3'd0;
            white_noise_en  <= 1'b0;
            freq_divider    <= 21'd1136364;
            state           <= IDLE;
            baud_counter    <= 0;
            temp_freq       <= 6'd9;
        end else begin
            case (state)
                IDLE: begin
                    if (start_bit && !receiving) begin
                        receiving <= 1'b1;
                        state <= RECEIVING;
                        baud_counter <= 0;
                        bit_count <= 0;
                    end
                end

                RECEIVING: begin
                    if (baud_counter == (BAUD_TICKS >> 1)) begin
                        received_byte[bit_count] <= rx;
                        if (bit_count < 3'd7) begin
                            bit_count <= bit_count + 1;
                        end else begin
                            receiving <= 1'b0;
                            state <= PROCESSING;
                        end
                        baud_counter <= 0;
                    end else begin
                        baud_counter <= baud_counter + 1;
                    end
                end

                PROCESSING: begin
                    white_noise_en <= white_noise_en;
                    wave_select <= wave_select;
                    temp_freq <= temp_freq;

                    case (received_byte)
                        // Wave controls
                        8'h4E: white_noise_en <= 1'b1;  // N
                        8'h46: white_noise_en <= 1'b0;  // F
                        8'h54: wave_select <= 3'b000;   // T
                        8'h53: wave_select <= 3'b001;   // S
                        8'h51: wave_select <= 3'b010;   // Q
                        8'h57: wave_select <= 3'b011;   // W

                        // Full frequency mapping (adjusted to skip 8'h46)
			8'h30: temp_freq <= 6'd0;   8'h31: temp_freq <= 6'd1;
			8'h32: temp_freq <= 6'd2;   8'h33: temp_freq <= 6'd3;
			8'h34: temp_freq <= 6'd4;   8'h35: temp_freq <= 6'd5;
			8'h36: temp_freq <= 6'd6;   8'h37: temp_freq <= 6'd7;
			8'h38: temp_freq <= 6'd8;   8'h39: temp_freq <= 6'd9;
			8'h61: temp_freq <= 6'd10;  8'h62: temp_freq <= 6'd11;
			8'h41: temp_freq <= 6'd12;  8'h42: temp_freq <= 6'd13;
			8'h43: temp_freq <= 6'd14;  8'h44: temp_freq <= 6'd15;
			8'h45: temp_freq <= 6'd16;  // 'E' (was 6'd16)
			8'h47: temp_freq <= 6'd17;  // 'G' (now 6'd17 instead of 6'd18)
			8'h48: temp_freq <= 6'd18;  8'h49: temp_freq <= 6'd19;
			8'h4A: temp_freq <= 6'd20;  8'h4B: temp_freq <= 6'd21;
			8'h4C: temp_freq <= 6'd22;  8'h4D: temp_freq <= 6'd23;
			8'h4F: temp_freq <= 6'd24;  8'h50: temp_freq <= 6'd25;
			8'h52: temp_freq <= 6'd26;  8'h55: temp_freq <= 6'd27;
			8'h56: temp_freq <= 6'd28;  8'h58: temp_freq <= 6'd29;
			8'h59: temp_freq <= 6'd30;  8'h5A: temp_freq <= 6'd31;
			8'h5B: temp_freq <= 6'd32;  8'h5D: temp_freq <= 6'd33;
			8'h5E: temp_freq <= 6'd34;  8'h63: temp_freq <= 6'd35;
			8'h64: temp_freq <= 6'd36;  8'h65: temp_freq <= 6'd37;
			8'h66: temp_freq <= 6'd38;  8'h67: temp_freq <= 6'd39;
			8'h68: temp_freq <= 6'd40;  8'h69: temp_freq <= 6'd41;
			8'h6A: temp_freq <= 6'd42;  8'h6B: temp_freq <= 6'd43;
			8'h6C: temp_freq <= 6'd44;  8'h6D: temp_freq <= 6'd45;
			8'h6E: temp_freq <= 6'd46;  8'h6F: temp_freq <= 6'd47;
			8'h70: temp_freq <= 6'd48;  8'h71: temp_freq <= 6'd49;
			8'h72: temp_freq <= 6'd50;  8'h73: temp_freq <= 6'd51;
			8'h74: temp_freq <= 6'd52;  8'h75: temp_freq <= 6'd53;
			8'h76: temp_freq <= 6'd54;  8'h77: temp_freq <= 6'd55;
			8'h78: temp_freq <= 6'd56;  8'h79: temp_freq <= 6'd57;
			8'h7A: temp_freq <= 6'd58; 

			// Default case for remaining values
			default: temp_freq <= 6'd9;   // Fallback to A2
                    		endcase

                    freq_select <= temp_freq;
                    
                    // Complete frequency divider mapping
                    case (temp_freq)
                        0:  freq_divider <= 21'd1915712;  1:  freq_divider <= 21'd1803586;
                        2:  freq_divider <= 21'd1702624;  3:  freq_divider <= 21'd1607142;
                        4:  freq_divider <= 21'd1515152;  5:  freq_divider <= 21'd1431731;
                        6:  freq_divider <= 21'd1351351;  7:  freq_divider <= 21'd1275510;
                        8:  freq_divider <= 21'd1204819;  9:  freq_divider <= 21'd1136364;
                        10: freq_divider <= 21'd1075268; 11: freq_divider <= 21'd1017340;
                        12: freq_divider <= 21'd95786;   13: freq_divider <= 21'd90180;
                        14: freq_divider <= 21'd85131;   15: freq_divider <= 21'd80357;
                        16: freq_divider <= 21'd75758;   17: freq_divider <= 21'd71586;
                        18: freq_divider <= 21'd67567;   19: freq_divider <= 21'd63775;
                        20: freq_divider <= 21'd60241;   21: freq_divider <= 21'd56818;
                        22: freq_divider <= 21'd53763;   23: freq_divider <= 21'd50867;
                        24: freq_divider <= 21'd47878;   25: freq_divider <= 21'd45090;
                        26: freq_divider <= 21'd42566;   27: freq_divider <= 21'd40178;
                        28: freq_divider <= 21'd37878;   29: freq_divider <= 21'd35793;
                        30: freq_divider <= 21'd33783;   31: freq_divider <= 21'd31888;
                        32: freq_divider <= 21'd30120;   33: freq_divider <= 21'd28409;
                        34: freq_divider <= 21'd26881;   35: freq_divider <= 21'd25434;
                        36: freq_divider <= 21'd23939;   37: freq_divider <= 21'd22545;
                        38: freq_divider <= 21'd21283;   39: freq_divider <= 21'd20089;
                        40: freq_divider <= 21'd18938;   41: freq_divider <= 21'd17896;
                        42: freq_divider <= 21'd16891;   43: freq_divider <= 21'd15944;
                        44: freq_divider <= 21'd15060;   45: freq_divider <= 21'd14204;
                        46: freq_divider <= 21'd13441;   47: freq_divider <= 21'd12717;
                        48: freq_divider <= 21'd11969;   49: freq_divider <= 21'd11272;
                        50: freq_divider <= 21'd10642;   51: freq_divider <= 21'd10044;
                        52: freq_divider <= 21'd9470;    53: freq_divider <= 21'd8948;
                        54: freq_divider <= 21'd8445;    55: freq_divider <= 21'd7972;
                        56: freq_divider <= 21'd7518;    57: freq_divider <= 21'd7090;
                        58: freq_divider <= 21'd6719;    59: freq_divider <= 21'd6358;
                        default: freq_divider <= 21'd1136364;
                    endcase

                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule



module white_noise_generator (
    input wire clk,
    input wire rst_n,
    output reg [7:0] noise_out,
    input wire ena
);
    reg [15:0] lfsr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'hACE1; 
            noise_out <= 8'd0;
        end else if (ena) begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]}; 
            noise_out <= lfsr[15:8]; 
        end
    end
endmodule



module i2s_transmitter (
    input wire clk,        
    input wire rst_n,      
    input wire ena,        
    input wire [7:0] data, 
    output reg sck,        
    output reg ws,         
    output reg sd          
);

    reg [3:0] bit_counter;  
    reg [15:0] shift_reg;   
    reg [7:0] clk_div;      

    parameter SCK_DIV = 8;  

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div    <= 0;
            sck        <= 0;
            ws         <= 0;
            sd         <= 0;
            bit_counter <= 0;
            shift_reg  <= 16'd0;
        end else if (ena) begin
            if (clk_div == (SCK_DIV - 1)) begin
                clk_div <= 0;
                sck <= ~sck;
            end else begin
                clk_div <= clk_div + 1;
            end

            if (sck == 0) begin  
                if (bit_counter == 0) begin
                    ws <= ~ws;  
                    shift_reg <= {data, 8'd0}; // Always load correct data
                end else begin
                    shift_reg <= shift_reg << 1;
                end
                sd <= shift_reg[15];

                if (bit_counter == 15)
                    bit_counter <= 0; // Ensure proper reset
                else
                    bit_counter <= bit_counter + 1;
            end
        end else begin
            sck <= 0;
            ws <= 0;
            sd <= 0;
            bit_counter <= 0;
        end
    end
endmodule




module cordic_sine_generator (
    input  wire clk,
    input  wire rst_n,
    input  wire ena,
    input  wire [7:0] phase,  // 8-bit phase input (0-255)
    output reg  [7:0] sine_out // 8-bit output (0-255 centered at 128)
);

    // CORDIC parameters
    reg signed [15:0] x, y, z;
    reg [3:0] i; // Iteration counter (0-7)
    reg signed [15:0] atan_value;

    // CORDIC gain compensation (1/1.64676 ≈ 0.60725 in Q1.15)
    localparam signed [15:0] CORDIC_GAIN = 16'h4DB4; // 0.60725 * 32767 ≈ 19912

    // Arctangent table (atan(2^-i) in Q1.15 format)
    localparam signed [15:0] atan_table[0:7] = '{
        16'h6488, // i=0: atan(1)   = π/4  ≈ 25736 (0.7854 rad)
        16'h3B52, // i=1: atan(0.5) ≈ 15186 (0.4636 rad)
        16'h1F5B, // i=2: atan(0.25)
        16'h0FEB, // i=3: atan(0.125)
        16'h07FD, // i=4: atan(0.0625)
        16'h03FF, // i=5: atan(0.03125)
        16'h01FF, // i=6: atan(0.015625)
        16'h00FF  // i=7: atan(0.0078125)
    };

    // Phase scaling: 8-bit phase → 16-bit angle (0-2π)
    wire signed [15:0] phase_scaled = {phase, 8'b0}; // Multiply by 256

    // Arctangent lookup
    always @(*) begin
        atan_value = atan_table[i[2:0]]; // Select based on iteration
    end

    // Main CORDIC processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset initialization
            x <= CORDIC_GAIN;
            y <= 16'd0;
            z <= 16'd0;
            i <= 4'd0;
            sine_out <= 8'd128; // Midpoint
        end else if (ena) begin
            if (i == 0) begin
                // Load new phase angle every 8 cycles
                z <= phase_scaled;
            end

            if (i < 8) begin
                // CORDIC iteration
                if (z[15]) begin // Negative angle
                    x <= x + (y >>> i);
                    y <= y - (x >>> i);
                    z <= z + atan_value;
                end else begin  // Positive angle
                    x <= x - (y >>> i);
                    y <= y + (x >>> i);
                    z <= z - atan_value;
                end
                i <= i + 1;
            end else begin
                // Convert to 8-bit unsigned (0-255)
                sine_out <= (y[15:8] + 8'h80); // Signed→unsigned conversion
                i <= 4'd0; // Reset for next calculation
            end
        end
    end

endmodule



module triangular_wave_generator (
    input  wire       ena,        
    input  wire       clk,        
    input  wire       rst_n,      
    input  wire [7:0] phase,  
    output reg  [7:0] wave_out    
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wave_out <= 8'd128;  // Set to mid-level instead of zero
        else if (ena) begin
            wave_out <= phase[7] ? (8'd255 - ({1'b0, phase[6:0]} << 1)) : ({1'b0, phase[6:0]} << 1);
            $display("Triangular Wave: Phase = %d, Output = %d", phase, wave_out);
        end else begin
            wave_out <= 8'd128; // Maintain mid-level when disabled
        end
    end
endmodule



module sawtooth_wave_generator (
    input  wire       ena,        
    input  wire       clk,        
    input  wire       rst_n,      
    input  wire [7:0] phase,  
    output reg  [7:0] wave_out    
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wave_out <= 8'd128; // Start at mid-level
        else if (ena)
            wave_out <= phase; // Directly use phase as sawtooth wave
        else
            wave_out <= 8'd128; // Maintain mid-level when disabled

        $display("Sawtooth Wave: Phase = %d, Output = %d", phase, wave_out);
    end
endmodule


module adsr_generator (
    input  wire        ena,        
    input  wire        clk,        
    input  wire        rst_n,      
    input  wire [7:0]  attack,     
    input  wire [7:0]  decay,      
    input  wire [7:0]  sustain,    
    input  wire [7:0]  rel,        
    output reg  [7:0]  amplitude   
);

    typedef enum logic [2:0] {
        STATE_IDLE    = 3'b000,
        STATE_ATTACK  = 3'b001,
        STATE_DECAY   = 3'b010,
        STATE_SUSTAIN = 3'b011,
        STATE_RELEASE = 3'b100
    } adsr_state_t;

    adsr_state_t state;
    reg [15:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            amplitude <= 8'd0;
            counter   <= 16'd0;
            state     <= STATE_IDLE;
        end else if (ena) begin
            case (state)
                STATE_IDLE: begin
                    amplitude <= 8'd0;
                    if (attack != 0) begin  // Solo entra en ATTACK si attack > 0
                        state <= STATE_ATTACK;
                    end
                end
                
                STATE_ATTACK: begin
                    if (amplitude < 8'd255) begin
                        counter <= counter + 1;
                      if (counter >= {8'b0, attack}) begin  // Incrementa amplitud cada "attack" ciclos
                            amplitude <= amplitude + 1;
                            counter <= 0;
                        end
                    end else begin
                        state <= STATE_DECAY;
                        counter <= 0;
                    end
                end
                 
                STATE_DECAY: begin
                    if (amplitude > sustain) begin
                        counter <= counter + 1;
                        if (counter >= {8'b0, decay}) begin   // Decrementa amplitud cada "decay" ciclos
                            amplitude <= amplitude - 1;
                            counter <= 0;
                        end
                    end else begin
                        state <= STATE_SUSTAIN;
                    end
                end
                
                STATE_SUSTAIN: begin
                    amplitude <= sustain;  // Mantiene nivel de sustain
                    if (rel != 0) begin    // Transición a RELEASE solo si rel > 0
                        state <= STATE_RELEASE;
                        counter <= 0;
                    end
                end
                
                STATE_RELEASE: begin
                    if (amplitude > 0) begin
                        counter <= counter + 1;
                        if (counter >= {8'b0, rel}) begin // Decrementa amplitud cada "rel" ciclos
                            amplitude <= amplitude - 1;
                            counter <= 0;
                        end
                    end else begin
                        state <= STATE_IDLE;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule



module square_wave_generator (
    input  wire       ena,         // Enable signal
    input  wire       clk,         // Clock signal
    input  wire       rst_n,       // Active-low reset signal
    // verilator lint_off UNUSED
    input  wire [7:0] phase, 
    // verilator lint_on UNUSED
    output reg  [7:0] wave_out     // 8-bit output wave
);  

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wave_out <= 8'd0;  // Reset output on reset
        else if (ena)
            wave_out <= phase[7] ? 8'd255 : 8'd0;  // Use the most significant bit of phase
    end
endmodule



module encoder #(
    parameter integer WIDTH = 8,
    parameter integer INCREMENT = 1,
    parameter integer MAX_VALUE = (1 << WIDTH)-1,
    parameter integer MIN_VALUE = 0
)(
    input wire ena,
    input wire clk,
    input wire rst_n,
    input wire a,
    input wire b,
    output reg [WIDTH-1:0] value
);

    reg old_a, old_b;
    wire [3:0] transition = {old_a, a, old_b, b}; // Fixed order

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            old_a <= 1'b0;
            old_b <= 1'b0;
            value <= MIN_VALUE[WIDTH-1:0]; // Bit-slice instead of cast
        end else if (ena) begin
            old_a <= a;
            old_b <= b;

            case (transition)
                // Clockwise (A leads B)
                4'b0001, 4'b0111, 4'b1110, 4'b1000: 
                    if (value < MAX_VALUE[WIDTH-1:0])
                        value <= value + INCREMENT[WIDTH-1:0];

                // Counter-clockwise (B leads A)
                4'b0010, 4'b1011, 4'b1101, 4'b0100: 
                    if (value > MIN_VALUE[WIDTH-1:0])
                        value <= value - INCREMENT[WIDTH-1:0];

                default: value <= value;
            endcase
        end
    end
endmodule