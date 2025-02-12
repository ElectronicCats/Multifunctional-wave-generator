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
  
  
    wire unused_ui_in;
    assign unused_ui_in = |ui_in[7:1];  // OR-reduction of unused bits


    // ADSR Control
    wire [7:0] attack, decay, sustain, rel;
    wire [7:0] adsr_amplitude;

    // Frequency Divider
    reg [31:0] freq_divider;
    reg [31:0] clk_div;//////////
    reg wave_clk;
  
    //reg [5:0] freq_select_reg;

    // Frequency selection logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_divider <= 32'd284091;  // Default to A4 frequency
        end else begin
            case (freq_select)  // FIXED: Using freq_select directly to avoid delay issues
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

    // Clock Divider to generate wave_clk
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div  <= 0;
            wave_clk <= 0;
        end else if (ena) begin
            if (clk_div >= freq_divider) begin
                clk_div  <= 0;
                wave_clk <= ~wave_clk;  // Toggle waveform clock
            end else begin
                clk_div <= clk_div + 1;
            end
        end
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
    encoder #(.WIDTH(8), .INCREMENT(1)) attack_encoder (.clk(clk), .rst_n(rst_n), .a(uio_in[0]), .b(uio_in[1]), .value(attack), .ena(ena));
    encoder #(.WIDTH(8), .INCREMENT(1)) decay_encoder  (.clk(clk), .rst_n(rst_n), .a(uio_in[2]), .b(uio_in[3]), .value(decay), .ena(ena));
    encoder #(.WIDTH(8), .INCREMENT(1)) sustain_encoder(.clk(clk), .rst_n(rst_n), .a(uio_in[4]), .b(uio_in[5]), .value(sustain), .ena(ena));
    encoder #(.WIDTH(8), .INCREMENT(1)) release_encoder(.clk(clk), .rst_n(rst_n), .a(uio_in[6]), .b(uio_in[7]), .value(rel), .ena(ena));

        // Wave generators with frequency control
    wire [7:0] tri_wave_out, saw_wave_out, sqr_wave_out, sine_wave_out;
    wire [7:0] noise_out;
  
    triangular_wave_generator triangle_gen (.clk(wave_clk), .rst_n(rst_n), .freq_select(freq_divider), .wave_out(tri_wave_out), .ena(ena));
    sawtooth_wave_generator  saw_gen      (.clk(wave_clk), .rst_n(rst_n), .freq_select(freq_divider), .wave_out(saw_wave_out), .ena(ena));
    square_wave_generator   sqr_gen      (.clk(wave_clk), .rst_n(rst_n), .freq_select(freq_divider), .wave_out(sqr_wave_out), .ena(ena));
    sine_wave_generator     sine_gen     (.clk(wave_clk), .rst_n(rst_n), .freq_select(freq_divider), .wave_out(sine_wave_out), .ena(ena));
    white_noise_generator   noise_gen    (.clk(wave_clk), .rst_n(rst_n), .noise_out(noise_out), .ena(white_noise_en & ena));
    
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
    reg [7:0] temp_wave;  // Reduced from [15:0] to avoid unused bits
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            temp_wave <= 8'd0;
        else
            temp_wave <= (selected_wave * adsr_amplitude) >> 8;
    end

    // I2S Output
    wire i2s_sck, i2s_ws, i2s_sd;
    i2s_transmitter i2s_out (
      .clk(clk), .rst_n(rst_n),.data(temp_wave), .sck(i2s_sck), .ws(i2s_ws),.sd(i2s_sd),.ena(ena)
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

    reg [7:0] received_byte;   // Received byte buffer
    reg [2:0] bit_count;       // Bit count (0-7 for 8 bits)
    reg receiving;             // UART receiving flag
    reg [1:0] state;           // State machine: 0 = idle, 1 = receiving, 2 = processing

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
        end else begin
            case (state)
                IDLE: begin
                    if (start_bit) begin
                        receiving <= 1'b1;
                        bit_count <= 0;
                        state <= RECEIVING;
                    end
                end

                RECEIVING: begin
                    if (receiving) begin
                        received_byte[bit_count] <= rx_stable;
                        if (bit_count < 3'd7) begin
                            bit_count <= bit_count + 1;
                        end else begin
                            receiving <= 1'b0;
                            state <= PROCESSING;
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
                                // '0' to '9' -> Convert to 6-bit value (0-9)
                                freq_select <= (received_byte[5:0] - 6'd48);  
                            end else if (received_byte >= 8'h41 && received_byte <= 8'h5A) begin
                                // 'A' to 'Z' -> Convert to 6-bit value (10-35)
                                freq_select <= (received_byte[5:0] - 6'd55);  
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
    input wire clk,            // System clock
    input wire rst_n,          // Reset, active low
    input wire ena,            // Enable signal
    input wire [7:0] data,     // 8-bit audio data
    output reg sck,                       // Bit clock
    output reg ws,             // Word select
    output reg sd              // Serial data output
);

    reg [3:0] bit_counter;
    reg [15:0] audio_data;

    // I2S transmission logic
  always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= 4'd0;
            audio_data  <= 16'd0;
            sck         <= 0;
            ws          <= 0;
            sd          <= 0;
        end else if (ena) begin
            // Bit clock generation
            sck <= ~sck;
            if (sck) begin
                bit_counter <= bit_counter + 1;
                if (bit_counter == 15) begin
                    bit_counter <= 0;
                    ws <= ~ws;  // Toggle Word Select for I2S framing
                    // Load next audio sample
                    audio_data <= {data, data};  // Replicate 8-bit data for 16-bit transmission
                end
                // Transmit audio data bit by bit
                sd <= audio_data[15 - bit_counter];
            end
        end
    end
endmodule



module sine_wave_generator (
    input  wire       ena,        // Enable signal
    input  wire       clk,        // Clock
    input  wire       rst_n,      // Active-low reset
    input  wire [31:0] freq_select, // Frequency selection (32 bits)
    output reg  [7:0] wave_out    // 8-bit sine wave output
);

    reg [7:0] counter;      // Counter for the sine table index
    reg [31:0] clk_div;     // Clock divider (32-bit)
    reg [7:0] sine_table [0:255]; // Lookup table for sine wave

    // Cargar tabla desde archivo externo en lugar de `initial begin`
    initial $readmemh("sine_table.mem", sine_table);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter  <= 8'd0;
            clk_div  <= 32'd0;
            wave_out <= 8'd0;
        end else if (ena) begin
            if (clk_div >= freq_select - 1) begin
                clk_div <= 32'd0;
                counter <= counter + 1;  
                wave_out <= sine_table[counter]; // Leer la ROM
            end else begin
                clk_div <= clk_div + 1;
            end
        end
    end
endmodule




module square_wave_generator (
    input  wire       ena,       // Enable signal
    input  wire       clk,       // Clock
    input  wire       rst_n,     // Active-low reset
    input  wire [31:0] freq_select, // Frequency selection (now 32 bits)
    output reg  [7:0] wave_out   // 8-bit square wave output
);

    reg wave_state;
    reg [31:0] clk_div; // Now 32 bits

  always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 32'd0;
            wave_state <= 1'b0;
            wave_out <= 8'd0;
        end else if (ena) begin
            clk_div <= clk_div + 1;
            if (clk_div >= freq_select - 1) begin  // Use the full 32-bit range
                clk_div <= 32'd0;
                wave_state <= ~wave_state;
                wave_out <= wave_state ? 8'd255 : 8'd0; // Toggle between 0 and 255
            end
        end
    end
endmodule


module sawtooth_wave_generator (
    input  wire       ena,        // Enable signal
    input  wire       clk,        // Clock
    input  wire       rst_n,      // Active-low reset
    input  wire [31:0] freq_select, // Frequency selection (32 bits)
    output reg  [7:0] wave_out    // 8-bit sawtooth wave output
);

    reg [7:0] counter;
    reg [31:0] clk_div; // 32-bit clock divider

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter  <= 8'd0;
            clk_div  <= 32'd0;
            wave_out <= 8'd0; // Initialize the output with the reset
        end else if (ena) begin
            clk_div <= clk_div + 1;
            if (clk_div >= freq_select - 1) begin // Uses all the 32-bits range
                clk_div <= 32'd0;
                counter <= counter + 1; // Increments the counter
            end
            wave_out <= counter; //Asign the output
        end
    end
endmodule





module adsr_generator (
    input  wire       ena,      // Enable signal
    input  wire       clk,       // Clock
    input  wire       rst_n,     // Active-low reset
    input  wire [7:0] attack,    // Attack value
    input  wire [7:0] decay,     // Decay value
    input  wire [7:0] sustain,   // Sustain value
    input  wire [7:0] rel,       // Release value
    output reg  [7:0] amplitude  // Generated amplitude signal
);

    reg [3:0] state;
    reg [7:0] counter;

    localparam STATE_IDLE     = 4'd0;
    localparam STATE_ATTACK   = 4'd1;
    localparam STATE_DECAY    = 4'd2;
    localparam STATE_SUSTAIN  = 4'd3;
    localparam STATE_RELEASE  = 4'd4;

  always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            amplitude <= 8'd0;
            counter <= 8'd0;
        end else if (ena) begin
            case (state)
                STATE_IDLE: begin
                    if (counter == 8'd255) begin
                        state <= STATE_ATTACK;
                        counter <= 8'd0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                STATE_ATTACK: begin
                    if (amplitude < attack) begin
                        amplitude <= amplitude + 1;
                    end else begin
                        state <= STATE_DECAY;
                    end
                end
                STATE_DECAY: begin
                    // Use the decay parameter to adjust the rate of decrease
                    if (amplitude > sustain) begin
                        amplitude <= amplitude - decay;
                    end else begin
                        state <= STATE_SUSTAIN;
                    end
                end
                STATE_SUSTAIN: begin
                    amplitude <= sustain;
                    if (counter == 8'd255) begin
                        state <= STATE_RELEASE;
                        counter <= 8'd0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                STATE_RELEASE: begin
    		      if (amplitude > 0) begin
        		amplitude <= amplitude - rel;
    			end else begin
        		state <= STATE_IDLE;
    		      end
		   end

                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule

module triangular_wave_generator (
    input  wire       ena,       // Enable signal
    input  wire       clk,       // Clock
    input  wire       rst_n,     // Active-low reset
    input  wire [31:0] freq_select, // Frequency selection (now 32 bits)
    output reg [7:0]  wave_out   // 8-bit triangular wave output
);

    reg [7:0] counter;
    reg       direction;
    reg [31:0] clk_div; // Now 32 bits

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter   <= 8'd0;
            direction <= 1'b1;
            clk_div   <= 32'd0;
            wave_out  <= 8'd0;  // Initialize wave_out here
        end else if (ena) begin
            clk_div <= clk_div + 1;
            if (clk_div >= freq_select - 1) begin  // Use the full 32-bit range
                clk_div <= 32'd0;

                // Update the counter based on the direction
                if (direction) begin
                    if (counter < 8'd255) 
                        counter <= counter + 1;
                    else 
                        direction <= 1'b0; // Switch direction to down
                end else begin
                    if (counter > 8'd0) 
                        counter <= counter - 1;
                    else 
                        direction <= 1'b1; // Switch direction to up
                end
            end

            // Update wave_out to follow the counter
            wave_out <= counter;
        end
    end

endmodule



module encoder #(
    parameter WIDTH = 8,
    parameter INCREMENT = 1'b1
)(
    input ena,
    input clk,
    input rst_n,
    input a,
    input b,
    output reg [WIDTH-1:0] value
);

    reg old_a, old_b;

  always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            old_a <= 0;
            old_b <= 0;
            value <= 0;
        end else if (ena) begin
            old_a <= a;
            old_b <= b;
            case ({a, old_a, b, old_b})
                4'b1000, 4'b0111: value <= value + INCREMENT;
                4'b0010, 4'b1101: value <= value - INCREMENT;
                default: value <= value;
            endcase
        end
    end
endmodule