# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def send_uart_byte(dut, byte_value, baud_cycles=2604):
    """Simulate UART byte transmission with a start bit, 8 data bits, and a stop bit."""
    dut.ui_in[0].value = 0  # Start bit
    await ClockCycles(dut.clk, baud_cycles)

    # Send 8 data bits
    for i in range(8):
        dut.ui_in[0].value = (byte_value >> i) & 1
        await ClockCycles(dut.clk, baud_cycles)

    # Stop bit
    dut.ui_in[0].value = 1
    await ClockCycles(dut.clk, baud_cycles)


@cocotb.test()
async def test_tt_um_waves(dut):
    """Test UART Receiver and waveform selection."""
    dut._log.info("Initializing testbench")

    # Initialize clock
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 20)  # Wait for reset stabilization

    # Test white noise enable/disable
    dut._log.info("Testing White Noise Enable/Disable")
    await send_uart_byte(dut, 0x4E)  # 'N'
    await ClockCycles(dut.clk, 10)
    assert dut.white_noise_en.value == 1, "White noise enable failed"
    dut._log.info("White noise enabled successfully")

    await send_uart_byte(dut, 0x46)  # 'F'
    await ClockCycles(dut.clk, 10)
    assert dut.white_noise_en.value == 0, "White noise disable failed"
    dut._log.info("White noise disabled successfully")

    # Test waveform selection via UART
    waveforms = {
        0x54: 0b000,  # Triangle (ASCII 'T')
        0x53: 0b001,  # Sawtooth (ASCII 'S')
        0x51: 0b010,  # Square (ASCII 'Q')
        0x57: 0b011   # Sine (ASCII 'W')
    }

    for byte, expected_wave_select in waveforms.items():
        dut._log.info(f"Testing UART Byte: {byte} (Expected wave_select: {expected_wave_select})")
        await send_uart_byte(dut, byte)
        await ClockCycles(dut.clk, 10)

        assert dut.wave_select.value == expected_wave_select, \
            f"Waveform mismatch: Expected {expected_wave_select}, got {dut.wave_select.value}"
        dut._log.info(f"Waveform {expected_wave_select} correctly selected")

    # Verify frequency selection
    dut._log.info("Testing Frequency Selection")
    for freq_byte in range(0x00, 0x3F):  # Test frequency selection from 0 to 63
        await send_uart_byte(dut, freq_byte)
        await ClockCycles(dut.clk, 10)
        assert dut.freq_select.value == freq_byte, \
            f"Frequency mismatch: Expected {freq_byte}, got {dut.freq_select.value}"
    dut._log.info("Frequency selection tested successfully")
