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
    wire       white_noise_en;
  wire [6:0] unused_temp_wave = temp_wave[6:0];
  
    wire unused_ui_in;
    assign unused_ui_in = |ui_in[7:1];  // OR-reduction of unused bits


    // ADSR Control
    wire [7:0] attack, decay, sustain, rel;
    wire [7:0] adsr_amplitude;

    // Frequency Divider
    reg [31:0] freq_divider;
    reg [31:0] clk_div;//////////
    reg wave_clk;
  

    // Frequency selection logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_divider <= 32'd284091;  // Default to A4 frequency
        end else begin
            case (freq_select)  
        6'b000000: freq_divider <= 32'd1915712;  // C2 (65.41 Hz)
       	6'b000001: freq_divider <= 32'd1803586;  // C#2/Db2 (69.30 Hz)
        6'b000010: freq_divider <= 32'd1702624;  // D2 (73.42 Hz)
        6'b000011: freq_divider <= 32'd1607142;  // D#2/Eb2 (77.78 Hz)
        6'b000100: freq_divider <= 32'd1515152;  // E2 (82.41 Hz)
        6'b000101: freq_divider <= 32'd1431731;  // F2 (87.31 Hz)
        6'b000110: freq_divider <= 32'd1351351;  // F#2/Gb2 (92.50 Hz)
        6'b000111: freq_divider <= 32'd1275510;  // G2 (98.00 Hz)
        6'b001000: freq_divider <= 32'd1204819;  // G#2/Ab2 (103.83 Hz)
        6'b001001: freq_divider <= 32'd1136364;  // A2 (110.00 Hz)
        6'b001010: freq_divider <= 32'd1075268;  // A#2/Bb2 (116.54 Hz)
        6'b001011: freq_divider <= 32'd1017340;  // B2 (123.47 Hz)

        // Octave 3
        6'b001100: freq_divider <= 32'd95786;    // C3 (130.81 Hz)
        6'b001101: freq_divider <= 32'd90180;    // C#3/Db3 (138.59 Hz)
        6'b001110: freq_divider <= 32'd85131;    // D3 (146.83 Hz)
        6'b001111: freq_divider <= 32'd80357;    // D#3/Eb3 (155.56 Hz)
        6'b010000: freq_divider <= 32'd75758;    // E3 (164.81 Hz)
        6'b010001: freq_divider <= 32'd71586;    // F3 (174.61 Hz)
        6'b010010: freq_divider <= 32'd67567;    // F#3/Gb3 (185.00 Hz)
        6'b010011: freq_divider <= 32'd63775;    // G3 (196.00 Hz)
        6'b010100: freq_divider <= 32'd60241;    // G#3/Ab3 (207.65 Hz)
        6'b010101: freq_divider <= 32'd56818;    // A3 (220.00 Hz)
        6'b010110: freq_divider <= 32'd53763;    // A#3/Bb3 (233.08 Hz)
        6'b010111: freq_divider <= 32'd50867;    // B3 (246.94 Hz)

        // Octave 4
        6'b011000: freq_divider <= 32'd47878;    // C4 (261.63 Hz)
        6'b011001: freq_divider <= 32'd45090;    // C#4/Db4 (277.18 Hz)
        6'b011010: freq_divider <= 32'd42566;    // D4 (293.66 Hz)
        6'b011011: freq_divider <= 32'd40178;    // D#4/Eb4 (311.13 Hz)
        6'b011100: freq_divider <= 32'd37878;    // E4 (329.63 Hz)
        6'b011101: freq_divider <= 32'd35793;    // F4 (349.23 Hz)
        6'b011110: freq_divider <= 32'd33783;    // F#4/Gb4 (369.99 Hz)
        6'b011111: freq_divider <= 32'd31888;    // G4 (392.00 Hz)
        6'b100000: freq_divider <= 32'd30120;    // G#4/Ab4 (415.30 Hz)
        6'b100001: freq_divider <= 32'd28409;    // A4 (440.00 Hz)
        6'b100010: freq_divider <= 32'd26881;    // A#4/Bb4 (466.16 Hz)
        6'b100011: freq_divider <= 32'd25434;    // B4 (493.88 Hz)

        // Octave 5
        6'b100100: freq_divider <= 32'd23939;    // C5 (523.25 Hz)
        6'b100101: freq_divider <= 32'd22545;    // C#5/Db5 (554.37 Hz)
        6'b100110: freq_divider <= 32'd21283;    // D5 (587.33 Hz)
        6'b100111: freq_divider <= 32'd20089;    // D#5/Eb5 (622.25 Hz)
        6'b101000: freq_divider <= 32'd18938;    // E5 (659.25 Hz)
        6'b101001: freq_divider <= 32'd17896;    // F5 (698.46 Hz)
        6'b101010: freq_divider <= 32'd16891;    // F#5/Gb5 (739.99 Hz)
        6'b101011: freq_divider <= 32'd15944;    // G5 (783.99 Hz)
        6'b101100: freq_divider <= 32'd15060;    // G#5/Ab5 (830.61 Hz)
        6'b101101: freq_divider <= 32'd14204;    // A5 (880.00 Hz)
        6'b101110: freq_divider <= 32'd13441;    // A#5/Bb5 (932.33 Hz)
        6'b101111: freq_divider <= 32'd12717;    // B5 (987.77 Hz)

        // Octave 6
        6'b110000: freq_divider <= 32'd11969;    // C6 (1046.50 Hz)
        6'b110001: freq_divider <= 32'd11272;    // C#6/Db6 (1108.73 Hz)
        6'b110010: freq_divider <= 32'd10642;    // D6 (1174.66 Hz)
        6'b110011: freq_divider <= 32'd10044;    // D#6/Eb6 (1244.51 Hz)
        6'b110100: freq_divider <= 32'd9470;     // E6 (1318.51 Hz)
        6'b110101: freq_divider <= 32'd8948;     // F6 (1396.91 Hz)
        6'b110110: freq_divider <= 32'd8445;     // F#6/Gb6 (1479.98 Hz)
        6'b110111: freq_divider <= 32'd7972;     // G6 (1567.98 Hz)
        6'b111000: freq_divider <= 32'd7518;     // G#6/Ab6 (1661.22 Hz)
        6'b111001: freq_divider <= 32'd7090;     // A6 (1760.00 Hz)
        6'b111010: freq_divider <= 32'd6719;     // A#6/Bb6 (1864.66 Hz)
        6'b111011: freq_divider <= 32'd6358;     // B6 (1975.53 Hz)
                default:   freq_divider <= 32'd284091;   // Default frequency
            endcase
        end
    end

    /*always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div  <= 0;
            wave_clk <= 0;
        end else if (clk_div >= freq_divider) begin
            clk_div  <= 0;
            wave_clk <= ~wave_clk;  // Toggle `wave_clk` every `freq_divider` cycles
        end else begin
            clk_div <= clk_div + 1;
        end
    end*/


    // Phase accumulator for all waveforms
    reg [7:0] phase_accum;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase_accum <= 8'd0;
        else if (ena)
            phase_accum <= phase_accum + freq_select[7:0]; // Increment based on frequency
    end

    // UART Receiver
    uart_receiver uart_rx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rx(ui_in[0]),
        .freq_select(freq_select),
        .wave_select(wave_select),
        .white_noise_en(white_noise_en)
    );

    // Encoders for ADSR
    encoder #(.WIDTH(8), .INCREMENT(1), .MAX_VALUE(255), .MIN_VALUE(0)) attack_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[0]), .b(uio_in[1]), .value(attack), .ena(ena));
    encoder #(.WIDTH(8), .INCREMENT(1), .MAX_VALUE(255), .MIN_VALUE(0)) decay_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[2]), .b(uio_in[3]), .value(decay), .ena(ena));
    encoder #(.WIDTH(8), .INCREMENT(1), .MAX_VALUE(255), .MIN_VALUE(0)) sustain_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[4]), .b(uio_in[5]), .value(sustain), .ena(ena));
    encoder #(.WIDTH(8), .INCREMENT(1), .MAX_VALUE(255), .MIN_VALUE(0)) release_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[6]), .b(uio_in[7]), .value(rel), .ena(ena));


        // Wave generators 
    wire [7:0] tri_wave_out, saw_wave_out, sqr_wave_out, sine_wave_out;
    wire [7:0] noise_out;

    // Square Wave Generator
    square_wave_generator sqr_gen        (.clk(clk),.rst_n(rst_n),.ena(ena),.phase(phase_accum), .wave_out(sqr_wave_out));
    triangular_wave_generator tri_gen   (.clk(clk), .rst_n(rst_n),.ena(ena), .phase(phase_accum), .wave_out(tri_wave_out));
    sawtooth_wave_generator saw_gen     (.clk(clk),.rst_n(rst_n),.ena(ena),.phase(phase_accum), .wave_out(saw_wave_out));
    white_noise_generator   noise_gen    (.clk(wave_clk), .rst_n(rst_n), .noise_out(noise_out), .ena(white_noise_en & ena));
    cordic_sine_generator sine_gen       (.clk(clk),.rst_n(rst_n),.ena(ena),.phase(phase_accum), .sine_out(sine_wave_out));


    // Select waveform output
    reg [7:0] selected_wave;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            selected_wave <= 8'd0;
        else begin
            case (wave_select)
                3'b000: selected_wave <= tri_wave_out;
                3'b001: selected_wave <= saw_wave_out;
                3'b010: selected_wave <= sqr_wave_out;
                3'b011: selected_wave <= sine_wave_out;
                3'b100: selected_wave <= noise_out;
                default: selected_wave <= 8'd0;
            endcase
        end
    end
  
    // ADSR Generator
    adsr_generator adsr_gen (
        .clk(clk), .rst_n(rst_n),
        .attack(attack), .decay(decay),
        .sustain(sustain), .rel(rel),
        .amplitude(adsr_amplitude), .ena(ena)
    );

