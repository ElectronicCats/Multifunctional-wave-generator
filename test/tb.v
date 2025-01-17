`timescale 1ns/1ps

module tb;
    reg clk;
    reg rst_n;
    reg rx;
    wire [7:0] uo_out;
    wire [2:0] wave_select;
    wire white_noise_en;

    // Instantiate DUT
    tt_um_waves dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .uo_out(uo_out),
        .wave_select(wave_select),
        .white_noise_en(white_noise_en)
    );

    // Generate 25 MHz clock
    initial begin
        clk = 0;
        forever #20 clk = ~clk;  // 40 ns period
    end

    // Reset logic
    initial begin
        rst_n = 0;  // Active low reset
        #100;       // Hold reset for 100 ns
        rst_n = 1;  // Release reset
    end

    // UART send task
    task send_uart_byte;
        input [7:0] byte;
        integer i;
        begin
            rx = 1; // Idle state
            #(104167); // One bit time at 9600 baud
            rx = 0; // Start bit
            #(104167);
            for (i = 0; i < 8; i = i + 1) begin
                rx = byte[i];
                #(104167);
            end
            rx = 1; // Stop bit
            #(104167);
        end
    endtask

    // Test sequence
    initial begin
        rx = 1;  // Idle state
        #200;    // Wait for reset
        send_uart_byte(8'h54);  // 'T' - Triangle wave
        #200;
        send_uart_byte(8'h53);  // 'S' - Sawtooth wave
        #200;
        $finish;
    end
endmodule
