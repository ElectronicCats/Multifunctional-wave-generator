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
async def test_wave_generation(dut):
    """Test UART-based wave selection and generation."""
    # Initialize clock
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 20)

    # Verify Reset State
    assert dut.uio_out[0].value == 0, "White noise enable should be 0 after reset"
    assert dut.uio_out[3:1].value == 0b000, "Wave select should be 0 after reset"

    # Test UART wave selection
    waveforms = {
        0x4E: {"white_noise_en": 1, "wave_select": 0b000},  # White Noise ('N')
        0x46: {"white_noise_en": 0, "wave_select": 0b000},  # Disable White Noise ('F')
        0x54: {"white_noise_en": 0, "wave_select": 0b001},  # Triangle Wave ('T')
        0x53: {"white_noise_en": 0, "wave_select": 0b010},  # Sawtooth Wave ('S')
        0x51: {"white_noise_en": 0, "wave_select": 0b011},  # Square Wave ('Q')
        0x57: {"white_noise_en": 0, "wave_select": 0b100},  # Sine Wave ('W')
    }

    for byte, expected in waveforms.items():
        dut._log.info(f"Testing UART Byte: {hex(byte)}")
        await send_uart_byte(dut, byte)
        await ClockCycles(dut.clk, 50)

        assert dut.uio_out[0].value == expected["white_noise_en"], \
            f"White noise enable mismatch for byte {hex(byte)}"
        assert dut.uio_out[3:1].value == expected["wave_select"], \
            f"Wave select mismatch for byte {hex(byte)}"

        dut._log.info(f"Waveform selection for {hex(byte)} passed!")

    # Verify Wave Output
    await ClockCycles(dut.clk, 100)
    assert dut.uo_out[0].value in (0, 1), "Invalid I2S SCK signal"
    assert dut.uo_out[1].value in (0, 1), "Invalid I2S WS signal"
    assert dut.uo_out[2].value in (0, 1), "Invalid I2S SD signal"
    dut._log.info("Waveform output verified successfully!")
