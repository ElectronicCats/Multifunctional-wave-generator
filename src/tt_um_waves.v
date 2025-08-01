`default_nettype none

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
    // Synchronized reset (3-stage FF)
    reg [2:0] reset_sync_reg;
    wire rst_sync_n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) reset_sync_reg <= 0;
        else reset_sync_reg <= {reset_sync_reg[1:0], 1'b1};
    end
    assign rst_sync_n = reset_sync_reg[2];
  
    // UART Interface Signals
    wire [5:0] freq_select;
    wire [2:0] wave_select;
    reg        white_noise_en;
    
    // ADSR Control
    wire [15:0] adsr_amplitude;
    reg [7:0] attack, decay, sustain, rel; 
  
    // Frequency Control
    reg [20:0] freq_divider;
    reg [20:0] clk_div;
    reg [5:0] prev_freq_select;
    wire [20:0] uart_freq_divider;
  
    // Phase Accumulator (16-bit for timing)
    reg [15:0] phase_accum;
    wire [15:0] increment = {9'd0, freq_select, 1'b0}; // 16-bit corrected
    
    always @(posedge clk or negedge rst_sync_n) begin
        if (!rst_sync_n) phase_accum <= 0;
        else if (ena && freq_select != 0) 
            phase_accum <= phase_accum + increment;
    end

    // Waveform Generators
    wire [7:0] tri_wave_out, saw_wave_out, sqr_wave_out, sine_wave_out, noise_out;
    
    square_wave_generator sqr_gen (.clk(clk), .rst_n(rst_sync_n), .ena(ena), 
                                  .phase(phase_accum[15:8]), .wave_out(sqr_wave_out));
    triangular_wave_generator tri_gen (.clk(clk), .rst_n(rst_sync_n), .ena(ena), 
                                     .phase(phase_accum[15:8]), .wave_out(tri_wave_out));
    sawtooth_wave_generator saw_gen (.clk(clk), .rst_n(rst_sync_n), .ena(ena), 
                                    .phase(phase_accum[15:8]), .wave_out(saw_wave_out));
    white_noise_generator noise_gen (.clk(clk), .rst_n(rst_sync_n), 
                                   .noise_out(noise_out), .ena(white_noise_en & ena));
    cordic_sine_generator sine_gen (.clk(clk), .rst_n(rst_sync_n), .ena(ena), 
                                  .phase(phase_accum[15:8]), .sine_out(sine_wave_out));
    
    // Wave Selection
    reg [7:0] selected_wave;
    always @(posedge clk or negedge rst_sync_n) begin
        if (!rst_sync_n) selected_wave <= 128;
        else case (wave_select)
            3'b000: selected_wave <= tri_wave_out;
            3'b001: selected_wave <= saw_wave_out;
            3'b010: selected_wave <= sqr_wave_out;
            3'b011: selected_wave <= sine_wave_out;
            3'b100: selected_wave <= noise_out;
            default: selected_wave <= 128;
        endcase
    end

    // ADSR Generator
    adsr_generator adsr_gen (
        .clk(clk), 
        .rst_n(rst_sync_n),
        .attack(attack), 
        .decay(decay),
        .sustain(sustain), 
        .rel(rel),
        .amplitude(adsr_amplitude), 
        .ena(ena)
    );

    // ADSR Application (Optimized multiplier)
    reg [7:0] scaled_wave;
    reg [15:0] adsr_scaled;
    
    always @(posedge clk) begin
        adsr_scaled <= selected_wave * adsr_amplitude[15:8];
    end
    
    always @(posedge clk or negedge rst_sync_n) begin
        if (!rst_sync_n) scaled_wave <= 0;
        else if ((attack == 0) && (decay == 0) && (sustain == 0) && (rel == 0))
            scaled_wave <= selected_wave;
        else 
            scaled_wave <= adsr_scaled[15:8];
    end

    // I2S Output
    wire i2s_sck, i2s_ws, i2s_sd;
    i2s_transmitter i2s_out (
        .clk(clk),
        .rst_n(rst_sync_n),
        .data(scaled_wave), 
        .sck(i2s_sck),
        .ws(i2s_ws),
        .sd(i2s_sd),
        .ena(ena)
    );

    // Assign outputs
    assign uo_out[0] = i2s_sck;
    assign uo_out[1] = i2s_ws;
    assign uo_out[2] = i2s_sd;
    assign uo_out[7:3] = 0;
    assign uio_out = 0;     
    assign uio_oe = 0;

    // UART Receiver
    uart_receiver uart_rx_inst (
        .clk(clk),
        .rst_n(rst_sync_n),
        .rx(ui_in[0]),
        .freq_select(freq_select),
        .wave_select(wave_select),
        .white_noise_en(white_noise_en),
        .freq_divider(uart_freq_divider)
    );
  
    // Encoders for ADSR
    encoder attack_encoder (.clk(clk), .rst_n(rst_sync_n), .a(uio_in[0]), .b(uio_in[1]), .value(attack), .ena(ena));
    encoder decay_encoder (.clk(clk), .rst_n(rst_sync_n), .a(uio_in[2]), .b(uio_in[3]), .value(decay), .ena(ena));
    encoder sustain_encoder (.clk(clk), .rst_n(rst_sync_n), .a(uio_in[4]), .b(uio_in[5]), .value(sustain), .ena(ena));
    encoder release_encoder (.clk(clk), .rst_n(rst_sync_n), .a(uio_in[6]), .b(uio_in[7]), .value(rel), .ena(ena));

    // Frequency Divider Update
    always @(posedge clk or negedge rst_sync_n) begin
        if (!rst_sync_n) begin
            prev_freq_select <= 1;
            freq_divider <= 1915712;
        end else if (freq_select != prev_freq_select) begin
            prev_freq_select <= freq_select;
            freq_divider <= uart_freq_divider;
        end
    end
endmodule


module uart_receiver (
    input wire clk,
    input wire rst_n,
    input wire rx,                 // UART RX Input
    output reg [5:0] freq_select,  // Frequency selection (0-63)
    output reg [2:0] wave_select,  // Waveform selection
    output reg white_noise_en,     // White noise enable
    output reg [20:0] freq_divider // Frequency divider output
);

    // UART Parameters for 25MHz clock, 115200 baud
    localparam BAUD_TICKS = 217;     // 25,000,000 / 115200 = 217.014
    localparam HALF_BAUD = 108;      // Half of BAUD_TICKS (217/2 = 108.5)

    // Synchronizer and edge detection
    reg [1:0] rx_sync;
    reg rx_last;
    wire start_bit;
    
    // State machine states
    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        START_DELAY = 3'b001,
        RECEIVE     = 3'b010,
        STOP_BIT    = 3'b011,
        PROCESSING  = 3'b100
    } uart_state_t;

    uart_state_t state;  

    // UART reception registers
    reg [7:0] received_byte;
    reg [2:0] bit_count;
    reg [15:0] baud_counter;  // Wider counter for timing
    reg [5:0] temp_freq;

    // Input synchronization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync <= 2'b11;
            rx_last <= 1'b1;
        end else begin
            rx_sync <= {rx_sync[0], rx};
            rx_last <= rx_sync[1];
        end
    end
    assign start_bit = (rx_last && !rx_sync[1]);  // Falling edge detect

    // UART Receiver State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            received_byte <= 8'd0;
            bit_count <= 3'd0;
            baud_counter <= 0;
            freq_select <= 6'd9;      // Default to A2
            wave_select <= 3'd0;
            white_noise_en <= 1'b0;
            freq_divider <= 21'd1136364;  // A2 frequency
            temp_freq <= 6'd9;
        end else begin
            case (state)
                IDLE: begin
                    if (start_bit) begin
                        state <= START_DELAY;
                        baud_counter <= HALF_BAUD - 1;
                    end
                    bit_count <= 0;
                end
                
                START_DELAY: begin
                    if (baud_counter == 0) begin
                        state <= RECEIVE;
                        baud_counter <= BAUD_TICKS - 1;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                RECEIVE: begin
                    if (baud_counter == 0) begin
                        // Sample at middle of bit period
                        received_byte[bit_count] <= rx_sync[1];
                        
                        if (bit_count == 3'd7) begin
                            state <= STOP_BIT;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                        
                        baud_counter <= BAUD_TICKS - 1;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                STOP_BIT: begin
                    if (baud_counter == 0) begin
                        state <= PROCESSING;
                    end else begin
                        baud_counter <= baud_counter - 1;
                    end
                end
                
                PROCESSING: begin
                    // Process received command
                    case (received_byte)
                        8'h6E, 8'h4E: white_noise_en <= 1'b1;  // 'n' or 'N'
                        8'h66, 8'h46: white_noise_en <= 1'b0;  // 'f' or 'F'
                        8'h74, 8'h54: wave_select <= 3'b000;   // 't' or 'T'
                        8'h73, 8'h53: wave_select <= 3'b001;   // 's' or 'S'
                        8'h71, 8'h51: wave_select <= 3'b010;   // 'q' or 'Q'
                        8'h77, 8'h57: wave_select <= 3'b011;   // 'w' or 'W'
                        default: begin
                            // Handle frequency selection
                            if (received_byte >= 8'h30 && received_byte <= 8'h39) begin
                                // Numbers 0-9: Convert ASCII to value (0-9)
                                temp_freq <= {2'b00, received_byte[3:0]};  // Zero-extend to 6 bits
                            end else if (received_byte >= 8'h41 && received_byte <= 8'h5A) begin
                                // Uppercase A-Z: A=10, B=11,... Z=35
                                temp_freq <= 6'(received_byte - 8'd55);  // Explicit 6-bit cast
                            end else if (received_byte >= 8'h61 && received_byte <= 8'h7A) begin
                                // Lowercase a-z: a=10, b=11,... z=35
                                temp_freq <= 6'(received_byte - 8'd87);  // Explicit 6-bit cast
                            end
                        end
                    endcase
                    
                    // Update frequency selection
                    freq_select <= temp_freq;
                    
                    // Update frequency divider based on new frequency
                    case (temp_freq)
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
                        default:   freq_divider <= 21'd1136364; // Default to A2
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
        end else if (ena) begin  // Fixed: Enable gating
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]}; 
            noise_out <= lfsr[15:8]; 
        end
    end
endmodule



module i2s_transmitter (
    input  wire       clk,        
    input  wire       rst_n,      
    input  wire       ena,        
    input  wire [7:0] data, 
    output reg        sck = 0,   
    output reg        ws = 0,    
    output reg        sd = 0     
);

    reg [3:0] bit_counter;
    reg [15:0] shift_reg;
    reg [3:0] clk_div;
    
    // Explicit reset handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 0;
            sck <= 0;
            ws <= 0;
            sd <= 0;
            bit_counter <= 0;
            shift_reg <= 0;
        end else if (ena) begin
            clk_div <= clk_div + 1;
            
            // Generate 3.125MHz SCK (25MHz / 8)
            if (clk_div == 3) begin
                clk_div <= 0;
                sck <= ~sck;
                
                if (sck) begin  // On falling edge
                    if (bit_counter == 0) begin
                        shift_reg <= {data, 8'd0};  // 16-bit frame
                        ws <= ~ws;  // Toggle word select
                    end else begin
                        shift_reg <= shift_reg << 1;
                    end
                    
                    sd <= shift_reg[15];
                    bit_counter <= (bit_counter == 15) ? 0 : bit_counter + 1;
                end
            end
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
    // Precomputed sine table (256 entries) - full period
    reg [7:0] sine_table [0:255];
    
    // Initialize with complete sine wave values
    // Values calculated as: 128 + 127*sin(2π*i/256)
    initial begin
        sine_table[0] = 8'd128;
        sine_table[1] = 8'd131; sine_table[2] = 8'd134; sine_table[3] = 8'd137;
        sine_table[4] = 8'd140; sine_table[5] = 8'd143; sine_table[6] = 8'd146;
        sine_table[7] = 8'd149; sine_table[8] = 8'd152; sine_table[9] = 8'd155;
        sine_table[10] = 8'd158; sine_table[11] = 8'd162; sine_table[12] = 8'd165;
        sine_table[13] = 8'd167; sine_table[14] = 8'd170; sine_table[15] = 8'd173;
        sine_table[16] = 8'd176; sine_table[17] = 8'd179; sine_table[18] = 8'd182;
        sine_table[19] = 8'd185; sine_table[20] = 8'd188; sine_table[21] = 8'd190;
        sine_table[22] = 8'd193; sine_table[23] = 8'd196; sine_table[24] = 8'd198;
        sine_table[25] = 8'd201; sine_table[26] = 8'd203; sine_table[27] = 8'd206;
        sine_table[28] = 8'd208; sine_table[29] = 8'd211; sine_table[30] = 8'd213;
        sine_table[31] = 8'd215; sine_table[32] = 8'd218; sine_table[33] = 8'd220;
        sine_table[34] = 8'd222; sine_table[35] = 8'd224; sine_table[36] = 8'd226;
        sine_table[37] = 8'd228; sine_table[38] = 8'd230; sine_table[39] = 8'd232;
        sine_table[40] = 8'd233; sine_table[41] = 8'd235; sine_table[42] = 8'd236;
        sine_table[43] = 8'd238; sine_table[44] = 8'd239; sine_table[45] = 8'd241;
        sine_table[46] = 8'd242; sine_table[47] = 8'd243; sine_table[48] = 8'd244;
        sine_table[49] = 8'd245; sine_table[50] = 8'd246; sine_table[51] = 8'd247;
        sine_table[52] = 8'd248; sine_table[53] = 8'd248; sine_table[54] = 8'd249;
        sine_table[55] = 8'd250; sine_table[56] = 8'd250; sine_table[57] = 8'd251;
        sine_table[58] = 8'd251; sine_table[59] = 8'd251; sine_table[60] = 8'd252;
        sine_table[61] = 8'd252; sine_table[62] = 8'd252; sine_table[63] = 8'd252;
        sine_table[64] = 8'd252; sine_table[65] = 8'd252; sine_table[66] = 8'd252;
        sine_table[67] = 8'd251; sine_table[68] = 8'd251; sine_table[69] = 8'd251;
        sine_table[70] = 8'd250; sine_table[71] = 8'd250; sine_table[72] = 8'd249;
        sine_table[73] = 8'd248; sine_table[74] = 8'd248; sine_table[75] = 8'd247;
        sine_table[76] = 8'd246; sine_table[77] = 8'd245; sine_table[78] = 8'd244;
        sine_table[79] = 8'd243; sine_table[80] = 8'd242; sine_table[81] = 8'd241;
        sine_table[82] = 8'd239; sine_table[83] = 8'd238; sine_table[84] = 8'd236;
        sine_table[85] = 8'd235; sine_table[86] = 8'd233; sine_table[87] = 8'd232;
        sine_table[88] = 8'd230; sine_table[89] = 8'd228; sine_table[90] = 8'd226;
        sine_table[91] = 8'd224; sine_table[92] = 8'd222; sine_table[93] = 8'd220;
        sine_table[94] = 8'd218; sine_table[95] = 8'd215; sine_table[96] = 8'd213;
        sine_table[97] = 8'd211; sine_table[98] = 8'd208; sine_table[99] = 8'd206;
        sine_table[100] = 8'd203; sine_table[101] = 8'd201; sine_table[102] = 8'd198;
        sine_table[103] = 8'd196; sine_table[104] = 8'd193; sine_table[105] = 8'd190;
        sine_table[106] = 8'd188; sine_table[107] = 8'd185; sine_table[108] = 8'd182;
        sine_table[109] = 8'd179; sine_table[110] = 8'd176; sine_table[111] = 8'd173;
        sine_table[112] = 8'd170; sine_table[113] = 8'd167; sine_table[114] = 8'd165;
        sine_table[115] = 8'd162; sine_table[116] = 8'd158; sine_table[117] = 8'd155;
        sine_table[118] = 8'd152; sine_table[119] = 8'd149; sine_table[120] = 8'd146;
        sine_table[121] = 8'd143; sine_table[122] = 8'd140; sine_table[123] = 8'd137;
        sine_table[124] = 8'd134; sine_table[125] = 8'd131; sine_table[126] = 8'd128;
        sine_table[127] = 8'd125; sine_table[128] = 8'd122; sine_table[129] = 8'd119;
        sine_table[130] = 8'd116; sine_table[131] = 8'd113; sine_table[132] = 8'd110;
        sine_table[133] = 8'd107; sine_table[134] = 8'd104; sine_table[135] = 8'd101;
        sine_table[136] = 8'd98; sine_table[137] = 8'd94; sine_table[138] = 8'd91;
        sine_table[139] = 8'd89; sine_table[140] = 8'd86; sine_table[141] = 8'd83;
        sine_table[142] = 8'd80; sine_table[143] = 8'd77; sine_table[144] = 8'd74;
        sine_table[145] = 8'd71; sine_table[146] = 8'd68; sine_table[147] = 8'd66;
        sine_table[148] = 8'd63; sine_table[149] = 8'd60; sine_table[150] = 8'd58;
        sine_table[151] = 8'd55; sine_table[152] = 8'd53; sine_table[153] = 8'd50;
        sine_table[154] = 8'd48; sine_table[155] = 8'd45; sine_table[156] = 8'd43;
        sine_table[157] = 8'd41; sine_table[158] = 8'd38; sine_table[159] = 8'd36;
        sine_table[160] = 8'd34; sine_table[161] = 8'd32; sine_table[162] = 8'd30;
        sine_table[163] = 8'd28; sine_table[164] = 8'd26; sine_table[165] = 8'd24;
        sine_table[166] = 8'd22; sine_table[167] = 8'd20; sine_table[168] = 8'd19;
        sine_table[169] = 8'd17; sine_table[170] = 8'd16; sine_table[171] = 8'd14;
        sine_table[172] = 8'd13; sine_table[173] = 8'd11; sine_table[174] = 8'd10;
        sine_table[175] = 8'd9; sine_table[176] = 8'd8; sine_table[177] = 8'd7;
        sine_table[178] = 8'd6; sine_table[179] = 8'd5; sine_table[180] = 8'd4;
        sine_table[181] = 8'd4; sine_table[182] = 8'd3; sine_table[183] = 8'd2;
        sine_table[184] = 8'd2; sine_table[185] = 8'd1; sine_table[186] = 8'd1;
        sine_table[187] = 8'd1; sine_table[188] = 8'd0; sine_table[189] = 8'd0;
        sine_table[190] = 8'd0; sine_table[191] = 8'd0; sine_table[192] = 8'd0;
        sine_table[193] = 8'd0; sine_table[194] = 8'd0; sine_table[195] = 8'd1;
        sine_table[196] = 8'd1; sine_table[197] = 8'd1; sine_table[198] = 8'd2;
        sine_table[199] = 8'd2; sine_table[200] = 8'd3; sine_table[201] = 8'd4;
        sine_table[202] = 8'd4; sine_table[203] = 8'd5; sine_table[204] = 8'd6;
        sine_table[205] = 8'd7; sine_table[206] = 8'd8; sine_table[207] = 8'd9;
        sine_table[208] = 8'd10; sine_table[209] = 8'd11; sine_table[210] = 8'd13;
        sine_table[211] = 8'd14; sine_table[212] = 8'd16; sine_table[213] = 8'd17;
        sine_table[214] = 8'd19; sine_table[215] = 8'd20; sine_table[216] = 8'd22;
        sine_table[217] = 8'd24; sine_table[218] = 8'd26; sine_table[219] = 8'd28;
        sine_table[220] = 8'd30; sine_table[221] = 8'd32; sine_table[222] = 8'd34;
        sine_table[223] = 8'd36; sine_table[224] = 8'd38; sine_table[225] = 8'd41;
        sine_table[226] = 8'd43; sine_table[227] = 8'd45; sine_table[228] = 8'd48;
        sine_table[229] = 8'd50; sine_table[230] = 8'd53; sine_table[231] = 8'd55;
        sine_table[232] = 8'd58; sine_table[233] = 8'd60; sine_table[234] = 8'd63;
        sine_table[235] = 8'd66; sine_table[236] = 8'd68; sine_table[237] = 8'd71;
        sine_table[238] = 8'd74; sine_table[239] = 8'd77; sine_table[240] = 8'd80;
        sine_table[241] = 8'd83; sine_table[242] = 8'd86; sine_table[243] = 8'd89;
        sine_table[244] = 8'd91; sine_table[245] = 8'd94; sine_table[246] = 8'd98;
        sine_table[247] = 8'd101; sine_table[248] = 8'd104; sine_table[249] = 8'd107;
        sine_table[250] = 8'd110; sine_table[251] = 8'd113; sine_table[252] = 8'd116;
        sine_table[253] = 8'd119; sine_table[254] = 8'd122; sine_table[255] = 8'd125;
    end

    // Synchronous output with reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sine_out <= 8'd0;
        else if (ena) sine_out <= sine_table[phase];
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
        if (!rst_n) wave_out <= 8'd128;
        else if (ena) begin
            wave_out <= phase[7] ? (8'd255 - ({1'b0, phase[6:0]} << 1)) : 
                                  ({1'b0, phase[6:0]} << 1);
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
        if (!rst_n) wave_out <= 8'd128;
        else if (ena) wave_out <= phase;
    end
endmodule

module adsr_generator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  attack,
    input  wire [7:0]  decay,
    input  wire [7:0]  sustain,
    input  wire [7:0]  rel,
    output reg  [15:0] amplitude,
    input  wire        ena
);

    typedef enum {IDLE, ATTACK, DECAY, SUSTAIN, RELEASE} state_t;
    state_t state;
    
    // Fixed-point scaling with proper bit widths
    wire [15:0] sustain_level = {sustain, 8'b0};
    
    // Zero-extend 8-bit values to 16-bit for division
    wire [15:0] attack_step  = (attack != 0) ? (65535 / {8'b0, attack}) : 0;
    wire [15:0] decay_step   = (decay != 0)  ? ((65535 - sustain_level) / {8'b0, decay}) : 0;
    wire [15:0] release_step = (rel != 0)    ? (sustain_level / {8'b0, rel}) : 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            amplitude <= 0;
        end else if (ena) begin
            case (state)
                IDLE: if (attack > 0) state <= ATTACK;
                
                ATTACK: begin
                    if (amplitude < 65535 - attack_step) 
                        amplitude <= amplitude + attack_step;
                    else begin
                        amplitude <= 65535;
                        state <= DECAY;
                    end
                end
                
                DECAY: begin
                    if (amplitude > sustain_level + decay_step) 
                        amplitude <= amplitude - decay_step;
                    else begin
                        amplitude <= sustain_level;
                        state <= SUSTAIN;
                    end
                end
                
                SUSTAIN: if (rel > 0) state <= RELEASE;
                
                RELEASE: begin
                    if (amplitude > release_step) 
                        amplitude <= amplitude - release_step;
                    else begin
                        amplitude <= 0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule



module square_wave_generator (
    input  wire       ena,        
    input  wire       clk,        
    input  wire       rst_n,      
    input  wire [7:0] phase, 
    output reg  [7:0] wave_out    
);  
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) wave_out <= 8'd0;
        else if (ena) wave_out <= (phase > 8'd127) ? 8'd255 : 8'd0;
    end
endmodule

module encoder #(
    parameter integer WIDTH = 8,              // Counter width
    parameter integer INCREMENT = 1,          // Increment value
    parameter integer MAX_VALUE = (1 << WIDTH)-1, // Max value
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
                    if (value < MAX_VALUE[WIDTH-1:0])
                        value <= value + INCREMENT[WIDTH-1:0];
                end
                4'b0001, 4'b1011, 4'b1110, 4'b0100: begin
                    if (value > MIN_VALUE[WIDTH-1:0])
                        value <= value - INCREMENT[WIDTH-1:0];
                end
                default: value <= value; 
            endcase
        end
    end
endmodule