# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, Timer

async def uart_send(dut, data):
    """ Simulate sending a UART byte (8N1 format: 1 start bit, 8 data bits, 1 stop bit). """
    dut._log.info(f"Sending UART byte: {chr(data)} ({data:#04x})")

    # Start bit (low)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 217)  # Adjusted for 115200 baud rate

    # Send 8 data bits (LSB first)
    for i in range(8):
        dut.ui_in.value = (data >> i) & 1
        await ClockCycles(dut.clk, 217)

    # Stop bit (high)
    dut.ui_in.value = 1
    await ClockCycles(dut.clk, 217)

    # Increased delay to allow UART processing (~4ms)
    await ClockCycles(dut.clk, 100000)

@cocotb.test()
async def test_waveform_generation(dut):
    """ Test UART commands, waveform selection, and I2S output verification. """

    # Start clock (40ns period → 25 MHz)
    cocotb.start_soon(Clock(dut.clk, 40, units="ns").start())

    # Reset DUT
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 500)  # Increased reset time
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 500)  # Allow system to stabilize

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
        before_wave_select = dut.adsr_debug.value  # Read adsr_debug before command
        await uart_send(dut, ord(cmd))
        await ClockCycles(dut.clk, 500)  # Allow processing time
        after_wave_select = dut.adsr_debug.value  # Read adsr_debug after command

        dut._log.info(f"Checking adsr_debug after {name} command...")
        dut._log.info(f"Before: {before_wave_select}, After: {after_wave_select}")
        assert before_wave_select != after_wave_select, f"wave_select did not change after {name} command"

        # Improved I2S monitoring
        i2s_sd_frames = []
        for _ in range(5):  # Capture multiple I2S frames
            await RisingEdge(dut.uo_out[1])  # Sync on WS rising edge
            frame_data = []
            for _ in range(16):  # Capture 16-bit frame
                await RisingEdge(dut.uo_out[0])  # Sync on SCK
                frame_data.append(dut.uo_out[2])  # Capture SD bit
            i2s_sd_frames.append(frame_data)

        dut._log.info(f"I2S Frames Captured for {name}: {i2s_sd_frames}")
        assert any(sum(frame) > 0 for frame in i2s_sd_frames), f"I2S SD stuck at zero after {name} command"

    dut._log.info("All tests passed successfully!")