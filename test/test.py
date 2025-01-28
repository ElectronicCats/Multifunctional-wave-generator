# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer

async def uart_send(dut, data):
    """ Simulate sending a UART byte (8N1 format: 1 start bit, 8 data bits, 1 stop bit). """
    dut._log.info(f"Sending UART byte: {chr(data)} ({data:#04x})")

    # Start bit (low)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2604)  # Adjusted for 25MHz clock

    # Send 8 data bits (LSB first)
    for i in range(8):
        dut.ui_in.value = (data >> i) & 1
        await ClockCycles(dut.clk, 2604)

    # Stop bit (high)
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 2604)

    # Wait before next command (~1ms delay)
    await ClockCycles(dut.clk, 25000)

@cocotb.test()
async def test_waveform_generation(dut):
    """ Test UART commands, waveform selection, and I2S output verification. """

    # Start clock (40ns period → 25 MHz)
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    # Reset DUT
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 100)  # Longer reset period
    dut.rst_n.value = 1
    dut.ena.value = 1  # Enable module

    dut._log.info("Reset complete")

    # Test UART: Select different waveforms and verify I2S output changes
    wave_commands = {
        'T': "Triangle",
        'S': "Sawtooth",
        'Q': "Square",
        'W': "Sine"
    }

    for cmd, name in wave_commands.items():
        await uart_send(dut, ord(cmd))
        await ClockCycles(dut.clk, 1000)  # Allow processing time

        # Observe I2S serial data (uo_out[2]) change
        i2s_sd_before = dut.uo_out[2].value
        await ClockCycles(dut.clk, 100)
        i2s_sd_after = dut.uo_out[2].value

        dut._log.info(f"Checking I2S SD signal after {name} command...")
        dut._log.info(f"Before: {i2s_sd_before}, After: {i2s_sd_after}")

        assert i2s_sd_before != i2s_sd_after, f"I2S SD signal did not change after {name} selection"

    # Test UART: Set frequency (sending '0' - '9')
    for i in range(10):
        await uart_send(dut, ord(str(i)))
        await ClockCycles(dut.clk, 1000)  # Allow processing time

        # Observe I2S clock (uo_out[0]) toggles
        prev_sck = dut.uo_out[0].value
        await ClockCycles(dut.clk, 50)
        new_sck = dut.uo_out[0].value

        dut._log.info(f"Checking I2S SCK signal after frequency '{i}' command...")
        dut._log.info(f"Before: {prev_sck}, After: {new_sck}")

        assert prev_sck != new_sck, f"I2S SCK signal did not change after setting frequency {i}"

    # Test UART: Enable White Noise ('N') and Disable ('F')
    await uart_send(dut, ord('N'))
    await ClockCycles(dut.clk, 1000)

    # Observe randomness in I2S serial data (uo_out[2])
    i2s_noise_before = dut.uo_out[2].value
    await ClockCycles(dut.clk, 50)
    i2s_noise_after = dut.uo_out[2].value

    dut._log.info("Checking I2S SD signal after enabling white noise...")
    dut._log.info(f"Before: {i2s_noise_before}, After: {i2s_noise_after}")

    assert i2s_noise_before != i2s_noise_after, "White noise selection failed (I2S SD signal did not change)"

    await uart_send(dut, ord('F'))
    await ClockCycles(dut.clk, 1000)

    # Observe I2S serial data (uo_out[2]) again
    i2s_noise_off_before = dut.uo_out[2].value
    await ClockCycles(dut.clk, 50)
    i2s_noise_off_after = dut.uo_out[2].value

    dut._log.info("Checking I2S SD signal after disabling white noise...")
    dut._log.info(f"Before: {i2s_noise_off_before}, After: {i2s_noise_off_after}")

    assert i2s_noise_off_before != i2s_noise_off_after, "White noise disable failed (I2S SD signal did not change)"

    # Check I2S output correctness
    await ClockCycles(dut.clk, 1000)  # Ensure stability
    dut._log.info("Checking I2S outputs...")

    # Ensure SCK, WS, and SD toggle
    prev_sck, prev_ws, prev_sd = dut.uo_out[0].value, dut.uo_out[1].value, dut.uo_out[2].value
    await ClockCycles(dut.clk, 100)

    new_sck, new_ws, new_sd = dut.uo_out[0].value, dut.uo_out[1].value, dut.uo_out[2].value

    assert prev_sck != new_sck, "I2S SCK did not toggle"
    assert prev_ws != new_ws, "I2S WS did not toggle"
    assert prev_sd != new_sd, "I2S SD did not toggle"

    dut._log.info("I2S signal toggling verified successfully.")

    dut._log.info("All tests passed successfully!")
