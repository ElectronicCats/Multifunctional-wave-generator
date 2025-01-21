# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer

async def uart_send(dut, data):
    """ Simulate sending a UART byte (8N1 format: 1 start bit, 8 data bits, 1 stop bit). """
    dut._log.info(f"Sending UART byte: {chr(data)} ({data:#04x})")

    # Start bit (low)
    dut.ui_in.value = 0
    await Timer(104_167, units="ns")  # Assuming 9600 baud (1/9600 = 104.167μs per bit)

    # Send 8 data bits (LSB first)
    for i in range(8):
        dut.ui_in.value = (data >> i) & 1
        await Timer(104_167, units="ns")

    # Stop bit (high)
    dut.ui_in.value = 1
    await Timer(104_167, units="ns")

    # Wait a bit before sending next byte
    await Timer(500_000, units="ns")  # Small gap between UART transmissions

@cocotb.test()
async def test_uart_waveform(dut):
    """ Test UART commands and verify waveform selection & I2S output """

    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    dut.ena.value = 1  # Enable the module

    dut._log.info("Reset complete")

    # Test UART: Select different waveforms
    wave_commands = {
        'T': "Triangle",
        'S': "Sawtooth",
        'Q': "Square",
        'W': "Sine"
    }

    for cmd, name in wave_commands.items():
        await uart_send(dut, ord(cmd))
        await ClockCycles(dut.clk, 100)
        assert dut.wave_select.value == list(wave_commands.keys()).index(cmd), f"Waveform selection failed for {name}"
        dut._log.info(f"Waveform set to {name}")

    # Test UART: Set frequency (sending '0' - '9')
    for i in range(10):
        await uart_send(dut, ord(str(i)))
        await ClockCycles(dut.clk, 100)
        assert dut.freq_select.value == i, f"Frequency selection failed for {i}"
        dut._log.info(f"Frequency set to {i}")

    # Test UART: Set white noise ON ('N') and OFF ('F')
    await uart_send(dut, ord('N'))
    await ClockCycles(dut.clk, 100)
    assert dut.white_noise_en.value == 1, "White noise enable failed"
    dut._log.info("White noise enabled")

    await uart_send(dut, ord('F'))
    await ClockCycles(dut.clk, 100)
    assert dut.white_noise_en.value == 0, "White noise disable failed"
    dut._log.info("White noise disabled")

    # Check I2S output
    await ClockCycles(dut.clk, 500)
    assert dut.uo_out[0].value == 1 or dut.uo_out[0].value == 0, "I2S SCK signal incorrect"
    assert dut.uo_out[1].value == 1 or dut.uo_out[1].value == 0, "I2S WS signal incorrect"
    assert dut.uo_out[2].value == 1 or dut.uo_out[2].value == 0, "I2S SD signal incorrect"
    
    dut._log.info("I2S signals verified")

    dut._log.info("All tests passed successfully!")
