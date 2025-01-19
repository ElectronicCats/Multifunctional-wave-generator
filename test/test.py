# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

BIT_PERIOD = 8680  # ns (para 115200 baudios)

@cocotb.test()
async def test_uart(dut):
    # Configuración inicial: reloj de 25 MHz
    clock = Clock(dut.clk, 40, units="ns")  # 40 ns periodo = 25 MHz
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    # Enviar 'T' (onda triangular)
    await send_uart_byte(dut, 0x54)  # ASCII 'T'
    await ClockCycles(dut.clk, 100)
    wave_select = dut.uo_out.value & 0x07  # Bits 2:0 de uo_out
    assert wave_select == 0, f"wave_select incorrecto: {wave_select}"

    # Enviar 'N' (habilitar ruido blanco)
    await send_uart_byte(dut, 0x4E)  # ASCII 'N'
    await ClockCycles(dut.clk, 100)
    white_noise_en = (dut.uo_out.value >> 3) & 0x01  # Bit 3 de uo_out
    assert white_noise_en == 1, f"white_noise_en incorrecto: {white_noise_en}"

    # Enviar 'F' (deshabilitar ruido blanco)
    await send_uart_byte(dut, 0x46)  # ASCII 'F'
    await ClockCycles(dut.clk, 100)
    white_noise_en = (dut.uo_out.value >> 3) & 0x01  # Bit 3 de uo_out
    assert white_noise_en == 0, f"white_noise_en incorrecto: {white_noise_en}"

async def send_uart_byte(dut, data):
    """Envía un byte al UART"""
    # Start bit
    dut.rx.value = 0
    await Timer(BIT_PERIOD, units="ns")

    # Data bits
    for i in range(8):
        dut.rx.value = (data >> i) & 1
        await Timer(BIT_PERIOD, units="ns")

    # Stop bit
    dut.rx.value = 1
    await Timer(BIT_PERIOD, units="ns")
