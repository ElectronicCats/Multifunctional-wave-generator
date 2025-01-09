module adsr_generator (
    input  wire       clk,       // Clock
    input  wire       rst_n,     // Reset, active low
    input  wire [7:0] attack,    // Attack value
    input  wire [7:0] decay,     // Decay value
    input  wire [7:0] sustain,   // Sustain value
    input  wire [7:0] rel,       // Release value
    output reg  [7:0] amplitude  // Generated amplitude signal
);

    reg [3:0] state;  // State of ADSR: 0=idle, 1=attack, 2=decay, 3=sustain, 4=release
    reg [7:0] counter;  // A counter to handle timing of each phase

    // Define states for better readability
    localparam STATE_IDLE     = 4'd0;
    localparam STATE_ATTACK   = 4'd1;
    localparam STATE_DECAY    = 4'd2;
    localparam STATE_SUSTAIN  = 4'd3;
    localparam STATE_RELEASE  = 4'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // On reset, return to idle state and reset amplitude
            state <= STATE_IDLE;
            amplitude <= 8'd0;
            counter <= 8'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    // Start the attack phase based on some external trigger condition
                    // Example trigger: counter reaches a certain value
                    if (counter == 8'd255) begin
                        state <= STATE_ATTACK;
                        counter <= 8'd0;  // Reset the counter for the next phase
                    end else begin
                        counter <= counter + 1;
                    end
                end
                STATE_ATTACK: begin
                    // Increase amplitude until it reaches the attack value
                    if (amplitude < attack) begin
                        amplitude <= amplitude + 1;
                    end else begin
                        state <= STATE_DECAY;
                    end
                end
                STATE_DECAY: begin
                    // Decrease amplitude until it reaches the sustain level
                    if (amplitude > sustain) begin
                        amplitude <= amplitude - 1;
                    end else begin
                        state <= STATE_SUSTAIN;
                    end
                end
                STATE_SUSTAIN: begin
                    // Maintain amplitude at sustain level until release condition is met
                    amplitude <= sustain;
                    
                    // Check for release condition (external trigger or timer)
                    if (counter == 8'd255) begin
                        state <= STATE_RELEASE;
                        counter <= 8'd0;  // Reset counter for the release phase
                    end else begin
                        counter <= counter + 1;
                    end
                end
                STATE_RELEASE: begin
                    // Gradually decrease amplitude to zero (release phase)
                    if (amplitude > 0) begin
                        amplitude <= amplitude - 1;
                    end else begin
                        state <= STATE_IDLE;  // Return to idle once the release phase ends
                    end
                end
                default: state <= STATE_IDLE;  // Fallback to idle state in case of an unknown state
            endcase
        end
    end
endmodule
