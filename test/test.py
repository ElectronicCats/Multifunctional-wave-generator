# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

@cocotb.test()
async def test_uart_receiver(dut):
    """Test the UART receiver functionality."""

    # Clock setup: 25 MHz clock (40 ns period)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut._log.info("Applying reset")
    dut.rst_n.value = 0
    dut.rx.value = 1  # Default RX line idle state (high)
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Function to send a UART byte
    async def send_uart_byte(byte):
        """Send a UART byte to the RX line."""
        dut.rx.value = 0  # Start bit
        await ClockCycles(dut.clk, 25)  # Wait 1 baud (adjust based on your baud rate)

        for i in range(8):  # Send 8 data bits (LSB first)
            dut.rx.value = (byte >> i) & 1
            await ClockCycles(dut.clk, 25)

        dut.rx.value = 1  # Stop bit
        await ClockCycles(dut.clk, 25)  # Wait for the stop bit period

    # Test cases
    dut._log.info("Sending 'T' for Triangle Wave")
    await send_uart_byte(0x54)  # ASCII 'T'
    await ClockCycles(dut.clk, 50)
    assert dut.wave_select.value == 0, "Wave select should be 0 for triangle wave"

    dut._log.info("Sending 'S' for Sawtooth Wave")
    await send_uart_byte(0x53)  # ASCII 'S'
    await ClockCycles(dut.clk, 50)
    assert dut.wave_select.value == 1, "Wave select should be 1 for sawtooth wave"

    dut._log.info("Sending 'Q' for Square Wave")
    await send_uart_byte(0x51)  # ASCII 'Q'
    await ClockCycles(dut.clk, 50)
    assert dut.wave_select.value == 2, "Wave select should be 2 for square wave"

    dut._log.info("Sending 'W' for Sine Wave")
    await send_uart_byte(0x57)  # ASCII 'W'
    await ClockCycles(dut.clk, 50)
    assert dut.wave_select.value == 3, "Wave select should be 3 for sine wave"

    dut._log.info("Sending 'N' to Enable White Noise")
    await send_uart_byte(0x4E)  # ASCII 'N'
    await ClockCycles(dut.clk, 50)
    assert dut.white_noise_en.value == 1, "White noise enable should be 1"

    dut._log.info("Sending 'F' to Disable White Noise")
    await send_uart_byte(0x46)  # ASCII 'F'
    await ClockCycles(dut.clk, 50)
    assert dut.white_noise_en.value == 0, "White noise enable should be 0"

    dut._log.info("Sending frequency byte 0x3C")
    await send_uart_byte(0x3C)  # Arbitrary frequency byte
    await ClockCycles(dut.clk, 50)
    assert dut.freq_select.value == 0x3C, "Frequency select should match received byte (0x3C)"

    dut._log.info("All tests passed!")