// Apply ADSR Envelope
reg [15:0] temp_wave;  // Ensure full precision calculation
reg [7:0] scaled_wave; // Final 8-bit output

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_wave <= 16'd0;
        scaled_wave <= 8'd0;
    end else begin
        temp_wave <= selected_wave * adsr_amplitude; // Full precision
        scaled_wave <= temp_wave[15:8] + (temp_wave[7] ? 8'd1 : 8'd0);
    end
end

    // I2S Output
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

    // Assign I2S Outputs to `uo_out`
    assign uo_out[0] = i2s_sck;
    assign uo_out[1] = i2s_ws;
    assign uo_out[2] = i2s_sd;
    assign uo_out[7:3] = 5'b00000;  // Ensure upper bits are not floating
    assign uio_out = 8'b0;     
    assign uio_oe = 8'b0;      
endmodule

module uart_receiver (
    input wire clk,               // System clock
    input wire rst_n,             // Active-low reset
    input wire rx,                // UART RX signal
    output reg [5:0] freq_select, // Frequency selection
    output reg [2:0] wave_select, // Wave type selection
    output reg white_noise_en     // White noise enable
);

    // Parameters
    parameter BAUD_TICKS = 2604;  // Baud rate clock ticks 
    
    wire [1:0] unused_temp_bits = temp_byte[7:6];
  
    // Registers and wires
    reg [31:0] baud_counter;      // Counter for baud rate clock (32 bits to match BAUD_TICKS)
    reg [7:0] received_byte;      // Received byte buffer
    reg [2:0] bit_count;          // Bit count (0-7 for 8 bits)
    reg receiving;                // UART receiving flag
    reg [1:0] state;              // State machine: 0 = idle, 1 = receiving, 2 = processing

    reg [7:0] temp_byte; // Ensure enough bits for calculation
    //wire unused_temp_bits = temp_byte[7:6]; // Prevent lint warning


    // State machine states
    localparam IDLE       = 2'b00;
    localparam RECEIVING  = 2'b01;
    localparam PROCESSING = 2'b10;

    // Synchronize the RX signal to avoid metastability
    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    wire rx_stable = rx_sync2;

    // Start bit detection (falling edge on rx_stable)
    reg rx_last;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_last <= 1'b1;
        else
            rx_last <= rx_stable;
    end
    wire start_bit = (rx_last == 1'b1 && rx_stable == 1'b0); // Falling edge detection

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            received_byte <= 8'd0;
            bit_count <= 3'd0;
            receiving <= 1'b0;
            freq_select <= 6'd0;
            wave_select <= 3'b000;  // Default: Triangle wave
            white_noise_en <= 1'b0; // Disable white noise
            state <= IDLE;
            baud_counter <= 0;     // Reset baud counter
        end else begin
            case (state)
                IDLE: begin
                    if (start_bit) begin
                        receiving <= 1'b1;
                        bit_count <= 0;
                        baud_counter <= 0; // Reset baud counter
                        state <= RECEIVING;
                    end
                end

                RECEIVING: begin
                    if (receiving) begin
                        if (baud_counter == BAUD_TICKS - 1) begin
                            baud_counter <= 0; // Reset baud counter for the next bit
                            received_byte[bit_count] <= rx_stable; // Store current bit
                            if (bit_count < 3'd7) begin
                                bit_count <= bit_count + 1;
                            end else begin
                                receiving <= 1'b0; // All bits received
                                state <= PROCESSING; // Go to processing state
                            end
                        end else begin
                            baud_counter <= baud_counter + 1; // Increment baud counter
                        end
                    end
                end

                PROCESSING: begin
                    case (received_byte)
                        // White noise control
                        8'h4E: white_noise_en <= 1'b1;        // 'N' - Enable white noise
                        8'h46: white_noise_en <= 1'b0;        // 'F' - Disable white noise

                        // Wave selection
                        8'h54: wave_select <= 3'b000;         // 'T' - Triangle wave
                        8'h53: wave_select <= 3'b001;         // 'S' - Sawtooth wave
                        8'h51: wave_select <= 3'b010;         // 'Q' - Square wave
                        8'h57: wave_select <= 3'b011;         // 'W' - Sine wave

                        // Frequency selection (numbers '0'-'9' and letters 'A'-'Z')
                        default: begin
                            if (received_byte >= 8'h30 && received_byte <= 8'h39) begin
                                temp_byte <= received_byte - 8'h30; // Convert '0'-'9' to value
                                freq_select <= temp_byte[5:0];     // Use lower 6 bits
                            end else if (received_byte >= 8'h41 && received_byte <= 8'h5A) begin
                                temp_byte <= received_byte - 8'h41 + 8'd10; // Convert 'A'-'Z' to value
                                freq_select <= temp_byte[5:0];            // Use lower 6 bits
                            end
                        end
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
            lfsr <= 16'hACE1; // Seed value
            noise_out <= 8'd0;
        end else if (ena) begin
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]}; // Feedback taps
            noise_out <= lfsr[15:8]; // Use upper 8 bits as noise
        end
    end
