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
  
    // Phase accumulator for all waveforms
    reg [7:0] phase_accum;
  
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_divider <= 21'd284091;  // Default to A4 frequency
            prev_freq_select <= 6'bxxxxxx; // Uninitialized state
        end else if (freq_select != prev_freq_select) begin
            prev_freq_select <= freq_select;
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
                default:   freq_divider <= 21'd284091;   // Default frequency
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div  <= 0;
            wave_clk <= 0;
        end else if (clk_div >= (freq_divider >> 1)) begin // Avoids instability
            clk_div  <= 0;
            wave_clk <= ~wave_clk;
        end else begin
            clk_div <= clk_div + 1;
        end
    end

    // Phase accumulator for waveforms
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase_accum <= 8'd0;
        else if (ena)
            phase_accum <= phase_accum + {2'b00, freq_select[5:0]}; // Zero-extend freq_select to 8 bits
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

    // Select waveform output
    reg [7:0] selected_wave;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            selected_wave <= tri_wave_out; // Ensure valid waveform
        else begin
            case (wave_select)
                3'b000: selected_wave <= tri_wave_out;
                3'b001: selected_wave <= saw_wave_out;
                3'b010: selected_wave <= sqr_wave_out;
                3'b011: selected_wave <= sine_wave_out;
                3'b100: selected_wave <= noise_out;
                default: selected_wave <= tri_wave_out;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            attack  <= 8'd10;
            decay   <= 8'd5;
            sustain <= 8'd128;
            rel     <= 8'd5;
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

    // Apply ADSR Envelope to waveform
    reg [7:0] scaled_wave;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_wave   <= 16'd0;
            scaled_wave <= 8'd0;
        end else begin
            temp_wave <= (selected_wave * adsr_amplitude) >> 8;

            if (adsr_amplitude > 8'd10) 
                scaled_wave <= temp_wave[15:8];
            else
                scaled_wave <= 8'd2; // Smallest nonzero value
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
        end else begin
            case (state)
                IDLE: begin
                    if (start_bit && !receiving) begin
                        receiving <= 1'b1;
                        bit_count <= 0;
                        baud_counter <= 0;
                        state <= RECEIVING;
                    end
                end

                RECEIVING: begin
                    if (receiving) begin
                        if (baud_counter == (BAUD_TICKS >> 1)) begin // Sample at middle of bit
                            received_byte[bit_count] <= rx;
                            if (bit_count < 3'd7) begin
                                bit_count <= bit_count + 1;
                            end else begin
                                receiving <= 1'b0;
                                state <= PROCESSING;
                            end
                        end
                        baud_counter <= baud_counter + 1;
                    end
                end

                PROCESSING: begin
                    case (received_byte)
                        8'h4E: white_noise_en <= 1'b1; // 'N' -> Enable white noise
                        8'h46: white_noise_en <= 1'b0; // 'F' -> Disable white noise
                        8'h54: wave_select <= 3'b000; // 'T' -> Triangle
                        8'h53: wave_select <= 3'b001; // 'S' -> Sawtooth
                        8'h51: wave_select <= 3'b010; // 'Q' -> Square
                        8'h57: wave_select <= 3'b011; // 'W' -> Sine
                        default: begin
                            if (received_byte >= 8'h30 && received_byte <= 8'h39) begin
                                freq_select <= received_byte[5:0] - 6'd48; // Convert ASCII '0'-'9' to 0-9
                            end else if (received_byte >= 8'h41 && received_byte <= 8'h5A) begin
                                freq_select <= (received_byte[5:0] - 6'd33); // Convert 'A'-'Z' to 10-35
                            end
                        end
                    endcase

                    // Ensure proper bit-width comparison
                    if (freq_select != received_byte[5:0]) begin
                        phase_accum_reg <= phase_accum_reg + {2'b00, freq_select};
                    end
                    
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

    // Display the data and control signals for debugging
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            clk_div    <= 0;
            sck        <= 0;
            ws         <= 0;
            sd         <= 0;
            bit_counter <= 0;
            shift_reg  <= 16'd0;
        end else if (ena) begin
            // Debugging: Display scaled_wave and enable signal
            $display("Sending scaled_wave: %d to i2s_transmitter", data);
            $display("ena = %b, sck = %b, ws = %b, sd = %b", ena, sck, ws, sd);

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

    // CORDIC arctangent lookup table for 8 angles
    localparam signed [15:0] atan_table_0 = 16'h3243;
    localparam signed [15:0] atan_table_1 = 16'h1DAC;
    localparam signed [15:0] atan_table_2 = 16'h0FAB;
    localparam signed [15:0] atan_table_3 = 16'h07F5;
    localparam signed [15:0] atan_table_4 = 16'h03FE;
    localparam signed [15:0] atan_table_5 = 16'h01FF;
    localparam signed [15:0] atan_table_6 = 16'h00FF;
    localparam signed [15:0] atan_table_7 = 16'h007F;

    // Select atan value based on index
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

    // CORDIC processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 16'h4000;   // Start with normalized x = 1.0
            y <= 16'd0;      // y = 0.0
            z <= 16'd0;      // Phase angle starts at 0
            i <= 4'b0000;    // Reset the iteration counter
        end else if (ena) begin
            if (i == 4'b0000) begin
                z <= {phase, 8'b0};  // Set phase input directly (without shifting)
            end

            if (i < 4'b1000) begin
                // Perform the CORDIC iteration
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
                // Output the sine value (normalized to 8 bits)
                sine_out <= y[15:8];  // Take the upper 8 bits of y for sine output
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
            // Validating that the control signals are non-zero
            if (attack == 8'd0 || decay == 8'd0 || sustain == 8'd0 || rel == 8'd0) begin
                // Si algún valor es 0, se puede poner a una amplitud predeterminada
                adsr_amplitude <= 8'd0;
                state <= STATE_IDLE;  // Reiniciar el generador en caso de valores invalidos
            end else begin
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