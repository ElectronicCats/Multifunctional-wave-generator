# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# UART Baud Rate: 115200 bits/s => Bit period ~ 8680 ns
BAUD_RATE = 115200
BIT_PERIOD = int(1e9 / BAUD_RATE)  # in nanoseconds


async def send_uart_byte(dut, data):
    """
    Simulate sending a UART byte to the RX line.
    - Start bit: 0
    - Data bits: 8 bits
    - Stop bit: 1
    """
    dut.rx.value = 0  # Start bit
    await Timer(BIT_PERIOD, units="ns")
    
    # Send data bits
    for i in range(8):
        dut.rx.value = (data >> i) & 1
        await Timer(BIT_PERIOD, units="ns")
    
    dut.rx.value = 1  # Stop bit
    await Timer(BIT_PERIOD, units="ns")


@cocotb.test()
async def test_uart_wave_selection(dut):
    """
    Test UART functionality to ensure proper wave selection.
    """
    # Start the clock (25 MHz -> 40 ns period)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the design
    dut.rst_n.value = 0
    dut.rx.value = 1  # Idle state for UART
    await Timer(100, units="ns")  # Wait for 100 ns
    dut.rst_n.value = 1
    await Timer(100, units="ns")  # Wait for the reset to complete

    # Send 'T' for Triangle wave (ASCII 0x54)
    await send_uart_byte(dut, 0x54)
    await Timer(10 * BIT_PERIOD, units="ns")  # Wait for processing

    # Check wave_select output
    assert dut.wave_select.value == 0b000, f"Failed: Expected wave_select=000, got {dut.wave_select.value}"
    dut._log.info("Triangle wave selected successfully!")

    # Send 'S' for Sawtooth wave (ASCII 0x53)
    await send_uart_byte(dut, 0x53)
    await Timer(10 * BIT_PERIOD, units="ns")  # Wait for processing

    # Check wave_select output
    assert dut.wave_select.value == 0b001, f"Failed: Expected wave_select=001, got {dut.wave_select.value}"
    dut._log.info("Sawtooth wave selected successfully!")

    # Send 'W' for Sine wave (ASCII 0x57)
    await send_uart_byte(dut, 0x57)
    await Timer(10 * BIT_PERIOD, units="ns")  # Wait for processing

    # Check wave_select output
    assert dut.wave_select.value == 0b011, f"Failed: Expected wave_select=011, got {dut.wave_select.value}"
    dut._log.info("Sine wave selected successfully!")

    # Send 'N' to enable white noise (ASCII 0x4E)
    await send_uart_byte(dut, 0x4E)
    await Timer(10 * BIT_PERIOD, units="ns")  # Wait for processing

    # Check white_noise_en output
    assert dut.white_noise_en.value == 1, f"Failed: Expected white_noise_en=1, got {dut.white_noise_en.value}"
    dut._log.info("White noise enabled successfully!")

    # Send 'F' to disable white noise (ASCII 0x46)
    await send_uart_byte(dut, 0x46)
    await Timer(10 * BIT_PERIOD, units="ns")  # Wait for processing

    # Check white_noise_en output
    assert dut.white_noise_en.value == 0, f"Failed: Expected white_noise_en=0, got {dut.white_noise_en.value}"
    dut._log.info("White noise disabled successfully!")
