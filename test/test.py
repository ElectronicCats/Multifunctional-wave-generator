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

    # Increased delay to allow UART processing (~2ms)
    await ClockCycles(dut.clk, 50000)

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

        # Observe I2S serial data (uo_out[2]) change over multiple cycles
        i2s_sd_changes = []
        for _ in range(10):
            await ClockCycles(dut.clk, 50)
            i2s_sd_changes.append(dut.uo_out.value[2])

        dut._log.info(f"I2S SD signal changes after {name}: {i2s_sd_changes}")
        assert len(set(i2s_sd_changes)) > 1, f"I2S SD signal did not change after {name} selection"

    # Test UART: Set frequency (sending '0' - '9')
    for i in range(10):
        before_freq_select = dut.adsr_debug.value  # Read adsr_debug before frequency command
        await uart_send(dut, ord(str(i)))
        await ClockCycles(dut.clk, 1000)  # Allow processing time
        after_freq_select = dut.adsr_debug.value  # Read adsr_debug after command

        dut._log.info(f"Checking adsr_debug after setting frequency '{i}'...")
        dut._log.info(f"Before: {before_freq_select}, After: {after_freq_select}")

        assert before_freq_select != after_freq_select, f"freq_select did not change after setting frequency {i}"

        # Observe I2S clock (uo_out[0]) toggles
        prev_sck = dut.uo_out.value[0]
        await ClockCycles(dut.clk, 50)
        new_sck = dut.uo_out.value[0]

        dut._log.info(f"Checking I2S SCK after frequency '{i}' command...")
        dut._log.info(f"Before: {prev_sck}, After: {new_sck}")

        assert prev_sck != new_sck, f"I2S SCK did not change after setting frequency {i}"

    # Test UART: Enable White Noise ('N') and Disable ('F')
    await uart_send(dut, ord('N'))
    await ClockCycles(dut.clk, 1000)

    i2s_noise_changes = []
    for _ in range(10):
        await ClockCycles(dut.clk, 50)
        i2s_noise_changes.append(dut.uo_out.value[2])

    dut._log.info("Checking I2S SD signal after enabling white noise...")
    dut._log.info(f"Changes: {i2s_noise_changes}")

    assert len(set(i2s_noise_changes)) > 1, "White noise selection failed"

    await uart_send(dut, ord('F'))
    await ClockCycles(dut.clk, 1000)

    i2s_noise_off_changes = []
    for _ in range(10):
        await ClockCycles(dut.clk, 50)
        i2s_noise_off_changes.append(dut.uo_out.value[2])

    dut._log.info("Checking I2S SD signal after disabling white noise...")
    dut._log.info(f"Changes: {i2s_noise_off_changes}")

    assert len(set(i2s_noise_off_changes)) == 1, "White noise disable failed"

    # Check I2S output correctness
    await ClockCycles(dut.clk, 1000)  
    dut._log.info("Checking I2S outputs...")

    # Ensure SCK, WS, and SD toggle
    prev_sck, prev_ws, prev_sd = dut.uo_out.value[0], dut.uo_out.value[1], dut.uo_out.value[2]
    await ClockCycles(dut.clk, 100)

    new_sck, new_ws, new_sd = dut.uo_out.value[0], dut.uo_out.value[1], dut.uo_out.value[2]

    assert prev_sck != new_sck, "I2S SCK did not toggle"
    assert prev_ws != new_ws, "I2S WS did not toggle"
    assert prev_sd != new_sd, "I2S SD did not toggle"

    dut._log.info("I2S signal toggling verified successfully.")

    dut._log.info("All tests passed successfully!")