endmodule



module i2s_transmitter (
    input wire clk,        // System clock
    input wire rst_n,      // Reset (active low)
    input wire ena,        // Enable signal
    input wire [7:0] data, // 8-bit audio data
    output reg sck,        // Serial clock (bit clock)
    output reg ws,         // Word select (left/right channel)
    output reg sd          // Serial data output
);

    reg [3:0] bit_counter;  // Counts bits being sent
    reg [15:0] shift_reg;   // Shift register for transmitting data
    reg [7:0] clk_div;      // Clock divider for generating `sck`

    parameter SCK_DIV = 16; // Adjust this based on your clock frequency

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div    <= 0;
            sck        <= 0;
            ws         <= 0;
            sd         <= 0;
            bit_counter <= 0;
            shift_reg  <= 16'd0;
        end else if (ena) begin
            // Generate I2S Serial Clock (sck) at the correct frequency
            if (clk_div == (SCK_DIV - 1)) begin
                clk_div <= 0;
                sck <= ~sck;  // Toggle sck
            end else begin
                clk_div <= clk_div + 1;
            end

            // Data Transmission Logic (Shift Register)
            if (sck == 0) begin  // Shift data on the falling edge of sck
                if (bit_counter == 0) begin
                    ws <= ~ws;  // Toggle word select every 16 bits
                    shift_reg <= {data, data};  // Duplicate 8-bit data for 16-bit format
                end else begin
                    shift_reg <= shift_reg << 1;  // Shift left to send MSB first
                end

                sd <= shift_reg[15];  // Output MSB first
                bit_counter <= (bit_counter == 15) ? 0 : bit_counter + 1;
            end
        end
    end
