# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

async def send_uart_byte(dut, byte_value, baud_cycles=2604):
    """Simulate UART byte transmission with a start bit, 8 data bits, and a stop bit."""
    dut.ui_in.value = 0  # Asegura que toda la señal está en 0 inicialmente
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
    """Test waveform selection, ADSR phases, and I2S output."""
    dut._log.info("Initializing testbench")

    # Initialize clock
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset and enable
    dut.ui_in.value = 0  # Initialize all bits
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    dut.ena.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 20)  # Wait for reset stabilization

    # Test waveform selection via UART
    waveforms = {
        0x54: 0b000,  # Triangle (ASCII 'T')
        0x53: 0b001,  # Sawtooth (ASCII 'S')
        0x51: 0b010,  # Square (ASCII 'Q')
        0x4E: 0b011,  # Sine (ASCII 'N')
        0x57: 0b100   # White Noise (ASCII 'W')
    }

    for byte, expected_value in waveforms.items():
        dut._log.info(f"Testing UART Byte: {byte} (Expected waveform: {expected_value})")
        await send_uart_byte(dut, byte)
        await ClockCycles(dut.clk, 10 * 2604)  # Wait for 10 UART cycles

        # Read and verify the waveform selection
        dut._log.info(f"uo_out = {dut.uo_out.value}")
        selected_wave = (dut.uo_out[2].value << 2) | (dut.uo_out[1].value << 1) | dut.uo_out[0].value
        assert selected_wave == expected_value, \
            f"Waveform mismatch: Expected {expected_value}, got {selected_wave}"

    # Test ADSR modulation phases
    adsr_inputs = {
        "Attack": (0, 1),
        "Decay": (2, 3),
        "Sustain": (4, 5),
        "Release": (6, 7)
    }

    for phase, pins in adsr_inputs.items():
        dut._log.info(f"Testing ADSR phase: {phase}")
        # Activate each ADSR phase
        dut.uio_in.value = 0  # Reset all inputs
        dut.uio_in[pins[0]].value = 1  # Encoder A
        dut.uio_in[pins[1]].value = 0  # Encoder B
        await ClockCycles(dut.clk, 100)  # Wait for stable signal

        # Verify ADSR output signal
        dut._log.info(f"uo_out[7] = {dut.uo_out[7].value}")
        assert dut.uo_out[7].value == 1, f"Expected ADSR {phase} output signal not active"

    # Verify I2S output signals (sck, ws, sd)
    dut._log.info("Verifying I2S signals")
    for _ in range(10):
        await ClockCycles(dut.clk, 200)
        dut._log.info(f"I2S signals: sck={dut.uo_out[0].value}, ws={dut.uo_out[1].value}, sd={dut.uo_out[2].value}")
        assert dut.uo_out[0].value in (0, 1), "Invalid SCK signal"
        assert dut.uo_out[1].value in (0, 1), "Invalid WS signal"
        assert dut.uo_out[2].value in (0, 1), "Invalid SD signal"
