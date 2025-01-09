module square_wave_generator (
    input wire clk,                  // Reloj del sistema
    input wire reset,                // Señal de reinicio
    output reg [7:0] wave_out        // Salida de onda cuadrada de 8 bits
);

    reg wave_state;                  // Estado actual de la onda cuadrada

    // Inicialización
    initial begin
        wave_state = 1'b0;
        wave_out = 8'd0;
    end

    // Generación de la onda cuadrada
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wave_state <= 1'b0;        // Reiniciar el estado de la onda
            wave_out <= 8'd0;          // Reiniciar la salida de la onda
        end else begin
            wave_state <= ~wave_state;  // Cambiar el estado de la onda cuadrada
            wave_out <= (wave_state) ? 8'd255 : 8'd0; // Establecer la salida de la onda cuadrada
        end
    end

endmodule