endmodule



module cordic_sine_generator (
    input wire clk,          // System clock
    input wire rst_n,        // Active-low reset
    input wire ena,          // Enable signal
    input wire [7:0] phase,  // Input phase (0-255 mapped to 0-2π)
    output reg [7:0] sine_out // Output sine wave (8-bit)
);

    // CORDIC Parameters
    parameter ITERATIONS = 10;
    parameter SCALE_FACTOR = 16'h26DD;  // 0.60725 in Q1.15 format

    // Lookup table for atan(2^-i) in Q1.15 format
    reg signed [15:0] atan_table [0:ITERATIONS-1];
    initial begin
        atan_table[0]  = 16'h3244; // atan(2^0)
        atan_table[1]  = 16'h1DAC; // atan(2^-1)
        atan_table[2]  = 16'h0FAD; // atan(2^-2)
        atan_table[3]  = 16'h07F5; // atan(2^-3)
        atan_table[4]  = 16'h03FE; // atan(2^-4)
        atan_table[5]  = 16'h01FF; // atan(2^-5)
        atan_table[6]  = 16'h00FF; // atan(2^-6)
        atan_table[7]  = 16'h007F; // atan(2^-7)
        atan_table[8]  = 16'h003F; // atan(2^-8)
        atan_table[9]  = 16'h001F; // atan(2^-9)
    end

    // Registers for CORDIC iterations
    reg signed [15:0] x, y, z;
    reg signed [15:0] x_next, y_next, z_next;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_out <= 8'd128; // Default mid-point
        end else if (ena) begin
            // Initial vector (1,0) scaled by K (0.60725 in Q1.15)
            x = SCALE_FACTOR;
            y = 0;
            z = {phase, 8'b0}; // Scale phase to Q1.15

            // CORDIC Iterations
            for (i = 0; i < ITERATIONS; i = i + 1) begin
                if (z < 0) begin
                    x_next = x + (y >>> i);
                    y_next = y - (x >>> i);
                    z_next = z + atan_table[i];
                end else begin
                    x_next = x - (y >>> i);
                    y_next = y + (x >>> i);
                    z_next = z - atan_table[i];
                end
                x = x_next;
                y = y_next;
                z = z_next;
            end

            // Convert output from Q1.15 format to 8-bit
            sine_out <= y[15:8] + 8'd128; // Shift and bias for unsigned output
        end
    end
endmodule



module square_wave_generator (
    input  wire       ena,        
    input  wire       clk,        
    input  wire       rst_n,      
    input  wire [7:0] phase,  // Use phase_accum instead of wave_clk
    output reg  [7:0] wave_out    
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wave_out <= 8'd0;
        else if (ena)
            wave_out <= phase[7] ? 8'd255 : 8'd0; // High for first half, low for second half
    end
endmodule




module sawtooth_wave_generator (
    input  wire       ena,        
    input  wire       clk,        
    input  wire       rst_n,      
    input  wire [7:0] phase,  // Use phase_accum instead of wave_clk
    output reg  [7:0] wave_out    
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wave_out <= 8'd0;
        else if (ena)
            wave_out <= phase; // Directly use phase as sawtooth wave
    end
endmodule



module adsr_generator (
    input  wire       ena,       // Enable signal
    input  wire       clk,       // Clock
    input  wire       rst_n,     // Active-low reset
    input  wire [7:0] attack,    // Attack value
    input  wire [7:0] decay,     // Decay value
    input  wire [7:0] sustain,   // Sustain value
    input  wire [7:0] rel,       // Release value
    output reg  [7:0] amplitude  // Generated amplitude signal
);

    (* fsm_encoding = "binary" *) reg [3:0] state;
    reg [7:0] counter;

    localparam STATE_IDLE    = 4'b0000;
    localparam STATE_ATTACK  = 4'b0001;
    localparam STATE_DECAY   = 4'b0010;
    localparam STATE_SUSTAIN = 4'b0011;
    localparam STATE_RELEASE = 4'b0100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            amplitude <= 8'd0;
            counter   <= 8'd0;
        end else if (ena) begin
            case (state)
                STATE_IDLE: begin
                    if (counter == 8'd255) begin
                        state   <= STATE_ATTACK;
                        counter <= 8'd0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                STATE_ATTACK: begin
                    if (amplitude < 8'd255) begin
                        amplitude <= amplitude + (attack >> 4); // Incremento proporcional al ataque
                    end else begin
                        amplitude <= 8'd255; // Límite superior
                        state <= STATE_DECAY;
                    end
                end
                STATE_DECAY: begin
                    if (amplitude > sustain) begin
                        amplitude <= amplitude - ((amplitude - sustain) >> decay[3:0]); // Decremento suave hacia el nivel de sostenido
                    end else begin
                        amplitude <= sustain;
                        state <= STATE_SUSTAIN;
                    end
                end
                STATE_SUSTAIN: begin
                    amplitude <= sustain; // Mantén el nivel de sostenido
                    if (counter == 8'd255) begin
                        state   <= STATE_RELEASE;
                        counter <= 8'd0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                STATE_RELEASE: begin
                    if (amplitude > 8'd0) begin
                        // Decremento hacia 0
                        amplitude <= amplitude - (amplitude >> rel[3:0]);
                    end else begin
                        amplitude <= 8'd0; // Asegurar que no sea negativo
                        state <= STATE_IDLE;
                    end
                end
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule



module triangular_wave_generator (
    input  wire       ena,        
    input  wire       clk,        
    input  wire       rst_n,      
    input  wire [7:0] phase,  // Use phase_accum instead of wave_clk
    output reg  [7:0] wave_out    
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wave_out <= 8'd0;
        else if (ena)
            wave_out <= phase[7] ? (8'd255 - phase[6:0] << 1) : (phase[6:0] << 1);
    end
endmodule


module encoder #(
    parameter WIDTH = 8,          // Ancho del contador
    parameter INCREMENT = 1'b1,   // Valor de incremento
    parameter MAX_VALUE = (1 << WIDTH) - 1, // Valor máximo (ej. 255 para 8 bits)
    parameter MIN_VALUE = 0       // Valor mínimo (por defecto 0)
)(
    input wire ena,               // Habilitación
    input wire clk,               // Reloj
    input wire rst_n,             // Reset activo bajo
    input wire a,                 // Entrada A del encoder
    input wire b,                 // Entrada B del encoder
    output reg [WIDTH-1:0] value  // Salida del contador
);

    reg old_a, old_b;

    // Estados posibles en el codificador en cuadratura
    wire [3:0] transition;
    assign transition = {a, old_a, b, old_b}; // Combina los estados actuales y anteriores

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            old_a <= 1'b0;
            old_b <= 1'b0;
            value <= {WIDTH{1'b0}}; // Inicializa el contador en el mínimo
        end else if (ena) begin
            // Guarda los estados anteriores
            old_a <= a;
            old_b <= b;

            // Manejo de las transiciones con límites
            case (transition)
                4'b1000, 4'b0110, 4'b0011, 4'b1101: begin
                    if (value < MAX_VALUE)  // Evita superar el límite superior
                        value <= value + INCREMENT;
                end
                4'b0001, 4'b1011, 4'b1110, 4'b0100: begin
                    if (value > MIN_VALUE)  // Evita caer por debajo del límite inferior
                        value <= value - INCREMENT;
                end
                default: value <= value; // Mantén el valor para transiciones no válidas
            endcase
        end
    end
endmodule