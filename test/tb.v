module tb;
    reg clk;
    reg rst_n;
    reg rx;
    wire [7:0] uo_out;

    // Instancia del diseño
    tt_um_waves uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .uo_out(uo_out)
    );

    // Generación de reloj de 25 MHz
    initial begin
        clk = 0;
        forever #20 clk = ~clk;  // 40 ns periodo = 25 MHz
    end

    // Tarea para enviar un byte por UART
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rx = 1'b0;
            #8680;  // BIT_PERIOD

            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #8680;  // BIT_PERIOD
            end

            // Stop bit
            rx = 1'b1;
            #8680;  // BIT_PERIOD
        end
    endtask

    // Secuencia de prueba
    initial begin
        // Reset
        rst_n = 0;
        rx = 1;
        #100;
        rst_n = 1;

        // Enviar 'T' para onda triangular
        send_uart_byte(8'h54);  // ASCII 'T'
        #20000;  // Esperar a que se procese
        $display("uo_out: %b", uo_out);  // wave_select debería ser 000 (onda triangular)

        // Enviar 'N' para habilitar ruido blanco
        send_uart_byte(8'h4E);  // ASCII 'N'
        #20000;  // Esperar a que se procese
        $display("uo_out: %b", uo_out);  // white_noise_en debería ser 1

        // Fin de simulación
        $finish;
    end
endmodule
