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
  
    // Phase accumulator for all waveforms
    reg [7:0] phase_accum;

    always @(posedge clk or negedge rst_n) begin
        $display("Wave clock toggled: %b, clk_div: %d, freq_divider: %d", wave_clk, clk_div, freq_divider);
        if (!rst_n) begin
            freq_divider <= 21'd284091;  // Default to A4 frequency
        end else begin
            case (freq_select)  
            6'b000000: freq_divider <= 21'd1915712;  // C2 (65.41 Hz)
       	    6'b000001: freq_divider <= 21'd1803586;  // C#2/Db2 (69.30 Hz)
            6'b000010: freq_divider <= 21'd1702624;  // D2 (73.42 Hz)
            6'b000011: freq_divider <= 21'd1607142;  // D#2/Eb2 (77.78 Hz)
            6'b000100: freq_divider <= 21'd1515152;  // E2 (82.41 Hz)
            6'b000101: freq_divider <= 21'd1431731;  // F2 (87.31 Hz)
            6'b000110: freq_divider <= 21'd1351351;  // F#2/Gb2 (92.50 Hz)
            6'b000111: freq_divider <= 21'd1275510;  // G2 (98.00 Hz)
            6'b001000: freq_divider <= 21'd1204819;  // G#2/Ab2 (103.83 Hz)
            6'b001001: freq_divider <= 21'd1136364;  // A2 (110.00 Hz)
            6'b001010: freq_divider <= 21'd1075268;  // A#2/Bb2 (116.54 Hz)
            6'b001011: freq_divider <= 21'd1017340;  // B2 (123.47 Hz)

            // Octave 3
            6'b001100: freq_divider <= 21'd95786;    // C3 (130.81 Hz)
            6'b001101: freq_divider <= 21'd90180;    // C#3/Db3 (138.59 Hz)
            6'b001110: freq_divider <= 21'd85131;    // D3 (146.83 Hz)
            6'b001111: freq_divider <= 21'd80357;    // D#3/Eb3 (155.56 Hz)
            6'b010000: freq_divider <= 21'd75758;    // E3 (164.81 Hz)
            6'b010001: freq_divider <= 21'd71586;    // F3 (174.61 Hz)
            6'b010010: freq_divider <= 21'd67567;    // F#3/Gb3 (185.00 Hz)
            6'b010011: freq_divider <= 21'd63775;    // G3 (196.00 Hz)
            6'b010100: freq_divider <= 21'd60241;    // G#3/Ab3 (207.65 Hz)
            6'b010101: freq_divider <= 21'd56818;    // A3 (220.00 Hz)
            6'b010110: freq_divider <= 21'd53763;    // A#3/Bb3 (233.08 Hz)
            6'b010111: freq_divider <= 21'd50867;    // B3 (246.94 Hz)

            // Octave 4
            6'b011000: freq_divider <= 21'd47878;    // C4 (261.63 Hz)
            6'b011001: freq_divider <= 21'd45090;    // C#4/Db4 (277.18 Hz)
            6'b011010: freq_divider <= 21'd42566;    // D4 (293.66 Hz)
            6'b011011: freq_divider <= 21'd40178;    // D#4/Eb4 (311.13 Hz)
            6'b011100: freq_divider <= 21'd37878;    // E4 (329.63 Hz)
            6'b011101: freq_divider <= 21'd35793;    // F4 (349.23 Hz)
            6'b011110: freq_divider <= 21'd33783;    // F#4/Gb4 (369.99 Hz)
            6'b011111: freq_divider <= 21'd31888;    // G4 (392.00 Hz)
            6'b100000: freq_divider <= 21'd30120;    // G#4/Ab4 (415.30 Hz)
            6'b100001: freq_divider <= 21'd28409;    // A4 (440.00 Hz)
            6'b100010: freq_divider <= 21'd26881;    // A#4/Bb4 (466.16 Hz)
            6'b100011: freq_divider <= 21'd25434;    // B4 (493.88 Hz)

            // Octave 5
            6'b100100: freq_divider <= 21'd23939;    // C5 (523.25 Hz)
            6'b100101: freq_divider <= 21'd22545;    // C#5/Db5 (554.37 Hz)
            6'b100110: freq_divider <= 21'd21283;    // D5 (587.33 Hz)
            6'b100111: freq_divider <= 21'd20089;    // D#5/Eb5 (622.25 Hz)
            6'b101000: freq_divider <= 21'd18938;    // E5 (659.25 Hz)
            6'b101001: freq_divider <= 21'd17896;    // F5 (698.46 Hz)
            6'b101010: freq_divider <= 21'd16891;    // F#5/Gb5 (739.99 Hz)
            6'b101011: freq_divider <= 21'd15944;    // G5 (783.99 Hz)
            6'b101100: freq_divider <= 21'd15060;    // G#5/Ab5 (830.61 Hz)
            6'b101101: freq_divider <= 21'd14204;    // A5 (880.00 Hz)
            6'b101110: freq_divider <= 21'd13441;    // A#5/Bb5 (932.33 Hz)
            6'b101111: freq_divider <= 21'd12717;    // B5 (987.77 Hz)

            // Octave 6
            6'b110000: freq_divider <= 21'd11969;    // C6 (1046.50 Hz)
            6'b110001: freq_divider <= 21'd11272;    // C#6/Db6 (1108.73 Hz)
            6'b110010: freq_divider <= 21'd10642;    // D6 (1174.66 Hz)
            6'b110011: freq_divider <= 21'd10044;    // D#6/Eb6 (1244.51 Hz)
            6'b110100: freq_divider <= 21'd9470;     // E6 (1318.51 Hz)
            6'b110101: freq_divider <= 21'd8948;     // F6 (1396.91 Hz)
            6'b110110: freq_divider <= 21'd8445;     // F#6/Gb6 (1479.98 Hz)
            6'b110111: freq_divider <= 21'd7972;     // G6 (1567.98 Hz)
            6'b111000: freq_divider <= 21'd7518;     // G#6/Ab6 (1661.22 Hz)
            6'b111001: freq_divider <= 21'd7090;     // A6 (1760.00 Hz)
            6'b111010: freq_divider <= 21'd6719;     // A#6/Bb6 (1864.66 Hz)
            6'b111011: freq_divider <= 21'd6358;     // B6 (1975.53 Hz)
           default:   freq_divider <= 21'd284091;   // Default frequency
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div  <= 0;
            wave_clk <= 0;
        end else if (clk_div >= freq_divider) begin
            clk_div  <= 0;
            wave_clk <= ~wave_clk;  // Toggle `wave_clk` every `freq_divider` cycles
        end else begin
            clk_div <= clk_div + 1;
        end
    end

    // Phase accumulator for waveforms
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase_accum <= 8'd0;
        else if (ena)
            phase_accum <= phase_accum + ({2'b00, freq_select} << 2); 
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

    // Select waveform output (Fixed default case)
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
                 default: selected_wave <= 8'd0; // Fix: Prevent dead mux input
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

    // Apply ADSR Envelope to waveform (Added saturation logic)
    reg [7:0] scaled_wave;
    always @(posedge clk or negedge rst_n) begin
        $display("Selected Waveform: %h, ADSR Amplitude: %h, Scaled Wave: %h", selected_wave, adsr_amplitude, scaled_wave);
        if (!rst_n) begin
            temp_wave   <= 16'd0;
            scaled_wave <= 8'd0;
        end else begin
            temp_wave <= (selected_wave * adsr_amplitude) >> 8;

            if (freq_select < 6'b111100) 
                scaled_wave <= temp_wave[15:8] ^ {2'b00, freq_select};
            else
                scaled_wave <= temp_wave[15:8]; 
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

    // Assign I2S Outputs
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
    input wire rx,               // UART RX Input
    output reg [5:0] freq_select, // Frequency selection (e.g., A4, B3, etc.)
    output reg [2:0] wave_select, // Waveform select (square, sine, etc.)
    output reg white_noise_en     // White Noise enable
);
    
    // Parameters
    parameter BAUD_TICKS = 2604;  // Baud rate clock ticks 
    
    // Registers and Wires
    reg [31:0] baud_counter;      // Baud rate clock counter
    reg [7:0] received_byte;      // Received byte buffer
    reg [2:0] bit_count;          // Bit counter (0-7 for 8 bits)
    reg receiving;                // UART receiving flag
    reg [1:0] state;              // State machine: 0 = idle, 1 = receiving, 2 = processing

    reg [7:0] phase_accum_reg;    // Phase accumulator register

    // Temporary variable for frequency conversion
    reg [7:0] temp_freq;  // Remains 8 bits, but ensures all bits are used

    // State machine states
    localparam IDLE       = 2'b00;
    localparam RECEIVING  = 2'b01;
    localparam PROCESSING = 2'b10;

    // Start bit detection (falling edge on rx)
    reg rx_last;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_last <= 1'b1;
        else
            rx_last <= rx;
    end
    wire start_bit = (rx_last == 1'b1 && rx == 1'b0);

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            received_byte <= 8'd0;
            bit_count <= 3'd0;
            receiving <= 1'b0;
            freq_select <= 6'd0;
            wave_select <= 3'b000;
            white_noise_en <= 1'b0;
            state <= IDLE;
            baud_counter <= 0;
            phase_accum_reg <= 8'd0;
            temp_freq <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start_bit) begin
                        receiving <= 1'b1;
                        bit_count <= 0;
                        baud_counter <= 0;
                        state <= RECEIVING;
                    end
                end

                RECEIVING: begin
                    if (receiving) begin
                        if (baud_counter == BAUD_TICKS - 1) begin
                            baud_counter <= 0;
                            received_byte[bit_count] <= rx;
                            if (bit_count < 3'd7) begin
                                bit_count <= bit_count + 1;
                            end else begin
                                receiving <= 1'b0;
                                state <= PROCESSING;
                            end
                        end else begin
                            baud_counter <= baud_counter + 1;
                        end
                    end
                end

                PROCESSING: begin
                    case (received_byte)
                        8'h4E: white_noise_en <= 1'b1;
                        8'h46: white_noise_en <= 1'b0;
                        8'h54: wave_select <= 3'b000;
                        8'h53: wave_select <= 3'b001;
                        8'h51: wave_select <= 3'b010;
                        8'h57: wave_select <= 3'b011;
                        default: begin
                            if (received_byte >= 8'h30 && received_byte <= 8'h39) begin
                                freq_select <= received_byte[5:0] - 6'h30;
                            end else if (received_byte >= 8'h41 && received_byte <= 8'h5A) begin
                                temp_freq <= (received_byte - 8'd65 + 8'd10) & 8'h3F;
                                temp_freq[7:6] <= 2'b00; // Assign 0 to unused bits
                                freq_select <= temp_freq[5:0];
                            end
                        end
                    endcase
                    phase_accum_reg <= phase_accum_reg + {2'b00, freq_select};
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
        $display("I2S Output Debug: SCK=%b, WS=%b, SD=%b", sck, ws, sd);
        if (!rst_n) begin
            clk_div    <= 0;
            sck        <= 0;
            ws         <= 0;
            sd         <= 0;
            bit_counter <= 0;
            shift_reg  <= 16'd0;
        end else if (ena) begin
            // Generación del clock I2S (sck)
            if (clk_div == (SCK_DIV - 1)) begin
                clk_div <= 0;
                sck <= ~sck;  // Toggle sck
            end else begin
                clk_div <= clk_div + 1;
            end

            // Lógica de transmisión de datos
            if (sck == 0) begin  // Se hace el shift en el flanco de bajada de `sck`
                if (bit_counter == 0) begin
                    ws <= ~ws;  // Cambia `ws` solo al inicio de un nuevo frame de 16 bits
                    shift_reg <= ws ? {data, 8'd0} : {8'd0, data}; // L/R separados
                end else begin
                    shift_reg <= shift_reg << 1;  // Shift left para enviar MSB primero
                end
                sd <= shift_reg[15];  // Se envía el MSB en `sd`
                bit_counter <= (bit_counter == 15) ? 0 : bit_counter + 1;
            end
        end else begin
            // Si `ena` es bajo, los valores se mantienen en 0
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
    input  wire [7:0] phase,
    output reg  [7:0] sine_out
);

    reg signed [15:0] x, y, z;
    reg [3:0] i; 
    reg signed [15:0] atan_value; 

    localparam signed [15:0] atan_table_0 = 16'h3243;
    localparam signed [15:0] atan_table_1 = 16'h1DAC;
    localparam signed [15:0] atan_table_2 = 16'h0FAB;
    localparam signed [15:0] atan_table_3 = 16'h07F5;
    localparam signed [15:0] atan_table_4 = 16'h03FE;
    localparam signed [15:0] atan_table_5 = 16'h01FF;
    localparam signed [15:0] atan_table_6 = 16'h00FF;
    localparam signed [15:0] atan_table_7 = 16'h007F;

    always @(*) begin
        case (i[2:0]) 
            3'b000: atan_value = atan_table_0;
            3'b001: atan_value = atan_table_1;
            3'b010: atan_value = atan_table_2;
            3'b011: atan_value = atan_table_3;
            3'b100: atan_value = atan_table_4;
            3'b101: atan_value = atan_table_5;
            3'b110: atan_value = atan_table_6;
            3'b111: atan_value = atan_table_7;
            default: atan_value = 16'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 16'h26DD;
            y <= 16'd0;
            z <= 16'd0;
            i <= 4'b0000;
        end else if (ena) begin
            if (i == 4'b0000)
                z <= {phase, 8'b0}; 

            if (i < 4'b1000) begin 
                if (z[15]) begin
                    x <= x + (y >>> i);
                    y <= y - (x >>> i);
                    z <= z - atan_value;
                end else begin
                    x <= x - (y >>> i);
                    y <= y + (x >>> i);
                    z <= z + atan_value;
                end
                i <= i + 1;
            end else begin
                sine_out <= y[15:8]; 
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
            wave_out <= 8'd0;
        else if (ena)
            wave_out <= phase[7] ? (8'd255 - {1'b0, phase[6:0]} << 1) : ({1'b0, phase[6:0]} << 1);
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
            wave_out <= 8'd0;
        else if (ena)
            wave_out <= phase; // Directly use phase as sawtooth wave
    end
endmodule



module adsr_generator (
    input  wire       ena,       
    input  wire       clk,       
    input  wire       rst_n,     
    input  wire [7:0] attack,    
    input  wire [7:0] decay,     
    input  wire [7:0] sustain,   
    input  wire [7:0] rel,       
    output reg  [7:0] amplitude  
);

    (* fsm_encoding = "one-hot" *) reg [3:0] state;
    
    reg [7:0] adsr_amplitude;
    reg [7:0] counter;

    localparam STATE_IDLE    = 4'b0000;
    localparam STATE_ATTACK  = 4'b0001;
    localparam STATE_DECAY   = 4'b0010;
    localparam STATE_SUSTAIN = 4'b0011;
    localparam STATE_RELEASE = 4'b0100;

    // Suppress unused signal warnings
   
    wire unused_decay = |decay[3:0];
    wire unused_rel   = |rel[3:0];
   

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            adsr_amplitude <= 8'd0;
            counter        <= 8'd0;
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
                    counter <= 8'd0;
                    if (adsr_amplitude < 8'd255)
                        adsr_amplitude <= adsr_amplitude + (attack >> 3); // Faster attack
                    else begin
                        adsr_amplitude <= 8'd255;
                        state <= STATE_DECAY;
                    end
                end
                STATE_DECAY: begin
                    if (adsr_amplitude > sustain) begin
                        adsr_amplitude <= adsr_amplitude - ((adsr_amplitude - sustain) >> (decay[7:4] > 0 ? decay[7:4] : 1)); // Ensure decay is not too fast
                        if (adsr_amplitude < sustain) adsr_amplitude <= sustain; 
                    end else begin
                        adsr_amplitude <= sustain;
                        state <= STATE_SUSTAIN;
                        counter <= 0; // Reset counter to use as a timer
                    end
                end
                STATE_SUSTAIN: begin
                    adsr_amplitude <= sustain;
                    if (counter == 8'd255) begin  // Using counter as a placeholder for key release
                        state   <= STATE_RELEASE;
                        counter <= 8'd0;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                STATE_RELEASE: begin
                    if (adsr_amplitude > 8'd0) begin
                        adsr_amplitude <= adsr_amplitude - (adsr_amplitude >> (rel[7:4] + 2)); // Smoother release
                        if (adsr_amplitude > 8'd0 && adsr_amplitude < (adsr_amplitude >> (rel[7:4] + 2))) 
                            adsr_amplitude <= 8'd0;
                    end else begin
                        adsr_amplitude <= 8'd0;
                        state <= STATE_IDLE;
                    end
                end
                default: state <= STATE_IDLE; // Ensuring reset to idle in unexpected cases
            endcase
        end
    end

    always @(posedge clk) begin
        amplitude <= adsr_amplitude;
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
    parameter integer WIDTH = 8,              // Counter width
    parameter integer INCREMENT = 1,          // Increment value (must be integer)
    parameter integer MAX_VALUE = (1 << WIDTH)-1, // Max value (e.g., 255 for 8-bit)
    parameter integer MIN_VALUE = 0           // Min value
)(
    input wire ena,       
    input wire clk,       
    input wire rst_n,     
    input wire a,         
    input wire b,         
    output reg [WIDTH-1:0] value  
);

    reg old_a, old_b;

    wire [3:0] transition;
    assign transition = {a, old_a, b, old_b}; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            old_a <= 1'b0;
            old_b <= 1'b0;
            value <= {WIDTH{1'b0}};
        end else if (ena) begin
            old_a <= a;
            old_b <= b;

            case (transition)
                4'b1000, 4'b0110, 4'b0011, 4'b1101: begin
                    if (value < MAX_VALUE[WIDTH-1:0]) // Size MAX_VALUE to match value width
                        value <= value + INCREMENT[WIDTH-1:0]; // Explicitly size INCREMENT
                end
                4'b0001, 4'b1011, 4'b1110, 4'b0100: begin
                    if (value > MIN_VALUE[WIDTH-1:0]) // Size MIN_VALUE to match value width
                        value <= value - INCREMENT[WIDTH-1:0]; // Explicitly size INCREMENT
                end
                default: value <= value; 
            endcase
        end
    end
endmodule