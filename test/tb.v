`timescale 1ns / 1ps

module tb;

    reg clk;
    reg rst_n;
    reg rx;
    wire [7:0] uo_out;
    
    // UART parámetros
    parameter CLK_PERIOD = 40; // 25 MHz
    parameter BIT_PERIOD = 10417; // 9600 baud (1/9600 seconds)

    // Instancia del módulo principal
    tt_um_waves uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .uo_out(uo_out)
    );

    // Generar el reloj de 25 MHz
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Procedimiento para enviar un byte por UART
    task send_uart_byte(input [7:0] byte);
        integer i;
        begin
            // Start bit
            rx = 0;
            #(BIT_PERIOD);

            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte[i];
                #(BIT_PERIOD);
            end

            // Stop bit
            rx = 1;
            #(BIT_PERIOD);
        end
    endtask

    initial begin
        // Inicialización
        rst_n = 0;
        rx = 1; // UART idle
        #100;
        rst_n = 1;

        // Enviar 'T' para onda triangular
        send_uart_byte(8'h54);  // ASCII 'T'
        #50000;  // Esperar procesamiento
        $display("uo_out: %b", uo_out);  // wave_select debería ser 000 (onda triangular)

        // Enviar 'N' para habilitar ruido blanco
        send_uart_byte(8'h4E);  // ASCII 'N'
        #50000;  // Esperar procesamiento
        $display("uo_out: %b", uo_out);  // white_noise_en debería ser 1

        // Enviar 'F' para deshabilitar ruido blanco
        send_uart_byte(8'h46);  // ASCII 'F'
        #50000;  // Esperar procesamiento
        $display("uo_out: %b", uo_out);  // white_noise_en debería ser 0

        // Fin de simulación
        $finish;
    end
endmodule
